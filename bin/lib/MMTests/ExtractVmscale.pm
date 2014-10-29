package MMTests::ExtractVmscale;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractVmscale",
		_DataType    => MMTests::Extract::DATA_WALLTIME,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	my ($self) = @_;
	print "Operations,Test,Variable";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my @cases;

	open(INPUT, "$reportDir/noprofile/cases") || die "Failed to open cases file";
	while (!eof(INPUT)) {
		my $line = <INPUT>;
		chomp($line);
		push @cases, $line;
	}
	close(INPUT);
	$self->{_Cases} = \@cases;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength} = 30;
	$self->{_TestName} = $testName;
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%$fieldLength.2f" ];
	$self->{_FieldHeaders} = [ "Test", "Metric", "Value" ];
}

sub extractSummary() {
	my ($self) = @_;
	$self->{_SummaryData} = $self->{_ResultData};
	return 1;
}

sub c2s($$) {
	return sprintf "%18s %10s", $_[0], $_[1];
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my @cases = @{$self->{_Cases}};

	foreach my $case (@cases) {
		open(INPUT, "$reportDir/noprofile/$case.time") ||
			die("Failed to open $reportDir/noprofile/$case.time");
		while (!eof(INPUT)) {
			my $line = <INPUT>;
			next if $line !~ /elapsed/;
			push @{$self->{_ResultData}}, [ c2s($case, "elapsed"), $self->_time_to_elapsed($line) ];
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
			push @{$self->{_ResultData}}, [ c2s($case, "time_range"),  calc_range(@values) ];
			push @{$self->{_ResultData}}, [ c2s($case, "time_stddv"), calc_stddev(@values) ];
		}

		close(INPUT);
	}
}

1;
