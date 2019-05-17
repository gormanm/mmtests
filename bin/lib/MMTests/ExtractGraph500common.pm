# ExtractGraph500common.pm
package MMTests::ExtractGraph500common;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractGraph500",
		_DataType    => DataTypes::DATA_OPS_PER_SECOND,
		_PlotType    => "histogram",
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $iteration = 0;

	open(INPUT, "$reportDir/graph500.log");
	while (!eof(INPUT)) {
		my $line = <INPUT>;

		if ($line =~ /firstquartile_TEPS: ([0-9e+.]*)/ ||
				$line =~ /median_TEPS: ([0-9e.+]*)/ ||
				$line =~ /thirdquartile_TEPS: ([0-9e.+]*)/) {
			my $mteps = $1 / 1e+6;
			$iteration++;
			$self->addData("megaTEPS", $iteration, $mteps);
		}
	}
	close (INPUT);
}

1;
