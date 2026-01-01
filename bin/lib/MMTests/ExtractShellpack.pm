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
		$self->setSummaryMultiops()	if $yamlMap{'summarise'} eq "Multiops";
		$self->setSummarySingleops()	if $yamlMap{'summarise'} eq "Singleops";
		$self->setSummarySubselection()	if $yamlMap{'summarise'} eq "Subselection";
	}

	if (defined($yamlMap{$subHeading}) && defined($yamlMap{$subHeading}{'summarise'})) {
		$self->setSummaryMultiops()	if $yamlMap{$subHeading}{'summarise'} eq "Multiops";
		$self->setSummarySingleops()	if $yamlMap{$subHeading}{'summarise'} eq "Singleops";
		$self->setSummarySubselection()	if $yamlMap{$subHeading}{'summarise'} eq "Subselection";
	}

	# Set reporting options specified by YAML
	$self->{_Precision} = 2;
	$self->{_Precision} = $yamlMap{'DecimalPlaces'} if defined($yamlMap{'DecimalPlaces'});
	$self->{_PreferredVal} = "Higher" if (lc($yamlMap{'preferhigher'}) =~ /^(|1|higher|true)$/);
	if (defined($yamlMap{$subHeading})) {
		$self->{_PreferredVal} = "Higher" if (lc($yamlMap{$subHeading}{'preferhigher'}) =~ /^(|1|higher|true)$/);
	}

	# Set graphing options specified by YAML
	$self->{_PlotXaxis} = $self->{_PlotYaxis} = "UNKNOWN";
	$self->{_PlotType} = "candlesticks";
	$self->{_PlotXaxis} = $yamlMap{'PlotXaxis'} if defined($yamlMap{'PlotXaxis'});
	$self->{_PlotYaxis} = $yamlMap{'PlotYaxis'} if defined($yamlMap{'PlotYaxis'});
	$self->{_PlotType}  = $yamlMap{'PlotType'}  if defined($yamlMap{'PlotType'});

	printVerbose("Init    module " . $self->{_ModuleName} . " summarise " . $yamlMap{'summarise'} . "\n");
	$self->SUPER::initialise($subHeading);
}

sub open_parser() {
	my ($self, $reportDir) = @_;
	my $fh;

	printVerbose("Generic parse $reportDir\n");
	open($fh, $self->{_ShellpackParser} . " $reportDir|") || die("Failed to open pipe to " . $self->{_ShellpackParser} . " $reportDir");
	return $fh;
}

sub extractReport() {
	my ($self, $reportDir, $opt_subheading) = @_;
	my @ratioOps;
	my $fh = $self->open_parser($reportDir);

	while (!eof($fh)) {
		my $line = <$fh>;
		my ($metric, $factorA, $factorB, $interval, $value, $extra) = split(/\t/, $line);
		my $label = $metric;
		$label .= "-$factorA" if ($factorA ne "" && $factorA ne "_");
		$label .= "-$factorB" if ($factorB ne "" && $factorB ne "_");
		$self->addData($label, $interval, $value);
		if ($extra =~ /^R/) {
			push @ratioOps, $label;
		}
	}

	if (@ratioOps) {
		$self->{_RatioOperations} = \@ratioOps;
	}
	close($fh);
}

1;
