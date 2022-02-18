package MMTests::ExtractLmbenchlat_proc;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractLmbenchlat_proc";
	$self->{_DataType}   = DataTypes::DATA_TIME_USECONDS;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_ExactPlottype} = "simple";
	$self->{_ExactSubheading} = 1;
	$self->SUPER::initialise($subHeading);
}

my %nr_samples;

sub extractReport() {
	my ($self, $reportDir) = @_;
	my @nr_procs;

	@nr_procs = $self->discover_scaling_parameters($reportDir, "lmbench-lat_proc-", ".log");

	foreach my $nr_proc (@nr_procs) {
		my $iteration = 0;
		my $size = -1;

		my $input = $self->SUPER::open_log("$reportDir/lmbench-lat_proc-$nr_proc.log");
		while (<$input>) {
			my $line = $_;

			$line =~ s/\///g;
			next if $line !~ /^Process ([a-z+ -]*): ([0-9.]+)* ([a-z]+)/;
			die if ($3 ne "microseconds");

			my $proc;
			$proc = "fork"   if $1 eq "fork+exit";
			$proc = "execve" if $1 eq "fork+execve";
			$proc = "shell"  if $1 eq "fork+binsh -c";

			$nr_samples{"$proc-$nr_proc"}++;
			$self->addData("$proc-$nr_proc", $nr_samples{"$proc-$nr_proc"}, $2);
		}
		close($input);
	}

	my @operations;
	foreach my $proc ("fork", "execve", "shell") {
		foreach my $nr_proc (@nr_procs) {
			push @operations, "$proc-$nr_proc";
		}
	}
	$self->{_Operations} = \@operations;
}

1;
