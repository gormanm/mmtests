# ExtractSockperfunderload.pm
package MMTests::ExtractSockperfunderload;
use MMTests::SummariseVariabletime;
our @ISA = qw(MMTests::SummariseVariabletime);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSockperfunderload",
		_DataType    => DataTypes::DATA_TIME_USECONDS,
		_Opname      => "Round-Trip-Time",
		_PlotType    => "simple-filter-points",
	};
	bless $self, $class;
	return $self;
}

sub uniq {
	my %seen;
	grep !$seen{$_}++, @_;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($protocol);

	my (@sizes, @rates);
	my @files = <$reportDir/*-*-1.log*>;
	foreach my $file (@files) {
		my @elements = split (/-/, $file);
		$protocol = $elements[-4];
		$protocol =~ s/.*\///;

		# Do not process the max rates any more. The dropped packets
		# confuse everything.
		next if $elements[-2] eq "max";

		push @sizes, $elements[-3];
		push @rates, $elements[-2];
	}
	@sizes = uniq(sort {$a <=> $b} @sizes);
	@rates = uniq(sort {$a <=> $b} @rates);

	foreach my $size (@sizes) {
		foreach my $rate (@rates) {
			my $file = "$reportDir/$protocol-$size-$rate-1.log";
			if (-e $file) {
				open(INPUT, $file) || die("Failed to open $file\n");
			} else {
				open(INPUT, "gunzip -c $file.gz|") || die("Failed to open $file.gz\n");
			}
			my $start_time = 0;

			my $sample = 0;
			while (!eof(INPUT)) {
				my $line = <INPUT>;

				next if $line !~ /^([0-9.]+), ([0-9.]+)/;

				# This is how sockperf calculates rtt internally.
				# Not sure what the /2 is about but without it
				# the report differences from what sockperf
				# spits out in its summary.
				my $rtt = ($2-$1) * 1000000 / 2;
				my $time = $1;

				if (!$start_time) {
					$start_time = $time;
				}

				$self->addData("size-$size-rate-$rate", ($time - $start_time), $rtt);
			}
			close(INPUT);
		}
	}
	close INPUT;
}
1;
