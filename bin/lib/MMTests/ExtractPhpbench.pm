# ExtractPhpbench.pm
package MMTests::ExtractPhpbench;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractPhpbench";
	$self->{_DataType}   = DataTypes::DATA_ACTIONS;
	$self->{_PlotType}   = "operation-candlesticks";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $recent = 0;

	my @files = <$reportDir/phpbench-*.log>;
	my $iteration = 1;
	foreach my $file (@files) {
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			next if $line !~ /^Score/;
			my @elements = split(/\s+/, $line);

			$self->addData("Score", $iteration, $elements[2]);

		}
		close INPUT;
	}
}

1;
