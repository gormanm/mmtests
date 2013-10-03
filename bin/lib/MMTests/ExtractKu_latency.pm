# ExtractTimeexit.pm
package MMTests::ExtractKu_latency;
use MMTests::Extract;
use VMR::Report;
our @ISA = qw(MMTests::Extract); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractKu_latency",
		_DataType    => MMTests::Extract::DATA_WALLTIME_OUTLIERS,
		_ResultData  => [],
		_Precision   => 6,
		_UseTrueMean => 1,
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	print "WalltimeOutliers,TestName,Time\n";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%$fieldLength.6f", "%$fieldLength.6f", "%$fieldLength.6f", "%$fieldLength.6f", "%$fieldLength.6f" ];
	$self->{_FieldHeaders} = [ "Latency" ];
	$self->{_TestName} = $testName;
}

sub printPlot() {
	my ($self, $subheading) = @_;

	$self->_printCandlePlot($self->{_FieldLength}, 1);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	my $file = "$reportDir/noprofile/ku-latency.log";
	open(INPUT, $file) || die("Failed to open $file\n");

	my $time_kernel;
	my $time_user;
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
			push @{$self->{_ResultData}}, [0, $delta];
		}
	}
	close INPUT;
}
1;
