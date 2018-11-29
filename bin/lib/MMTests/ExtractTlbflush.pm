# ExtractTlbflush.pm
package MMTests::ExtractTlbflush;
use MMTests::SummariseVariabletime;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseVariabletime);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractTlbflush";
	$self->{_DataType}   = DataTypes::DATA_TIME_NSECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;

	my @ops;
	my @clients;
	my @files = <$reportDir/$profile/tlbflush-*.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $iteration = 0;

		my $file = "$reportDir/$profile/tlbflush-$client.log";
		open(INPUT, $file) || die("Failed to open $file\n");
		my ($user, $sys, $records);
		while (<INPUT>) {
			if ($_ =~ /.*, cost ([0-9]*)ns.*/) {
				push @{$self->{_ResultData}}, [ "nsec-$client", ++$iteration, $1 ];
				if ($iteration == 1) {
					push(@ops, "nsec-$client");
				}
			}
		}
		close INPUT;
	}

	$self->{_Operations} = \@ops;
}

1;
