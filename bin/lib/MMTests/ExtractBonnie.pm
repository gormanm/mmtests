# ExtractBonnie.pm
package MMTests::ExtractBonnie;
use MMTests::SummariseVariabletime;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseVariabletime);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractBonnie";
	$self->{_DataType}   = DataTypes::DATA_TIME_USECONDS;
	$self->{_PlotType}   = "simple-samples";
	$self->{_DefaultPlot} = "SeqOut Block";
	$self->{_ExactSubheading} = 1;
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $recent = 0;

	my @files = <$reportDir/bonnie-detail.*>;
	my $iteration = 1;
	my %ops = (
		"pc" => "SeqOut Char",
		"wr" => "SeqOut Block",
		"rw" => "SeqOut Rewrite",
		"gc" => "SeqIn Char",
		"rd" => "SeqIn Block",
		"sk" => "Random seeks",
		"cs" => "SeqCreate create",
		"ss" => "SeqCreate read",
		"ds" => "SeqCreate del",
		"cr" => "RandCreate create",
		"sr" => "RandCreate read",
		"dr" => "RandCreate del"
	);

	foreach my $file (@files) {
		if ($file =~ /.*\.gz$/) {
			open(INPUT, "gunzip -c $file|") || die("Failed to open $file\n");
		} else {
			open(INPUT, $file) || die("Failed to open $file\n");
		}
		while (<INPUT>) {
			chomp;
			my $line = $_;
			my @elements = split(/ /, $line);

			if (defined($ops{$elements[0]})) {
				$self->addData($ops{$elements[0]}, $iteration, $elements[1]);
			}
		}
		close INPUT;
		$iteration++;
	}
}

1;
