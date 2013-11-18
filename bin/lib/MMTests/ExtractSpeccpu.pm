# ExtractSpeccpu.pm
package MMTests::ExtractSpeccpu;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSpeccpu",
		_DataType    => MMTests::Extract::DATA_OPSSEC,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	$self->{_FieldLength} = 27;
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}s", "%$fieldLength.2f" ];
	$self->{_FieldHeaders}[0] = "Benchmark";
	$self->{_FieldHeaders}[1] = "RunTime";
	$self->{_PlotHeaders}[0] = "Benchmark";
	$self->{_SummaryHeaders} = $self->{_FieldHeaders};
	$self->{_TestName} = $testName;
}

sub extractSummary() {
	my ($self) = @_;
	$self->{_SummaryData} = $self->{_ResultData};
	return 1;
}

sub printSummary() {
	my ($self) = @_;

	$self->printReport();
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $section = 0;
	my $pagesize = "base";

	if (! -e "$reportDir/noprofile/$pagesize") {
		$pagesize = "transhuge";
	}
	if (! -e "$reportDir/noprofile/$pagesize") {
		$pagesize = "default";
	}

	my $size = "test";
	print "DEBUG: $reportDir/noprofile/$pagesize/CINT2006.001.test.txt\n";
	if (! -e "$reportDir/noprofile/$pagesize/CINT2006.001.test.txt") {
		$size = "ref";
	}

	foreach my $file ("$reportDir/noprofile/$pagesize/CINT2006.001.$size.txt", "$reportDir/noprofile/$pagesize/CFP2006.001.$size.txt") {
		open(INPUT, $file) || die("Failed to open $file\n");
		my $reading = 0;

		while (<INPUT>) {
			my $line = $_;

			if ($line =~ /======================/) {
				$reading = 1;
				next;
			}
			if ($line =~ /Est. SPEC/) {
				$reading = 0;
			}

			if (!$reading) {
				next;
			}
			my @elements = split(/\s+/, $line);
			my $bench = $elements[0];
			my $ops = $elements[2];

			if ($file =~ /CINT/) {
				$bench .= ".int";
			} else {
				$bench .= ".fp";
			}

			if ($ops ne "") {
				push @{$self->{_ResultData}}, [ $bench, $ops ];
			}
		}
	}
	close INPUT;
}

1;
