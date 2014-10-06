# SummariseCputime.pm
package MMTests::SummariseCputime;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "SummariseCputime",
		_DataType    => MMTests::Extract::DATA_CPUTIME,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	$self->{_FieldLength} = 12;
	$self->{_SummaryLength} = 12;
        $self->{_PlotLength} = 12;
	$self->{_FieldHeaders} = [ "User", "System", "Elapsed", "CPU" ];

	$self->{_SummaryHeaders} = [ "Operation", "User", "System", "Elapsed", "CPU" ];
        $self->{_PlotHeaders} = [ "LowStddev", "Min", "Max", "HighStddev", "Mean" ];

	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s",  "%${fieldLength}d", "%${fieldLength}.2f", "%${fieldLength}.2f", "%${fieldLength}d" ];

	$self->{_TestName} = $testName;
}

sub printDataType() {
	print "CPUTime,TestName,Time,candlesticks";
}

sub printPlot() {
	my ($self, $subheading) = @_;
	my $fieldLength = $self->{_PlotLength};
	my $column;

	# Figure out which column we need
	if ($subheading eq "User") {
		$column = 0;
	} elsif ($subheading eq "System") {
		$column = 1;
	} elsif ($subheading eq "Elapsed") {
		$column = 2;
	} elsif ($subheading eq "CPU") {
		$column = 3;
	} else {
		print("Unknown sub-heading '$subheading', specify --sub-heading\n");
		return;
	}
	$self->_printCandlePlot($fieldLength - 1, $column);
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @formatList;
	my $fieldLength = $self->{_FieldLength};
	if (defined $self->{_FieldFormat}) {
		@formatList = @{$self->{_FieldFormat}};
	}

	my (@user, @sys, @elapsed, @cpu);

	foreach my $row (@{$self->{_ResultData}}) {
		my @rowArray = @{$row};
		push @user,    $rowArray[0];
		push @sys,     $rowArray[1];
		push @elapsed, $rowArray[2];
		push @cpu,     $rowArray[3];
	}

	$self->{_FieldFormat} = [ "%-${fieldLength}s" ];
	foreach my $funcName ("calc_min", "calc_mean", "calc_stddev", "calc_coeffvar", "calc_max") {
		no strict "refs";
		my $op = $funcName;
		$op =~ s/calc_//;

		push @{$self->{_SummaryData}}, [$op,
						&$funcName(@user),
						&$funcName(@sys),
						&$funcName(@elapsed),
						&$funcName(@cpu) ];
	}

	return 1;
}

sub printReport() {
	my ($self) = @_;
	$self->{_PrintHandler}->printRow($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);
	my $file = "$reportDir/noprofile/time";

	if (! -e $file) {
		$file = "$reportDir/fine-profile-timer/time";
	}

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		$_ =~ tr/[a-zA-Z]%//d;
		($user, $system, $elapsed, $cpu) = split(/\s/, $_);
		my @elements = split(/:/, $elapsed);
		my ($hours, $minutes, $seconds);
		if ($#elements == 1) {
			$hours = 0;
			($minutes, $seconds) = @elements;
		} else {
			($hours, $minutes, $seconds) = @elements;
		}
		$elapsed = $hours * 60 * 60 + $minutes * 60 + $seconds;
		
		push @{$self->{_ResultData}}, [ $user, $system, $elapsed, $cpu ];
	}
	close INPUT;
}

1;
