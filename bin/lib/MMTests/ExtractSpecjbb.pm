# ExtractSpecjbb.pm
package MMTests::ExtractSpecjbb;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->{_ModuleName} = "ExtractSpecjbb";
	$self->{_DataType}   = MMTests::Extract::DATA_OPS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_PlotXaxis}  = "Clients";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my %warehouses;
	my $jvm_instance = -1;
	my $reading_tput = 0;
	my @jvm_instances;
	my $single_instance = 0;
	my $pagesize = "base";

	if (! -e "$reportDir/noprofile/$pagesize") {
		$pagesize = "transhuge";
	}
	if (! -e "$reportDir/noprofile/$pagesize") {
		$pagesize = "default";
	}

	my $file;
	if (-e "$reportDir/noprofile/$pagesize/SPECjbbMultiJVM.001") {
		$file = "$reportDir/noprofile/$pagesize/SPECjbbMultiJVM.001/MultiVMReport.txt";
		if (! -e $file) {
			my $instances = 0;

			$file = "$reportDir/noprofile/$pagesize/SPECjbbMultiJVM.001/MultiVMMmtests.txt";
			open(OUTPUT, ">$file") || die("Failed to open $file\n");

			foreach my $report (<$reportDir/noprofile/$pagesize/SPECjbbMultiJVM.001/SPECjbb.*.txt>) {
				my ($included, $warehouse, $throughput);
				my $line = "";

				$instances++;
				print OUTPUT "\n";
				print OUTPUT "JVM $instances Scores\n";
				print OUTPUT "Warehouses Thrput\n";

				open(INPUT, $report) || die("Failed to open $file");
				while (!eof(INPUT) && $line !~ /SPEC scores/) {
					$line = <INPUT>;
				}
				$line = <INPUT>;
				$line = <INPUT>;
				while (!eof(INPUT)) {
					my @elements = split(/\s+/, $line);
					shift @elements;
					if ($elements[0] eq "*") {
						($included, $warehouse, $throughput) = @elements;
					} else {
						($warehouse, $throughput) = @elements;
						$included = "";
					}
					last if $warehouse eq "";
					print OUTPUT " $warehouse $throughput\n";
					$line = <INPUT>;
				}
				close(INPUT);
			}
			close OUTPUT;
		}
	} else {
		$self->{_SuppressDmean} = 1;
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

		my $nr_samples = 0;
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
			$warehouses{$warehouse}++;
			push @{$self->{_ResultData}}, [ "tput-$warehouse", $warehouses{$warehouse}, $throughput ];
		}
	}

	my @ops;
	foreach my $warehouse (sort {$a <=> $b} (keys %warehouses)) {
		push @ops, "tput-$warehouse";
	}
	$self->{_Operations} = \@ops;
	close INPUT;
}

1;
