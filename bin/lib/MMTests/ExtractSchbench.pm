# ExtractSchbench.pm
package MMTests::ExtractSchbench;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractSchbench";
	$self->{_DataType}   = MMTests::Extract::DATA_TIME_USECONDS;
	$self->{_PlotXaxis}  = "Threads";
	$self->{_FieldLength} = 12;
	$self->{_ExactSubheading} = 1;
	$self->{_ExactPlottype} = "simple";
	$self->{_DefaultPlot} = "1";
	$self->{_Variable} = 1;

	$self->SUPER::initialise($reportDir, $testName);

	$self->{_SummaryHeaders} = [ "Unit", "Min", "50th-qrtle", "75th-qrtle", "90th-qrtle", "95th-qrtle", "99th-qrtle", "99.5th-qrtle", "99.9th-qrtle", "Max" ];
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	my @files = <$reportDir/noprofile/schbench-*.log>;
	my @groups;

	foreach my $file (@files) {
		my @split = split /-/, $file;
		my $group = $split[-1];

		$group =~ s/([0-9]+).*/$1/;

		push @groups, $group
	}
	@groups = sort { $a <=> $b } @groups;

	foreach my $group (@groups) {
		open(INPUT, "$reportDir/noprofile/schbench-$group.log") || die("Failed to open $group\n");
		while (<INPUT>) {
			if ($_ =~ /[ \t\*]+([0-9]+)\.[0-9]+th: ([0-9]+)/) {
				push @{$self->{_ResultData}}, [$group, $1, $2];
			} elsif ($_ =~ /min=([0-9]+), max=([0-9]+)/) {
				push @{$self->{_ResultData}}, [$group, "LatMin", $1];
				push @{$self->{_ResultData}}, [$group, "LatMax", $2];
			}
		}
		close INPUT;
	}

	$self->{_Operations} = \@groups;
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @_operations = @{$self->{_Operations}};
	my @data = @{$self->{_ResultData}};

	if ($subHeading ne "") {
		my $index = 0;
		while ($index <= $#_operations) {
			if ($_operations[$index] =~ /^$subHeading.*/) {
				$index++;
				next;
			}
			splice(@_operations, $index, 1);
		}
	}

	foreach my $operation (@_operations) {
		my @units;
		my @row;
		foreach my $row (@data) {
			if (@{$row}[0] eq "$operation") {
				push @units, @{$row}[2];
			}
		}

		push @row, $operation;
		push @row, $units[7];
		push @row, $units[0];
		push @row, $units[1];
		push @row, $units[2];
		push @row, $units[3];
		push @row, $units[4];
		push @row, $units[5];
		push @row, $units[6];
		push @row, $units[8];

		push @{$self->{_SummaryData}}, \@row;
	}

	return 1;
}
