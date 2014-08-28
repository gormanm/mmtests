# ExtractSummarisePlain.pm
package MMTests::ExtractSummarisePlain;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract);
use strict;

sub printDataType() {
	print "Plain";
}

sub extractSummary() {
	my ($self) = @_;
	$self->{_SummaryData} = $self->{_ResultData};

	return 1;
}
