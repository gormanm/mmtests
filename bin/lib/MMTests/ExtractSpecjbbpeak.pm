# ExtractSpecjbbpeak.pm
package MMTests::ExtractSpecjbbpeak;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

use constant DATA_SPECJBB_PEAK     => 900;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSpecjbbpeak",
		_DataType    => DATA_SPECJBB_PEAK,
		_ResultData  => [],
		_FieldLength => 17,
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	print "NrWarehouses\n";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%${fieldLength}d", "%${fieldLength}d", "%${fieldLength}s" ];
	$self->{_FieldHeaders} = [ "JVMInstance", "Warehouses", "Bops", "Included" ];
	$self->{_SummaryHeaders} = [ "Metric", "" ];
	$self->{_SummaryLength} = 17;
	$self->{_TestName} = $testName;
}

sub extractSummary() {
	my ($self) = @_;
	my @data = @{$self->{_ResultData}};
	my @instances = @{$self->{_JVMInstances}};
	my $specjbb_bops = $self->{_SpecJBBBops};
	my $specjbb_bopsjvm = $self->{_SpecJBBBopsJVM};
	my $peak_warehouse = 0;
	my $peak_bops;
	my $expected_peak = $self->{_ExpectedPeak};
	my $expected_bops = 0;

	# Bodge
	my $fieldLength = $self->{_FieldLength} = $self->{_SummaryLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%${fieldLength}d" ];

	my $rowIndex = 0;
	foreach my $warehouse (@{$self->{_Warehouses}}) {
		my @units;
		my $printWarehouse = $warehouse + 1;

		foreach my $instance (@instances) {
			my @instance_rows = @{$self->{_ResultData}[$instance]};
			my @row = @{$instance_rows[$rowIndex]};
			push @units, $row[1];
		}
		my $bops = calc_sum(@units);
		if ($bops > $peak_bops) {
			$peak_warehouse = $warehouse;
			$peak_bops = $bops;
		}

		if ($warehouse == $expected_peak) {
			$expected_bops = $bops;
		}
		$rowIndex++;
	}

	push @{$self->{_SummaryData}}, [ "Expctd Warehouse", $expected_peak + 1 ];
	push @{$self->{_SummaryData}}, [ "Expctd Peak Bops", $expected_bops ];
	push @{$self->{_SummaryData}}, [ "Actual Warehouse", $peak_warehouse + 1 ];
	push @{$self->{_SummaryData}}, [ "Actual Peak Bops",   $peak_bops ];
	push @{$self->{_SummaryData}}, [ "SpecJBB Bops", $specjbb_bops ];
	push @{$self->{_SummaryData}}, [ "SpecJBB Bops/JVM",   $specjbb_bopsjvm ];

	return 1;
}

sub printReport() {
	my ($self, $reportDir) = @_;
	my @jvm_instances = @{$self->{_JVMInstances}};

	$self->_printClientReport($reportDir, @jvm_instances);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $jvm_instance = -1;
	my $reading_tput = 0;
	my @jvm_instances;
	my $specjbb_bops;
	my $specjbb_bopsjvm;
	my $single_instance;
	my $pagesize = "base";

	# Bodge
	$reportDir =~ s/specjbbpeak/specjbb/;

	if (! -e "$reportDir/noprofile/$pagesize") {
		$pagesize = "transhuge";
	}
	if (! -e "$reportDir/noprofile/$pagesize") {
		$pagesize = "default";
	}

	my $file = "$reportDir/noprofile/$pagesize/SPECjbbMultiJVM.001/MultiVMReport.txt";
	if (! -e $file) {
		$single_instance = 1;
		$file = "$reportDir/noprofile/$pagesize/SPECjbbSingleJVM/SPECjbb.001.txt";
	}

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;

		if (!$single_instance && $line =~ /JVM ([0-9]+) Scores/) {
			$jvm_instance = $1;
			push @jvm_instances, $jvm_instance;
			next;
		}
		if ($single_instance && $line =~ /SPEC scores/) {
			$jvm_instance = 1;
			push @jvm_instances, $jvm_instance;
			next;
		}

		if ($jvm_instance != -1 && $line =~ /Warehouses/) {
			$reading_tput = 1;
			next;
		}

		if (!$single_instance && $jvm_instance == -1 && $line =~ /SPECjbb2005 bops=([0-9]+), SPECjbb2005 bops\/JVM=([0-9]+)/) {
			$specjbb_bops = $1;
			$specjbb_bopsjvm = $2;
		}

		if ($single_instance && $line =~ /^Throughput\s+([0-9]+)/) {
			$specjbb_bops = $1;
			$specjbb_bopsjvm = $1;
		}

		if ($reading_tput && $line =~ /^\s+$/) {
			$reading_tput = 0;
			next;
		}

		if ($reading_tput) {
			my ($included, $warehouse, $throughput);
			my @elements = split(/\s+/, $line);
			shift @elements;
			if ($elements[0] eq "*") {
				($included, $warehouse, $throughput) = @elements;
			} else {
				($warehouse, $throughput) = @elements;
				$included = "";
			}
			if ($#jvm_instances == 1 || $single_instance) {
				push @{$self->{_Warehouses}}, $warehouse;
			}
			push @{$self->{_ResultData}[$jvm_instance]}, [ $warehouse, $throughput, $included ];
		}
	}
	$self->{_SpecJBBBops} = $specjbb_bops;
	$self->{_SpecJBBBopsJVM} = $specjbb_bopsjvm;
	$self->{_JVMInstances} = \@jvm_instances;
	close INPUT;


	$file = "$reportDir/noprofile/$pagesize/SPECjbbMultiJVM.001/SPECjbb.raw";
	if ($single_instance) {
		$file = "$reportDir/noprofile/$pagesize/SPECjbbSingleJVM/SPECjbb.001.raw";
	}
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;
		if ($line =~ /^global.input.expected_peak_warehouse/ ||
		    $line =~ /^input.expected_peak_warehouse/) {
			(my $dummy, $self->{_ExpectedPeak}) = split(/=/, $line);
			$self->{_ExpectedPeak}--;
		}
	}
	close INPUT;
}

1;
