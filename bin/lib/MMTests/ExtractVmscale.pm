package MMTests::ExtractVmscale;
use MMTests::SummariseSingleops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	my $fieldLength = $self->{_FieldLength} = 25;
	$self->{_ModuleName} = "ExtractVmscale";
	$self->{_DataType} = MMTests::Extract::DATA_TIME_SECONDS;
	$self->{_TestName} = $testName;
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%$fieldLength.2f" ];
	$self->{_FieldHeaders} = [ "Test", "Metric", "Value" ];
	$self->{_SingleType} = 1;

	$self->SUPER::initialise($reportDir, $testName);
	$self->{_RatioPreferred} = "Lower";
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my @cases;

	open(INPUT, "$reportDir/noprofile/cases") || die "Failed to open cases file";
	while (!eof(INPUT)) {
		my $line = <INPUT>;
		chomp($line);
		push @cases, $line;
	}
	close(INPUT);
	$self->{_Cases} = \@cases;
	my %ops;

	foreach my $case (@cases) {
		open(INPUT, "$reportDir/noprofile/$case.time") ||
			die("Failed to open $reportDir/noprofile/$case.time");
		while (!eof(INPUT)) {
			my $line = <INPUT>;
			next if $line !~ /elapsed/;
			push @{$self->{_ResultData}}, [ "$case-elapsed", $self->_time_to_elapsed($line) ];
			$ops{"$case-elapsed"} = 1;
		}
		close(INPUT);

		open(INPUT, "$reportDir/noprofile/$case.log") ||
			die("Failed to open $reportDir/noprofile/$case.log");

		if ($case eq "lru-file-readonce" || $case eq "lru-file-readtwice") {
			my @values;
			while (!eof(INPUT)) {
				my $line = <INPUT>;
				next if $line !~ /elapsed/;
				push @values, $self->_time_to_elapsed($line);
			}
			push @{$self->{_ResultData}}, [ "$case-time_range",  calc_range(@values) ];
			push @{$self->{_ResultData}}, [ "$case-time_stddv", calc_stddev(@values) ];
		}

		close(INPUT);
	}
	$self->{_SingleInclude} = \%ops;
}

1;
