# ExtractSockperfthroughput.pm
package MMTests::ExtractSockperfthroughput;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractSockperfthroughput";
	$self->{_DataType}   = DataTypes::DATA_MBITS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_Opname}     = "Tput";
	$self->{_FieldLength} = 12;
	$self->{_SingleType} = 1;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $protocol;

	my @sizes;
	my @files = <$reportDir/$profile/*-max-1.stdout>;
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

		foreach $file (<$reportDir/$profile/$protocol-$size-max-*.stdout>) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (!eof(INPUT)) {
				my $line = <INPUT>;

				if ($line !~ /Summary: BandWidth is.*\(([0-9.]+) Mbps\)/) {
					next;
				}

				push @{$self->{_ResultData}}, [ "$size", ++$iteration, $1 ];
			}
			close(INPUT);
		}
	}
	$self->{_Operations} = \@sizes;
}

1;
