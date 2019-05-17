# ExtractEbizzy.pm
package MMTests::ExtractEbizzy;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractEbizzy";
	$self->{_DataType}   = DataTypes::DATA_ACTIONS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my @clients;
	my @files = <$reportDir/ebizzy-*-1.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-2] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $iteration = 0;

		my @files = <$reportDir/ebizzy-$client-*>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			my ($user, $sys, $records);
			while (<INPUT>) {
				my $line = $_;
				if ($line =~ /([0-9]*) records.*/) {
					$records = $1;
				}
			}
			close INPUT;
			$self->addData("Rsec-$client", $iteration, $records);
		}
	}
}

1;
