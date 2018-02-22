# ExtractSstartup.pm
package MMTests::ExtractSstartup;
use MMTests::SummariseSingleops;
use MMTests::DataTypes;
use VMR::Report;
our @ISA = qw(MMTests::SummariseSingleops);

use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSstartup",
		_DataType    => DataTypes::DATA_TIME_SECONDS,
		_PlotType    => "histogram",
		_ResultData  => [],
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	my @jobnames;
	foreach my $file (<$reportDir/noprofile/results/overall_stats-*_startup.txt>) {
		$file =~ s/.*overall_stats-replayed_//;
		$file =~ s/_startup.txt$//;
		push @jobnames, $file;
	}
	@jobnames = sort { $a <=> $b } @jobnames;

##	Example of extracting repetitions but unused at this time
##	---------------------------------------------------------
##	Note that an unfortunate limitation is that we do not have a breakdown
##	of times for each repetition so only the aggregate can be reported
##	which will give no hint of variability
##
##	my @repetitions;
##	foreach my $dir (<$reportDir/noprofile/results/$jobnames[0]_startup/repetition*>) {
##		$dir =~ s/.*repetition([0-9]*)$/\1/;
##		push @repetitions, $dir;
##	}
##	@repetitions = sort { $a > $b} @repetitions;
##
##	Example of extracting the scheduler and stat files but unused for time
##	----------------------------------------------------------------------
##	my $scheduler;
##	my @patterns;
##	foreach my $file (<$reportDir/noprofile/results/$jobnames[0]_startup/repetition$repetitions[0]/*.txt>) {
##		$file =~ s/_stat\.txt//;
##		$file =~ s/.*\///;
##		my @elements = split /-/, $file;
##		if ($elements[0] eq "mq") {
##			$file =~ s/^mq-deadline-//;
##			$scheduler = "mq-deadline";
##		} else {
##			$file =~ s/^[a-z]+-//;
##			$scheduler = $elements[0];
##		}
##		push @patterns, $file;
##	}
##	@patterns = sort { $a <=> b} @patterns;

	my %patterns;

	foreach my $jobname (@jobnames) {
		my $reading = 0;
		open INPUT, "$reportDir/noprofile/results/replayed_$jobname\_startup/replayed_$jobname\_startup-time-table.txt" || die "Failed to find time table file for $jobname\n";
		while (!eof(INPUT)) {
			my $line = <INPUT>;
			chomp($line);
			$line =~ s/^\s+//;
			if ($line =~ /^# Workload/) {
				$reading = 1;
				next;
			}
			next if !$reading;
			my @elements = split /\s+/, $line;
			$patterns{$elements[0]} = 1;
			push @{$self->{_ResultData}}, [ "$jobname-$elements[0]", $elements[1]];
		}
		close INPUT;
	}

	my @ops;
	foreach my $jobname (@jobnames) {
		foreach my $pattern (sort {$a <=> $b} (keys %patterns)) {
			push @ops, "$jobname-$pattern";
		}
	}
	$self->{_Operations} = \@ops;
}
1;
