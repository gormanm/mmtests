# CompareTiobench.pm
package MMTests::CompareTiobench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareTiobench",
		_DataType    => MMTests::Extract::DATA_THROUGHPUT,
		_FieldLength => 12,
		_CompareOp   => "pdiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
