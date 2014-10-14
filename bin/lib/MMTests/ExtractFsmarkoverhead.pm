# ExtractFsmarkoverhead.pm
package MMTests::ExtractFsmarkoverhead;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractFsmarkoverhead",
		_DataType    => MMTests::Extract::DATA_TIME_USECONDS,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	print "Operations/sec,TestName,Latency,candlesticks";
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $elapsed, $cpu);
	$reportDir =~ s/overhead//;
	my $file = "$reportDir/noprofile/fsmark.log";
	my $preamble = 1;
	my $iteration = 1;

        $self->{_CompareLookup} = {
                "files/sec" => "pdiff",
                "overhead"  => "pndiff"
        };

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;
		if ($preamble && $line !~ /^FSUse/) {
			next;
		}
		$preamble = 0;
		if ($line =~ /[a-zA-Z]/) {
			next;
		}

		my @elements = split(/\s+/, $_);
		push @{$self->{_ResultData}}, [ "overhead",  ++$iteration, $elements[5] ];
	}
	close INPUT;

	$self->{_Operations} = [ "overhead" ];
}

1;
