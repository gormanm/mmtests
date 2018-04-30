# ExtractSstartup.pm
package MMTests::ExtractSstartup;
use MMTests::SummariseVariabletime;
use MMTests::DataTypes;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseVariabletime);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSstartup",
		_DataType    => DataTypes::DATA_TIME_SECONDS,
		_ResultData  => [],
		_PlotType    => "simple-filter-points",
		_PlotXaxis   => "Sample #"
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	my @jobnames;
	foreach my $file (<$reportDir/noprofile/results/replayed_*_startup>) {
		$file =~ s/.*replayed_//;
		$file =~ s/_startup$//;
		$file =~ s/_startup.txt$//;
		push @jobnames, $file;
	}
	@jobnames = sort { $a <=> $b } @jobnames;

	my %jobnamesPatterns;
	foreach my $jobname (@jobnames) {
		my $reading = 0;

		my @schedulers;
		foreach my $file (<$reportDir/noprofile/results/replayed_$jobname\_startup/repetition0/*-0r0w-seq-single_times.txt>) {
			$file =~ s/.*\/repetition0\///;
			$file =~ s/-0r0w-seq-single_times.txt$//;
			push @schedulers, $file;
		}
		@schedulers = sort { $a <=> $b } @schedulers;

		# Scheduler info is extracted but not used. If its
		# planned in the future that one benchmark run
		# switches between I/O schedulers this extraction
		# needs to be adapted.
		foreach my $scheduler (@schedulers) {
			my @patterns;
			foreach my $file (<$reportDir/noprofile/results/replayed_$jobname\_startup/repetition0/$scheduler-*-single_times.txt>) {
				$file =~ s/.*$scheduler-//;
				$file =~ s/-single_times.txt//;
				push @patterns, $file;
			}
			@patterns = sort { $a <=> $b } @patterns;

			# Now extract data from
			# $scheduler-$pattern-single_times.txt (not
			# using $scheduler-$pattern-lat_thr_stat.txt
			# at the moment).
			foreach my $pattern (@patterns) {
				open INPUT,
				"$reportDir/noprofile/results/replayed_$jobname\_startup/repetition0/$scheduler-$pattern-single_times.txt"
				|| die "Failed to find time data file
				for $jobname\n";

				my $nr_samples=0;
				my $jobnamePattern="$jobname-$pattern";
				while (!eof(INPUT)) {
					my $line = <INPUT>;
					chomp($line);
					$line =~ s/^\s+//;
					$jobnamesPatterns{$jobnamePattern} = 1;
					$nr_samples++;
					push @{$self->{_ResultData}}, [ "$jobnamePattern", $nr_samples, $line];
				}
				close INPUT;
			}
		}
	}

	my @ops;
	foreach my $jobnamePattern (sort {$a <=> $b} (keys %jobnamesPatterns)) {
		push @ops, "$jobnamePattern";
	}
	$self->{_Operations} = \@ops;
}
1;
