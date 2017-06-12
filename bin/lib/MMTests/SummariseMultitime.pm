# SummariseMultitime.pm
package MMTests::SummariseMultitime;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
        my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise($reportDir, $testName);
}

