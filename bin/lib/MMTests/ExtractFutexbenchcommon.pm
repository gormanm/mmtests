# ExtractFutexbench.pm
package MMTests::ExtractFutexbenchcommon;
use MMTests::Extract;
use VMR::Stat;
our @ISA = qw(MMTests::Extract);
use strict;
use Data::Dumper qw(Dumper);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractFutexbenchcommon",
		_DataType    => MMTests::Extract::DATA_THROUGHPUT,
		_ResultData  => [],
		_FieldLength => 16,
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->SUPER::initialise();

	my $fieldLength = $self->{_FieldLength} = 12;
	$self->{_FieldLength} = $fieldLength;
	$self->{_SummaryLength} = $fieldLength;
	$self->{_TestName} = $testName;
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%$fieldLength.2f" , "%${fieldLength}.3f%%" ];
	$self->{_FieldHeaders} = [ "Threads", "Tput", ];
	$self->{_SummaryHeaders} =[ "Unit", "Tput" ];
}

sub printPlot() {
	my ($self, $subheading) = @_;
	$self->printSummary();
}

sub extractSummary() {
	my ($self) = @_;

	$self->{_SummaryData} = $self->{_ResultData};
	return 1;
}

sub uniq {
	my %seen;
	grep !$seen{$_}++, @_;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($tp, $name);
	my $file_wk = "$reportDir/noprofile/workloads";
	open(INPUT, "$file_wk") || die("Failed to open $file_wk\n");
	my @workloads = split(/ /, <INPUT>);
	$self->{_Workloads} = \@workloads;
	close(INPUT);

	my @threads;
	foreach my $wl (@workloads) {
		chomp($wl);
		my @files = <$reportDir/noprofile/$wl-*.log>;
		foreach my $file (@files) {
			my @elements = split (/-/, $file);
			my $thr = $elements[-1];
			$thr =~ s/.log//;
			push @threads, $thr;
		}
	}
	@threads = sort {$a <=> $b} @threads;
	@threads = uniq(@threads);

	foreach my $nthr (@threads) {
		foreach my $wl (@workloads) {
			my $file = "$reportDir/noprofile/$wl-$nthr.log";

			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				my @tmp = split(/\s+/, $line);

				if ($line =~ /Averaged/) {
					$tp = $tmp[1];
					last;
				}

				if ($line =~ /Wokeup/) {
					if ($line =~ /%/) {
						$tp = $tmp[6];
						last;
					}
				}

				if ($line =~ /Requeued/) {
					if ($line =~ /%/) {
						$tp = $tmp[6];
						last;
					}
				}
			}

			close INPUT;
			push @{$self->{_ResultData}}, [ "$wl ($nthr threads)", $tp ];
		}
	}
}

sub printSummary() {
	my ($self, $subHeading) = @_;
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%$fieldLength.2f" ];
	$self->SUPER::printSummary($subHeading);
}
