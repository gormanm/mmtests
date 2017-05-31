# ExtractMonitor.pm
package MMTests::ExtractMonitor;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractMonitor",
		_DataType    => DataTypes::DATA_NONE,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	return 1;
}

1;
