# ExtractSpecjbb.pm
package MMTests::ExtractSpecjbb;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract); 
use strict;

use constant DATA_SPECJBB     => 800;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSpecjbb",
		_DataType    => DATA_SPECJBB,
		_ResultData  => [],
		_FieldLength => 12,
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	print "Bops\n";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%${fieldLength}d", "%${fieldLength}d", "%${fieldLength}s" ];
	$self->{_FieldHeaders} = [ "JVMInstance", "Warehouses", "Bops", "Included" ];
	$self->{_SummaryHeaders} = [ "Metric", "Bops" ];
	$self->{_SummaryLength} = 15;
	$self->{_TestName} = $testName;
}

sub extractSummary() {
	my ($self) = @_;
	my @data = @{$self->{_ResultData}};
	my @instances = @{$self->{_JVMInstances}};

	# Bodge
	my $fieldLength = $self->{_FieldLength} = 15;
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%${fieldLength}.2f" ];

	foreach my $funcName ("calc_min", "calc_mean", "calc_stddev", "calc_max", "calc_sum") {
		my $printFuncName = $funcName;
		$printFuncName =~ s/calc_//;
		if ($printFuncName eq "sum") {
			$printFuncName = "tput";
		}
		for (my $warehouse = 0; $warehouse < $self->{_MaxWarehouse}; $warehouse++) {
			no strict "refs";
			my @units;
			my $printWarehouse = $warehouse + 1;

			foreach my $instance (@instances) {
				my @instance_rows = @{$self->{_ResultData}[$instance]};
				my @row = @{$instance_rows[$warehouse]};
				push @units, $row[1];
			}
			push @{$self->{_SummaryData}}, [ "Warehouse $printWarehouse $printFuncName", &$funcName(@units) ];
		}

		
	}

	return 1;
}
#
#sub printSummary() {
#	my ($self) = @_;
#
#	$self->printReport();
#}

sub printReport() {
	my ($self, $reportDir) = @_;
	my @jvm_instances = @{$self->{_JVMInstances}};

	$self->_printClientReport($reportDir, @jvm_instances);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $jvm_instance = -1;
	my $reading_tput = 0;
	my $max_warehouse = 0;
	my @jvm_instances;

	my $file = "$reportDir/noprofile/base/SPECjbbMultiJVM.001/MultiVMReport.txt";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;

		if ($line =~ /JVM ([0-9]+) Scores/) {
			$jvm_instance = $1;
			push @jvm_instances, $jvm_instance;
			next;
		}

		if ($jvm_instance != -1 && $line =~ /Warehouses/) {
			$reading_tput = 1;
			next;
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
			if ($warehouse > $max_warehouse) {
				$max_warehouse = $warehouse;
			}
			push @{$self->{_ResultData}[$jvm_instance]}, [ $warehouse, $throughput, $included ];
		}
	}
	$self->{_JVMInstances} = \@jvm_instances;
	$self->{_MaxWarehouse} = $max_warehouse;
	close INPUT;


	$file = "$reportDir/noprofile/base/SPECjbbMultiJVM.001/SPECjbb.raw";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;
		if ($line =~ /^global.input.expected_peak_warehouse/) {
			(my $dummy, $self->{_ExpectedPeak}) = split(/=/, $line);
		}
	}
	close INPUT;
}

1;
