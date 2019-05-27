# ExtractXfsioops.pm
package MMTests::ExtractXfsioops;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractXfsioops";
	$self->{_DataType}   = DataTypes::DATA_OPS_PER_SECOND;
	$self->{_FieldLength} = 12;

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iteration = 0;

	foreach my $file (<$reportDir/*-log.*>) {
		my $testcase = $file;
		$testcase =~ s/.*\///;
		$testcase =~ s/-log.*//;

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			next if $_ !~ /.*and ([0-9.]+) ops\/sec.*/;
			$self->addData("$testcase-ops", ++$iteration, $1);
		}
		close(INPUT);
	}
}

1;
