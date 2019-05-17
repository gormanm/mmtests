# ExtractVmrstream.pm
package MMTests::ExtractVmrstream;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_DataType} = DataTypes::DATA_MBYTES_PER_SECOND;
	$self->{_PlotXaxis}   = "MemSize";
	$self->{_PlotType} = "client-errorlines";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @pagesize_types;
	my %wss_sizes;

	# Get a list of backing buffer types: malloc, static etc.
	my @files = <$reportDir/default/stream-*>;
	foreach my $file (@files) {
		my @split = split /\//, $file;
		push @pagesize_types, $split[-1];
	}

	# Lazy, the test can handle this but the extract script doesn't
	if ($#pagesize_types > 1) {
		die("Extract script cannot handle multiple buffer types");
	}

	# Get the list of buffer sizes used during the test
	open(INPUT, "$reportDir/default/$pagesize_types[0]/stream-Add.instances") || die("Failed to open file for wss_sizes");
	while (<INPUT>) {
		my @elements = split(/\s+/, $_);
		$wss_sizes{$elements[0]} = 1;
	}
	close INPUT;

	my %samples;
	my @ops;
	foreach my $pagesize_type (@pagesize_types) {
		foreach my $operation ("Add", "Copy", "Scale", "Triad") {
			my $file = "$reportDir/default/$pagesize_type/stream-$operation.instances";
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my @elements = split(/\s+/, $_);
				my $size = int ($elements[0] / 1024);
				my $op = "$operation-${size}K";
				$self->addData($op, ++$samples{$op}, $elements[1]);
				if ($samples{$op} == 1) {
					push @ops, $op;
				}
			}
			close INPUT;
		}
	}
	$self->{_Operations} = \@ops;
}

1;
