# ExtractIpcscalecommon.pm
package MMTests::ExtractIpcscalecommon;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractIpcscale";
	$self->{_PlotYaxis} = DataTypes::LABEL_OPS_PER_SECOND;
	$self->{_PreferredVal} = "Higher";
	$self->{_Opname} = "Latency";
	$self->{_PlotType} = "thread-errorlines";
	$self->{_ClientSubheading} = 1;
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $recent = 0;

	my @files = <$reportDir/semscale.*>;
	my %samples;
	foreach my $file (@files) {
		my $input = $self->SUPER::open_log($file);
		while (<$input>) {
			my $line = $_;
			if ($line =~ /^Threads ([0-9]+), interleave ([0-9]+) threadspercore ([0-9]+) delay ([0-9]+): ([0-9]+) in ([0-9]+) secs/) {
				my $nr_threads = $1;
				my $interleave = $2;
				my $delay = $4;
				my $opSec = $5 / $6;

				if ($delay == 0) {
					my $op = "$nr_threads-i$interleave-d$delay";
					$self->addData($op, ++$samples{$op}, $opSec);
				}
			}
		}
		close $input;
	}
	my @ops = sort { $a cmp $b } keys %samples;
	$self->{_Operations} = \@ops;
}

1;
