# ExtractEbizzy.pm
package MMTests::ExtractEbizzy;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my $class = shift;
	$self->{_ModuleName} = "ExtractEbizzy";
	$self->{_DataType}   = MMTests::Extract::DATA_MBYTES_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;

	my @clients;
	my @files = <$reportDir/$profile/ebizzy-*-1.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-2] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $iteration = 0;

		my @files = <$reportDir/$profile/ebizzy-$client-*>;
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
			push @{$self->{_ResultData}}, [ "Rsec-$client", $iteration, $records ];
		}
	}

	my @ops;
	foreach my $client (@clients) {
		push @ops, "Rsec-$client";
	}
	$self->{_Operations} = \@ops;
}

1;
