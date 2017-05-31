# CompareBlogbench.pm
package MMTests::CompareBlogbench;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareBlogbench",
		_DataType    => MMTests::Extract::DATA_ACTIONS,
		_FieldLength => 16,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
