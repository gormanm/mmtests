# SummariseVariableops.pm
package MMTests::SummariseVariableops;
use MMTests::SummariseVariabletime;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseVariabletime);
use strict;

sub initialise() {
        my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise($reportDir, $testName);
}

