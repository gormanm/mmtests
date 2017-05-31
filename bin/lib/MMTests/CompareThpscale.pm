# CompareThpscale.pm
package MMTests::CompareThpscale;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareThpscale",
		_DataType    => MMTests::Extract::DATA_TIME_USECONDS,
	};
	bless $self, $class;
	return $self;
}

1;
