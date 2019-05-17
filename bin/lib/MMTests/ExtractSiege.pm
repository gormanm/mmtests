# ExtractSiege.pm
package MMTests::ExtractSiege;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractSiege";
	$self->{_DataType}   = DataTypes::DATA_TRANS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @clients;
	my @files = <$reportDir/siege-*-1.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my @files = <$reportDir/siege-$client-*.log>;
		my $iteration = 0;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (!eof(INPUT)) {
				my $line = <INPUT>;
				next if $line !~ /Transaction rate:/;
				my @elements = split(/\s+/, $line);
				$self->addData($client, ++$iteration, $elements[-2]);
			}
			close INPUT;
		}
	}
}

1;
