# CompareCputime.pm
package MMTests::CompareCputime;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareCputime",
		_FieldLength => 12,
		_CompareOp   => "pndiff",
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

1;
