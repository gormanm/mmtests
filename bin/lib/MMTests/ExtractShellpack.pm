# ExtractShellpack.pm
package MMTests::ExtractShellpack;
use MMTests::Report;
use MMTests::Summarise;
use MMTests::DataTypes;
use YAML::PP;
our @ISA = qw(MMTests::Summarise);

use strict;

sub initialise() {
	my ($self, $subHeading) = @_;

	# Load config options from YAML
	my $yaml = YAML::PP->new;
	my @documents = $yaml->load_file($self->{_ShellpackConfig});
	my %yamlMap = %{$documents[0]};

	if (defined($yamlMap{'summarise'})) {
		$self->setSummaryMultiops()		if $yamlMap{'summarise'} eq "Multiops";
		$self->setSummaryNormalisedops()	if $yamlMap{'summarise'} eq "Normalisedops";
		$self->setSummarySingleops()		if $yamlMap{'summarise'} eq "Singleops";
		$self->setSummarySubselection()		if $yamlMap{'summarise'} eq "Subselection";
	}

	if (defined($yamlMap{$subHeading}) && defined($yamlMap{$subHeading}{'summarise'})) {
		$self->setSummaryMultiops()	if $yamlMap{$subHeading}{'summarise'} eq "Multiops";
		$self->setSummarySingleops()	if $yamlMap{$subHeading}{'summarise'} eq "Singleops";
		$self->setSummarySubselection()	if $yamlMap{$subHeading}{'summarise'} eq "Subselection";
	}

	# Set reporting options specified by YAML
	$self->{_Precision} = 2;
	$self->{_Precision} = $yamlMap{'DecimalPlaces'} if defined($yamlMap{'DecimalPlaces'});
	$self->{_PreferredVal} = "Lower";
	$self->{_PreferredVal} = "Higher" if (defined($yamlMap{'preferhigher'}) &&
					      lc($yamlMap{'preferhigher'}) =~ /^(|1|higher|true)$/);
	$self->{_PreferredVal} = "Higher" if (defined($yamlMap{$subHeading}{'preferhigher'}) &&
					      lc($yamlMap{$subHeading}{'preferhigher'}) =~ /^(|1|higher|true)$/);
	printVerbose("Improve val if $self->{_PreferredVal}\n");
	# Set graphing options specified by YAML
	$self->{_PlotXaxis} = $self->{_PlotYaxis} = "UNKNOWN";
	$self->{_PlotType} = "lines";
	$self->{_PlotXaxis} = $yamlMap{'PlotXaxis'} if defined($yamlMap{'PlotXaxis'});
	$self->{_PlotYaxis} = $yamlMap{'PlotYaxis'} if defined($yamlMap{'PlotYaxis'});
	$self->{_PlotType}  = $yamlMap{'PlotType'}  if defined($yamlMap{'PlotType'});

	printVerbose("Init    module " . $self->{_ModuleName} . " summarise " . $yamlMap{'summarise'} . " plot " . $self->{_PlotType} . "\n");
	$self->SUPER::initialise($subHeading);
}

sub open_parser() {
	my ($self, $reportDir, $opt_altreport) = @_;
	my $fh;

	printVerbose("Generic parse $reportDir $opt_altreport\n");
	open($fh, $self->{_ShellpackParser} . " $reportDir $opt_altreport|") || die("Failed to open pipe to " . $self->{_ShellpackParser} . " $reportDir");
	return $fh;
}

sub extractReport() {
	my ($self, $reportDir, $opt_subheading, $opt_altreport) = @_;
	my @ratioOps;
	my %seenOps;
	my $fh = $self->open_parser($reportDir, $opt_altreport);

	while (!eof($fh)) {
		my $line = <$fh>;
		my ($metric, $factorA, $factorB, $interval, $value, $extra) = split(/\t/, $line);
		my $label = $metric;
		$label .= "-$factorA" if ($factorA ne "" && $factorA ne "_");
		$label .= "-$factorB" if ($factorB ne "" && $factorB ne "_");
		$self->addData($label, $interval, $value) if (!defined($opt_subheading) || $label =~ /$opt_subheading/);
		if ($extra =~ /^R/ && $seenOps{$label} != 1) {
			push @ratioOps, $label;
			$seenOps{$label} = 1;
		}
	}

	if (@ratioOps) {
		$self->{_RatioOperations} = \@ratioOps;
	}
	close($fh);
}

1;
