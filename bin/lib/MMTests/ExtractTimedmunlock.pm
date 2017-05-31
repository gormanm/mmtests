# ExtractTimedmunlock.pm
package MMTests::ExtractTimedmunlock;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractTimedmunlock",
		_DataType    => DataTypes::DATA_TIME_USECONDS,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($user, $system, $elapsed, $cpu);
	my $file = "$reportDir/$profile/timedmunlock.time";

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		$_ =~ tr/[a-zA-Z]%//d;
		$elapsed = $_ / 1000000000;

		push @{$self->{_ResultData}}, [ 0, 0, $elapsed, 0 ];
	}
	close INPUT;
}

1;
