# ExtractTimeexit.pm
package MMTests::ExtractKu_latency;
use MMTests::SummariseVariabletime;
our @ISA = qw(MMTests::SummariseVariabletime);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractKu_latency",
		_DataType    => DATA_TIME_USECONDS;
		_Precision   => 6,
		_UseTrueMean => 1,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;

	my $file = "$reportDir/$profile/ku-latency.log";
	open(INPUT, $file) || die("Failed to open $file\n");

	my $time_kernel;
	my $time_user;
	my $nr_samples = 0;
	while (<INPUT>) {
		my $line = $_;
		my @elements = split(/:/, $_);
		my $name = $elements[0];
		$name =~ s/^\s+|\s+$//g;

		if ($name eq "time_kernel") {
			$time_kernel = $elements[1];
			$time_kernel =~ s/^\s+|\s+$//g;
		} elsif ($name eq "time_user") {
			$time_user = $elements[1];
			$time_user =~ s/^\s+|\s+$//g;
		} elsif ($name eq "Total Average") {
			# only here we are sure that printing time_user was not interrupted in the middle
			my $delta = ($time_user - $time_kernel) * 1000000;
			$self->addData("Time", ++$nr_samples, $delta);
		}
	}
	close INPUT;
}
1;
