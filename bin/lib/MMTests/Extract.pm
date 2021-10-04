# Extract.pm
#
# This is base class description for modules that parse MM Tests directories
# and extract information from them

package MMTests::Extract;
use MMTests::DataTypes;
use MMTests::Stat;
use MMTests::Blessless qw(blessless);
use MMTests::PrintGeneric;
use MMTests::PrintHtml;
use List::Util ();
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName 	=> "Extract",
		_FieldHeaders	=> [],
		_FieldLength	=> 0,
		_Cmd			=> "",
	};
	bless $self, $class;
	return $self;
}

sub TO_JSON() {
	my ($self) = @_;
	return blessless($self);
}

sub getModuleName() {
	my ($self) = @_;
	return $self->{_ModuleName};
}

sub getDataType() {
	my ($self, $op) = @_;

	if (defined($self->{_DataType})) {
		return $self->{_DataType};
	}
	return $self->{_DataTypes}->{$op};
}

sub getPlotYaxis() {
	my ($self, $op) = @_;

	if (defined($self->{_PlotYaxis})) {
		return $self->{_PlotYaxis};
	}
	if (defined($self->{_PlotYaxes})) {
		return $self->{_PlotYaxes}->{$op};
	}
	return "UNKNOWN";
}

sub printDataType() {
	my ($self, $subHeading) = @_;
	my $yaxis = "UNKNOWN AXIS";
	my $units = "Time";
	my $dtype;

	if ($subHeading eq "") {
		$subHeading = $self->{_DefaultPlot};
	}
	$dtype = $self->getDataType($subHeading);

	if ($dtype == DataTypes::DATA_TIME_USECONDS) {
		$yaxis = "Time (usec)";
	} elsif ($dtype == DataTypes::DATA_TIME_NSECONDS) {
		$yaxis = "Time (nanosec)";
	} elsif ($dtype == DataTypes::DATA_TIME_MSECONDS) {
		$yaxis = "Time (msec)";
	} elsif ($dtype == DataTypes::DATA_TIME_SECONDS) {
		$yaxis = "Time (seconds)";
	} elsif ($dtype == DataTypes::DATA_TIME_CYCLES) {
		$yaxis = "Time (cpu cycles)";
	} elsif ($dtype == DataTypes::DATA_ACTIONS) {
		$yaxis = "Actions";
		$units = "VarAction";
	} elsif ($dtype == DataTypes::DATA_ACTIONS_PER_SECOND) {
		$yaxis = "Actions/sec";
		$units = "Actions";
	} elsif ($dtype == DataTypes::DATA_ACTIONS_PER_MINUTE) {
		$yaxis = "Actions/minute";
		$units = "Actions";
	} elsif ($dtype == DataTypes::DATA_OPS_PER_SECOND) {
		$yaxis = "Ops/sec";
		$units = "Operations";
	} elsif ($dtype == DataTypes::DATA_OPS_PER_MINUTE) {
		$yaxis = "Ops/minute";
		$units = "Operations";
	} elsif ($dtype == DataTypes::DATA_TRANS_PER_SECOND) {
		$yaxis = "Transactions/sec";
		$units = "Transactions";
	} elsif ($dtype == DataTypes::DATA_TRANS_PER_MINUTE) {
		$yaxis = "Transactions/minute";
		$units = "Transactions";
	} elsif ($dtype == DataTypes::DATA_MBITS_PER_SECOND) {
		$yaxis = "MBits/sec";
		$units = "Throughput";
	} elsif ($dtype == DataTypes::DATA_MBYTES_PER_SECOND) {
		$yaxis = "MBytes/sec";
		$units = "Throughput";
	} elsif ($dtype == DataTypes::DATA_KBYTES_PER_SECOND) {
		$yaxis = "KBytes/sec";
		$units = "Throughput";
	} elsif ($dtype == DataTypes::DATA_SUCCESS_PERCENT) {
		$yaxis = "Percentage";
		$units = "Success";
	} elsif ($dtype == DataTypes::DATA_USAGE_PERCENT) {
		$yaxis = "Percentage";
		$units = "Usage";
	} elsif ($dtype == DataTypes::DATA_REQ_PER_SECOND) {
		$yaxis = "Requests/sec";
		$units = "Throughput";
	} elsif ($dtype == DataTypes::DATA_SIZE_SECTOR) {
		$yaxis = "Size (sectors)";
		$units = "Size";
	} elsif ($dtype == DataTypes::DATA_SIZE_BYTES) {
		$yaxis = "Size (Bytes)";
		$units = "Size";
	} elsif ($dtype == DataTypes::DATA_SIZE_KBYTES) {
		$yaxis = "Size (KiB)";
		$units = "Size";
	} elsif ($dtype == DataTypes::DATA_SIZE_MBYTES) {
		$yaxis = "Size (MiB)";
		$units = "Size";
	} elsif ($dtype == DataTypes::DATA_SIZE_PAGES) {
		$yaxis = "Size (pages)";
		$units = "Size";
	} elsif ($dtype == DataTypes::DATA_SIZE_QUEUED) {
		$yaxis = "Queue size";
		$units = "Size";
	} elsif ($dtype == DataTypes::DATA_FREQUENCY_MHZ) {
		$yaxis = "MHz";
		$units = "Frequency";
	} elsif ($dtype == DataTypes::DATA_CONSUMPTION_WATT) {
		$yaxis = "Watt";
		$units = "Consumption";
	} elsif ($dtype == DataTypes::DATA_RATIO_SPEEDUP) {
		$yaxis = "Speedup (ratio)";
	} elsif ($dtype == DataTypes::DATA_BALANCE) {
		$units = "Balance";
		$yaxis = "Balance";
	} elsif ($dtype == DataTypes::DATA_CONVERGENCE) {
		$units = "Convergence";
		$yaxis = "Convergence";
	}

	my $xaxis = "UNKNOWN";
	if (defined($self->{_PlotXaxis})) {
		$xaxis = $self->{_PlotXaxis};
	}
	my $yaxis_extra = $self->getPlotYaxis($subHeading);
	if (defined $yaxis_extra && $yaxis_extra ne "UNKNOWN") {
		$yaxis = $yaxis_extra;
	}
	my $plotType = "UNKNOWN";
	if (defined($self->{_PlotType})) {
		$plotType = $self->{_PlotType};
	}

	if ($xaxis eq "UNKNOWN" && $self->{_PlotType} =~ /candlesticks/) {
		$xaxis = "-";
	}

	print "$units,$xaxis,$yaxis,$plotType";
	if ($self->{_SubheadingPlotType} != "") {
		print ",$self->{_SubheadingPlotType}";
	}
}

sub initialise() {
	my ($self, $subHeading) = @_;
	my @fieldHeaders;
	my ($fieldLength, $plotLength, $summaryLength);

	$fieldLength = 12;
	@fieldHeaders = ("UnknownType");
	$fieldLength = $self->{_FieldLength}   if defined $self->{_FieldLength};

	$self->{_FieldLength}  = $fieldLength;
	$self->{_FieldHeaders} = \@fieldHeaders;
	$self->{_PlotLength} = $plotLength;
	$self->{_ResultData} = {};
	$self->{_ResultDataUnsorted} = 0;
	$self->{_LastSample} = {};
	$self->{_GeneratedOperations} = [];
	$self->{_OperationsSeen} = {};
	$self->{_CurrentIteration} = 0;

	if ($self->{_PlotType} eq "client-errorlines") {
		$self->{_PlotXaxis}  = "Clients";
	}
	if ($self->{_PlotType} eq "thread-errorlines") {
		$self->{_PlotType} = "client-errorlines";
		$self->{_PlotXaxis}  = "Threads";
	}
	if ($self->{_PlotType} eq "process-errorlines") {
		$self->{_PlotType} = "client-errorlines";
		$self->{_PlotXaxis}  = "Processes";
	}
	if ($self->{_PlotType} eq "group-errorlines") {
		$self->{_PlotType} = "client-errorlines";
		$self->{_PlotXaxis}  = "Groups";
	}
	if ($self->{_PlotType} eq "histogram-single") {
		$self->{_PlotType} = "histogram-time";
	}
	if ($self->{_SubheadingPlotType} eq "simple-clients") {
		$self->{_ExactSubheading} = 1;
		$self->{_ExactPlottype} = "simple";
	}
}

sub setFormat() {
	my ($self, $format) = @_;
	if ($format eq "html") {
		$self->{_PrintHandler} = MMTests::PrintHtml->new();
	} else {
		$self->{_PrintHandler} = MMTests::PrintGeneric->new();
	}
}

sub printReportTop() {
	my ($self) = @_;
	$self->{_PrintHandler}->printTop();
}

sub printReportBottom() {
	my ($self) = @_;
	$self->{_PrintHandler}->printBottom();
}

sub printFieldHeaders() {
	my ($self) = @_;
	my @headers = ();

	push @headers, "Operation";
	push @headers, @{$self->{_FieldHeaders}};
	$self->{_PrintHandler}->printHeaders(
		$self->{_FieldLength}, \@headers,
		$self->{_FieldHeaderFormat});
}

sub printPlotHeaders() {
	my ($self) = @_;
	$self->{_PrintHandler}->printHeaders(
		$self->{_PlotLength}, $self->{_PlotHeaders},
		$self->{_FieldHeaderFormat});
}

sub _printCandlePlotData() {
	my ($self, $fieldLength, @data) = @_;

	my $stddev = calc_stddev(\@data);
	my $mean = calc_amean(\@data);
	my $min  = calc_min(\@data);
	my $max  = calc_max(\@data);
	my $low_stddev = ($mean - $stddev > $min) ? ($mean - $stddev) : $min;
	my $high_stddev = ($mean + $stddev < $max) ? ($mean + $stddev) : $max;

	printf("%${fieldLength}.3f %${fieldLength}.3f %${fieldLength}.3f %${fieldLength}.3f %${fieldLength}.3f	# stddev=%-${fieldLength}.3f\n", $low_stddev, $min, $max, $high_stddev, $mean, $stddev);
}

sub _printErrorBarData() {
	my ($self, $fieldLength, @data) = @_;

	my $stddev = calc_stddev(\@data);
	my $mean = calc_amean(\@data);

	printf("%${fieldLength}.3f %${fieldLength}.3f\n", $mean, $stddev);
}


sub _time_to_user {
	my ($self, $line) = @_;
	my ($user, $system, $elapsed, $cpu) = split(/\s/, $line);
	my @elements = split(/:/, $user);
	my ($hours, $minutes, $seconds);
	if ($#elements == 0) {
		$hours = 0;
		$minutes = 0;
		$seconds = @elements[0];
	} elsif ($#elements == 1) {
		$hours = 0;
		($minutes, $seconds) = @elements;
	} else {
		($hours, $minutes, $seconds) = @elements;
	}
	return $hours * 60 * 60 + $minutes * 60 + $seconds;
}


sub _time_to_sys {
	my ($self, $line) = @_;
	my ($user, $system, $elapsed, $cpu) = split(/\s/, $line);
	my @elements = split(/:/, $system);
	my ($hours, $minutes, $seconds);
	if ($#elements == 0) {
		$hours = 0;
		$minutes = 0;
		$seconds = @elements[0];
	} elsif ($#elements == 1) {
		$hours = 0;
		($minutes, $seconds) = @elements;
	} else {
		($hours, $minutes, $seconds) = @elements;
	}
	return $hours * 60 * 60 + $minutes * 60 + $seconds;
}

sub _time_to_elapsed {
	my ($self, $line) = @_;
	my ($user, $system, $elapsed, $cpu) = split(/\s/, $line);
	my @elements = split(/:/, $elapsed);
	my ($hours, $minutes, $seconds);
	if ($#elements == 1) {
		$hours = 0;
		($minutes, $seconds) = @elements;
	} else {
		($hours, $minutes, $seconds) = @elements;
	}
	return $hours * 60 * 60 + $minutes * 60 + $seconds;
}

sub printPlot() {
	my ($self, $subheading) = @_;
	my $fieldLength = $self->{_PlotLength};

	print "Unhandled data type for plotting.\n";
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my $fieldLength = $self->{_FieldLength};

	print "Unknown data type for summarising\n";

	return 1;
}

sub extractRatioSummary() {
	print "Unsupported\n";
}

sub filterSubheading() {
	my ($self, $subHeading, $opref) = @_;
	my @ops;

	if ($subHeading eq "") {
		return @{$opref};
	}

	foreach my $operation (@{$opref}) {
		if ($self->{_ExactSubheading} == 1) {
			if ($operation ne "$subHeading") {
				next;
			}
		} elsif ($self->{_ClientSubheading} == 1) {
			if (!($operation =~ /.*-$subHeading$/)) {
				next;
			}
		} else {
			if (!($operation =~ /^$subHeading.*/)) {
				next;
			}
		}
		push @ops, $operation;
	}

	return @ops;
}

sub getOperations() {
	my ($self, $subHeading) = @_;
	my $opref;

	if (!defined($self->{_Operations})) {
		$opref = $self->{_GeneratedOperations};
	} else {
		$opref = $self->{_Operations};
	}
	return $self->filterSubheading($subHeading, $opref);
}

sub printReport() {
	my ($self) = @_;
	my @format = ();
	my $fieldLength = $self->{_FieldLength};
	my $oplen = 0;

	foreach my $op ($self->getOperations("")) {
		if (length($op) > $oplen) {
			$oplen = length($op) + 3;
		}
	}
	push @format, "%-${oplen}s";
	push @format, "%-2d";
	push @format, @{$self->{_FieldFormat}};

	foreach my $op ($self->getOperations("")) {
		for (my $iter = 0;
		     $iter < scalar(@{$self->{_ResultData}->{$op}});
		     $iter++) {
			my $iterref = $self->{_ResultData}->{$op}->[$iter];
			for (my $dataidx = 0;
			     $dataidx < scalar(@{$iterref->{Values}});
			     $dataidx++) {
				my @row = ($op, $iter);
				my @table = ();

				push @row, $iterref->{SampleNrs}->[$dataidx];
				push @row, $iterref->{Values}->[$dataidx];
				push @table, \@row;
				$self->{_PrintHandler}->printRow(\@table, $fieldLength,
								 \@format);
			}
		}
	}
}

sub nextIteration() {
	my $self = shift;

	$self->{_CurrentIteration}++;
	if (!$self->{_ResultDataUnsorted}) {
		foreach my $op (keys %{$self->{_LastSample}}) {
			undef $self->{_LastSample}->{$op};
		}
	}
}

sub addCmd() {
	my ($self, $cmd) = @_;
	push @{$self->{_Cmd}}, $cmd;
}

sub addData() {
	my ($self, $op, $sample, $val) = @_;

	if (!$self->{_ResultDataUnsorted}) {
		if (defined($self->{_LastSample}->{$op}) &&
		    $self->{_LastSample}->{$op} > $sample) {
			$self->{_ResultDataUnsorted} = 1;
		} else {
			$self->{_LastSample}->{$op} = $sample;
		}
	}
	if (!defined($self->{_Operations})) {
		if (!defined($self->{_OperationsSeen}->{$op})) {
			push @{$self->{_GeneratedOperations}}, $op;
			$self->{_OperationsSeen}->{$op} = 1;
		}
	}

	push @{$self->{_ResultData}->{$op}->[$self->{_CurrentIteration}]->{SampleNrs}}, $sample;
	push @{$self->{_ResultData}->{$op}->[$self->{_CurrentIteration}]->{Values}}, $val;
}

sub sortResults() {
	my ($self) = @_;

	if ($self->{_ResultDataUnsorted}) {
		for my $op (keys %{$self->{_ResultData}}) {
			for (my $iter = 0;
			     $iter < scalar(@{$self->{_ResultData}->{$op}});
			     $iter++) {
				my $iterref = $self->{_ResultData}->{$op}->[$iter];

				my @indices = 0..$#{\@{$iterref->{Values}}};
				@indices = sort {
					$iterref->{SampleNrs}->[$a] <=>
					$iterref->{SampleNrs}->[$b];
				} @indices;

				$iterref->{SampleNrs} = [ map {$iterref->{SampleNrs}->[$_]} @indices ];
				$iterref->{Values} = [ map {$iterref->{Values}->[$_]} @indices ];
			}
		}
	}
}

sub discover_scaling_parameters() {
	my ($self, $reportDir, $prefix, $suffix) = @_;
	my @scaling;

	my @files = <$reportDir/$prefix*$suffix>;
	foreach my $file (<$reportDir/$prefix*$suffix>) {
		$file =~ s/.*\/$prefix//;

		if ($suffix ne "") {
			$file =~ s/$suffix$//;
		}

		push @scaling, $file;
	}

	@scaling = sort { $a <=> $b } @scaling;
	return @scaling;
}

sub open_log() {
	my ($self, $file) = @_;
	my $fh;

	$file =~ s/\.gz$//;
	$file =~ s/\.xz$//;
	if (-e "$file.gz") {
		open($fh, "gunzip -c $file.gz|") || die("Failed to open $file.gz: $!\n");
	} elsif (-e "$file.xz") {
		open($fh, "unxz -c $file.xz|") || die("Failed to open $file.xz: $!\n");
	} elsif (-e $file) {
		open($fh, $file) || die("Failed to open $file: $!\n") || die("Failed to open $file");
	}

	return $fh;
}

sub parse_time_elapsed() {
	my ($self, $log, $scaling, $iteration) = @_;

	my $input = $self->open_log($log);
	while (<$input>) {
		next if $_ !~ /elapsed/;
		$self->addData($scaling, $iteration, $self->_time_to_elapsed($_));
	}
	close($input);
}

sub parse_time_all() {
	my ($self, $log, $scaling, $iteration) = @_;

	if ($scaling >= 0) {
		$scaling = "-$scaling";
	} else {
		$scaling = "";
	}
	my $input = $self->open_log($log);
	while (<$input>) {
		next if $_ !~ /elapsed/;
		$self->addData("user$scaling", $iteration, $self->_time_to_user($_));
		$self->addData("syst$scaling", $iteration, $self->_time_to_sys($_));
		$self->addData("elsp$scaling", $iteration, $self->_time_to_elapsed($_));
	}
	close($input);
}

sub parse_time_syst_elsp() {
	my ($self, $log, $scaling, $iteration) = @_;

	if ($scaling >= 0) {
		$scaling = "-$scaling";
	} else {
		$scaling = "";
	}
	my $input = $self->open_log($log);
	while (<$input>) {
		next if $_ !~ /elapsed/;
		$self->addData("syst$scaling", $iteration, $self->_time_to_sys($_));
		$self->addData("elsp$scaling", $iteration, $self->_time_to_elapsed($_));
	}
	close($input);
}


1;
