# ExtractSpecjvm.pm
package MMTests::ExtractSpecjvm;
use MMTests::SummariseSingleops;
our @ISA = qw(MMTests::SummariseSingleops); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSpecjvm",
		_DataType    => MMTests::Extract::DATA_ACTIONS_PER_SECOND,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
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

	my $file = "$reportDir/noprofile/$pagesize/SPECjvm2008.001/SPECjvm2008.001.txt";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;

		if ($line =~ /======================/) {
			$section++;
			next;
		}

		if ($section == 3 && $line !~ /result:/) {
			my ($bench, $ops) = split(/\s+/, $line);
			if ($bench !~ /startup/) {
				push @{$self->{_ResultData}}, [ $bench, $ops ];
			}
		}

		if ($section == 4 && $line =~ /iteration [0-9]+/) {
			my ($bench, $dA, $dB, $dC, $dD, $dE, $ops) = split(/\s+/, $line);
			if ($bench !~ /startup/) {
				push @{$self->{_ResultData}}, [ $bench, $ops ];
			}
		}
	}
	close INPUT;
}

1;
