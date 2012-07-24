# ExtractFsmark.pm
package MMTests::ExtractFsmark;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractFsmark",
		_DataType    => MMTests::Extract::DATA_OPSSEC,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength};

	$self->{_TestName} = $testName;
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%$fieldLength.2f" , "%${fieldLength}d" ];
	$self->{_FieldHeaders} = [ "Iteration", "Files/sec", "Overhead" ];
}

sub _setSummaryColumn() {
	my ($self, $subHeading) = @_;

	if ($subHeading eq "Files/sec") {
		$self->{_SummariseColumn} = 1;
	} elsif ($subHeading eq "Overhead") {
		$self->{_SummariseColumn} = 2;
	} else {
		die("Unrecognised summarise header '$subHeading' for Fsmark");
	}
}

sub printPlot() {
	my ($self, $subHeading) = @_;

	$self->_setSummaryColumn($subHeading);
	$self->SUPER::printPlot();
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	$self->_setSummaryColumn($subHeading);
	$self->SUPER::extractSummary($subHeading);
}

sub printSummary() {
	my ($self, $subHeading) = @_;

	$self->_setSummaryColumn($subHeading);
	$self->SUPER::printSummary($subHeading);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);
	my $file = "$reportDir/noprofile/fsmark.log";
	my $preamble = 1;
	my $iteration = 1;

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;
		if ($preamble && $line !~ /^FSUse/) {
			next;
		}
		$preamble = 0;
		if ($line =~ /[a-zA-Z]/) {
			next;
		}

		my @elements = split(/\s+/, $_);
		push @{$self->{_ResultData}}, [ $iteration, $elements[4], $elements[5] ];
		$iteration++;
	}
	close INPUT;
}

1;
