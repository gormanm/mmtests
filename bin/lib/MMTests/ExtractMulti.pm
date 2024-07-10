# ExtractMulti.pm
package MMTests::ExtractMulti;
use MMTests::ExtractFactory;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractMulti",
		_DataType    => DataTypes::DATA_NONE,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	open(INPUT, "$reportDir/multi.list") || die("Failed to open $reportDir/multi.list");
	while (!eof(INPUT)) {
		$altModule = <INPUT>;
		chomp($altModule);
	}
	close INPUT;

	$reportDir =~ s@/multi/@/$altModule/@;

	my $extractFactory = MMTests::ExtractFactory->new();
	my $altExtract = $extractFactory->loadModule("extract", $altModule, $self->{"_TestName"}, "");
	$altExtract->initialise();
	$altExtract->extractReport($reportDir);

	foreach my $datafield ("_ResultDataUnsorted", "_ResultDataUnsorted", "_LastSample", "_Operations", "_OperationsSeen", "_GeneratedOperations", "_OperationsSeen", "_ResultData") {
		$self->{$datafield} = $altExtract->{$datafield};
	}
}
1;
