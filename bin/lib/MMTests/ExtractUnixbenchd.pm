# ExtractUnixbench.pm
package MMTests::ExtractUnixbenchd;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $nr_samples = 0;

	open(INPUT, "$reportDir/unixbenchd.log") || die "Failed to open unixbenchd.log";
	while (<INPUT>) {
		my $line = $_;
		next if $line !~ /^COUNT/;

		my @elements = split(/\|/, $line);

		$self->addData("unixbenchd-ops", ++$nr_samples, $elements[1]);
	}
	close INPUT;
}
