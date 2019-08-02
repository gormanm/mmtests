# ExtractBonnie.pm
package MMTests::ExtractBonnie;
use MMTests::SummariseSubselection;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSubselection);
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

	my $file = "$reportDir/bonnie-detail";
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

	if (-e "$file.gz") {
		open(INPUT, "gunzip -c $file.gz|") || die("Failed to open $file.gz\n");
	} else {
		open(INPUT, $file) || die("Failed to open $file\n");
	}
	my %nrSamples;

	while (<INPUT>) {
		chomp;
		my $line = $_;
		my @elements = split(/ /, $line);

		if (defined($ops{$elements[0]})) {
			$nrSamples{$elements[0]}++;
			$self->addData($ops{$elements[0]}, $nrSamples{$elements[0]}, $elements[1]);
		}
	}
	close INPUT;
}

1;
