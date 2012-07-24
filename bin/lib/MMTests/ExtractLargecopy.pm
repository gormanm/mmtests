# ExtractLargecopy.pm
package MMTests::ExtractLargecopy;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractLargecopy",
		_DataType    => MMTests::Extract::DATA_WALLTIME,
		_FieldLength => 12,
		_ExtractOp   => "pndiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
