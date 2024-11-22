# ExtractSockperfthroughput.pm
package MMTests::ExtractSockperfthroughput;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractSockperfthroughput";
	$self->{_PlotYaxis}  = DataTypes::LABEL_MBITS_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
	$self->{_PlotType}   = "client-errorlines";

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $protocol;

	my @sizes;
	my @files = <$reportDir/*-max-1.stdout>;
	foreach my $file (@files) {
		my @elements = split (/-/, $file);
		$protocol = $elements[-4];
		$protocol =~ s/.*\///;
		push @sizes, $elements[-3];
	}
	@sizes = sort {$a <=> $b} @sizes;

	foreach my $size (@sizes) {
		my $file;
		my $iteration = 0;

		foreach $file (<$reportDir/$protocol-$size-max-*.stdout>) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (!eof(INPUT)) {
				my $line = <INPUT>;

				if ($line !~ /Summary: BandWidth is.*\(([0-9.]+) Mbps\)/) {
					next;
				}

				$self->addData("$size", ++$iteration, $1);
			}
			close(INPUT);
		}
	}
}

1;
