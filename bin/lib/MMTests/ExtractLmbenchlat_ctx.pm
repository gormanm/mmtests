# ExtractLmbenchlat_ctx
package MMTests::ExtractLmbenchlat_ctx;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractLmbenchlat_ctx";
	$self->{_DataType}   = DataTypes::DATA_TIME_USECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_ExactPlottype} = "simple";
	$self->{_ExactSubheading} = 1;
	$self->SUPER::initialise($subHeading);
}

my %nr_samples;

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients;

	@clients = $self->discover_scaling_parameters($reportDir, "lmbench-lat_ctx-", "-1.log");
	
	print "CLIENTS: @clients\n";

	foreach my $client (@clients) {
		my @files = <$reportDir/lmbench-lat_ctx-$client-*.log>;
		my $iteration = 0;
		my $size = -1;

		foreach my $file (@files) {
			my $input = $self->SUPER::open_log($file);

			while (<$input>) {
				my $line = $_;
				if ($line =~ /^mmtests_size: ([0-9]+)/) {
					$size = $1;
					next;
				}
				if ($line =~ /^[0-9].*/) {
					my @elements = split(/\s+/, $line);
					$nr_samples{"$elements[0]-$size"}++;

					$self->addData("$client-$size", $nr_samples{"$client-$size"}, $elements[1]);
					next
				}
			}

			close($input);
		}
	}
}

1;
