# ExtractLibmicro.pm
package MMTests::ExtractLibmicro;
use MMTests::SummariseSingleops;
use VMR::Report;
our @ISA = qw(MMTests::SummariseSingleops); 

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractLibmicro",
		_DataType    => MMTests::Extract::DATA_WALLTIME,
		_ResultData  => [],
		_UseTrueMean => 1,
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);

	my @files = <$reportDir/noprofile/*.log>;
	my @ops;
	foreach my $file (@files) {
		my $testname = $file;
		$testname =~ s/.*\///;
		$testname =~ s/\.log$//;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			if ($_ =~ /^$testname /) {
				my @elements = split(/\s+/);
				push @{$self->{_ResultData}}, [$testname, $elements[3]];
				push @ops, $testname;
			}
		}
		close INPUT;
	}
	$self->{_Operations} = \@ops;
}
1;
