# ExtractSysjitter.pm
package MMTests::ExtractSysjitter;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops);
use MMTests::Stat;
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractSysjitter";
	$self->{_DataType}   = DataTypes::DATA_TIME_NSECONDS;
	$self->{_PlotType}   = "histogram";
	$self->{_Opname}     = "Time";
	$self->{_SingleType} = 1;
	$self->{_FieldLength} = 14;
	$self->{_ClientSubheading} = 1;

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $nr_cpus;
	my @cpus;

	open(INPUT, "$reportDir/$profile/sysjitter.log") || die "Failed to open sysjitter.log";
	while (!eof(INPUT)) {
		my $line = <INPUT>;
		chomp($line);

		if ($line =~ /^core_i:/) {
			@cpus = split(/\s+/, $line);
			shift @cpus;
			next;
		}
		next if $line =~ /^threshold/;
		next if $line =~ /^cpu_mhz/;
		next if $line =~ /^runtime/;
		# next if $line =~ /^int_total\(ns\)/;

		$line =~ s/://;
		$line =~ s/\(ns\)//;
		my @elements = split(/\s+/, $line);
		my $metric = shift @elements;

		my $i = 0;
		foreach my $value (@elements) {
			$self->addData("cpu$cpus[$i]-$metric", 0, $value);
			$i++;
		}
	}

}

1;
