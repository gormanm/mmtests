# CompareTlbflush.pm
package MMTests::CompareTlbflush;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareTlbflush",
		_DataType    => MMTests::Compare::DATA_TIME_NSECONDS,
	};
	bless $self, $class;
	return $self;
}

1;
