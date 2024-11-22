# ExtractXfsio.pm
package MMTests::ExtractXfsio;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractXfsio";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_SECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($tm, $tput, $latency);
	my $iteration;
	my $testcase;

	foreach my $file (<$reportDir/*-time.*>) {
		$testcase = $file;
		$testcase =~ s/.*\///;
		$testcase =~ s/-time.*//;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			next if $_ !~ /elapsed/;
			$self->addData("$testcase-System", ++$iteration, $self->_time_to_sys($_));
			$self->addData("$testcase-Elapsd", ++$iteration, $self->_time_to_elapsed($_));
		}
		close(INPUT);
	}
}

1;
