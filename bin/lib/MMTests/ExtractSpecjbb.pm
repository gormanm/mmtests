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
		_ModuleName  => "ExtractSpecjbb",
		_DataType    => MMTests::Extract::DATA_THROUGHPUT,
		_ResultData  => [],
		_FieldLength => 12,
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	print "Operations,Bops,Time\n";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength} = 12;
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%${fieldLength}d", "%${fieldLength}d", "%${fieldLength}s" ];
	$self->{_FieldHeaders} = [ "JVMInstance", "Warehouses", "Bops", "Included" ];
	$self->{_SummaryHeaders} = [ "Warehouse", "Min", "Mean", "Stddev", "Max", "TPut" ];
	$self->{_SummaryLength} = $fieldLength;
	$self->{_TestName} = $testName;
}

sub extractSummary() {
	my ($self) = @_;
	my @data = @{$self->{_ResultData}};
	my @instances = @{$self->{_JVMInstances}};
	my @funcList = ("calc_min", "calc_mean", "calc_stddev", "calc_max", "calc_sum");
	if ($self->{_JVMSingle}) {
		@funcList = ("calc_sum");
		$self->{_SummaryHeaders} = [ "Warehouse", "TPut" ];
	}

	# Bodge
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%${fieldLength}d", "%${fieldLength}.2f", "%${fieldLength}.2f", "%${fieldLength}d", "%${fieldLength}d", "%${fieldLength}d" ];

	for (my $warehouse = 0;
	     $warehouse <= $self->{_MaxWarehouse} - $self->{_MinWarehouse};
	     $warehouse++) {
		my @summaryRow;
		push @summaryRow, $warehouse + $self->{_MinWarehouse};

		foreach my $funcName (@funcList) {
			no strict "refs";
			my @units;

			foreach my $instance (@instances) {
				my @instance_rows = @{$self->{_ResultData}[$instance]};
				my @row = @{$instance_rows[$warehouse]};
				push @units, $row[1];
			}
			push @summaryRow, &$funcName(@units);
		}

		push @{$self->{_SummaryData}}, \@summaryRow;
	}

	return 1;
}

sub printPlot() {
	my ($self, $subHeading) = @_;
	my @data = @{$self->{_ResultData}};
	my $fieldLength = $self->{_FieldLength};
	my @instances = @{$self->{_JVMInstances}};

	for (my $warehouse = 0; $warehouse < $self->{_MaxWarehouse}; $warehouse++) {
		my @units;
		foreach my $instance (@instances) {
			my @instance_rows = @{$self->{_ResultData}[$instance]};
			my @row = @{$instance_rows[$warehouse]};
			push @units, $row[1];
		}

		printf("%-${fieldLength}d", $warehouse);
		$self->_printSimplePlotData($fieldLength, @units);
	}
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
	my $min_warehouse = -1;
	my $max_warehouse = 0;
	my @jvm_instances;
	my $single_instance = 0;
	my $pagesize = "base";

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
			if ($min_warehouse == -1) {
				$min_warehouse = $warehouse;
			}
			if ($warehouse > $max_warehouse) {
				$max_warehouse = $warehouse;
			}
			push @{$self->{_ResultData}[$jvm_instance]}, [ $warehouse, $throughput, $included ];
		}
	}
	$self->{_JVMSingle} = $single_instance;
	$self->{_JVMInstances} = \@jvm_instances;
	$self->{_MinWarehouse} = $min_warehouse;
	$self->{_MaxWarehouse} = $max_warehouse;
	close INPUT;
}

1;
