# ExtractAdrestia.pm
package MMTests::ExtractAdrestia;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractAdrestia";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_USECONDS;
	$self->{_Precision} = 4;

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($user, $system, $elapsed, $cpu);

	my @files = <$reportDir/adrestia-*-1.log>;
	my @tmp;
	my @threads;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @tmp, $split[-3];
	}

	my @groups = do { my %seen; grep { !$seen{$_}++ } @tmp };
	my @threads = $self->discover_scaling_parameters($reportDir, "adrestia-$groups[0]-", "-1.log");

	@groups = sort { $a <=> $b} @groups;
	@threads = sort { $a <=> $b} @threads;

	foreach my $thread (@threads) {
		foreach my $group (@groups) {
			my $nr_samples = 0;
			foreach my $file (<$reportDir/adrestia-$group-$thread-*.log*>) {
				my @split = split /-/, $file;

				my $input = $self->SUPER::open_log($file);
				while (<$input>) {
					if ($_ !~ /^wakeup cost.*: (.*)us/) {
						next;
					}
					my $walltime = $1;
					$self->addData("$thread-$group", ++$nr_samples, $walltime);
				}

				close $input;
			}
		}
	}
}
1;
