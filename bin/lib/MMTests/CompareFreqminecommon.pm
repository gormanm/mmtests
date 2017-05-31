# CompareFreqminecommon.pm
package MMTests::CompareFreqminecommon;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareFreqminecommon",
		_DataType    => MMTests::Extract::DATA_TIME_SECONDS,
		_FieldLength => 12,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
