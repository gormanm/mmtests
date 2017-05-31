# CompareFsmarkoverhead.pm
package MMTests::CompareFsmarkoverhead;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareFsmarkoverhead",
		_DataType    => MMTests::Extract::DATA_TIME_USECONDS,
		_FieldLength => 12,
		_CompareOps  => [ "none", "pdiff", "pdiff", "pdiff", "pndiff", "pdiff" ],
		_CompareLength => 6,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
