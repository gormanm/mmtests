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
	my ($self, $reportDir) = @_;

	my @ops;
	my @clients;
	my @files = <$reportDir/tlbflush-*.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $iteration = 0;

		my $file = "$reportDir/tlbflush-$client.log";
		open(INPUT, $file) || die("Failed to open $file\n");
		my ($user, $sys, $records);
		while (<INPUT>) {
			if ($_ =~ /.*, cost ([0-9]*)ns.*/) {
				$self->addData("nsec-$client", ++$iteration, $1);
			}
		}
		close INPUT;
	}
}

1;
