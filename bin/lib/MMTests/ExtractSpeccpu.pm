# ExtractSpeccpu.pm
package MMTests::ExtractSpeccpu;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSpeccpu",
		_DataType    => MMTests::Extract::DATA_TIME_SECONDS,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_Opname} = "Time";
	$self->SUPER::initialise($reportDir, $testName);
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
