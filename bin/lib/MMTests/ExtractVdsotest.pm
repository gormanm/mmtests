# ExtractVdsotest.pm
package MMTests::ExtractVdsotest;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;
use Data::Dumper qw(Dumper);

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_ModuleName} = "ExtractVdsotest";
	$self->{_PlotYaxis}  = DataTypes::LABEL_TIME_NSECONDS;
	$self->{_Opname} = "Latency";
	$self->{_PlotType}   = "histogram";
	$self->{_DefaultPlot} = "1";
	$self->{_ClientSubheading} = 1;
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($tp, $name);
	close(INPUT);
	my @ops;

	my @files = <$reportDir/benchlog-*-_-*>;
	my %samples;

	foreach my $file (@files) {
		my $bare = $file;
		$bare =~ s/.*\///;
		my ($dummy, $wl, $dummy) = split(/-/, $bare);

		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;

			if ($line =~ /.*system calls per second:\W+([0-9]+).*/) {
				my $op = "$wl-syscall";
				my $lat = ($1/1000000000) ** -1;

				$self->addData($op, ++$samples{$op}, $lat);
			}

			elsif ($line =~ /.*vdso calls per second:\W+([0-9]+).*/) {
				my $op = "$wl-vdso";
				my $lat = ($1/1000000000) ** -1;

				$self->addData($op, ++$samples{$op}, $lat);
			}

			elsif ($line =~ /(\w+):\W+([0-9]+)\s+nsec\/call/) {
				my $op = "$wl-$1";
				my $lat = $2;

				$self->addData($op, ++$samples{$op}, $lat);
			}
		}
		close INPUT;
	}

}
