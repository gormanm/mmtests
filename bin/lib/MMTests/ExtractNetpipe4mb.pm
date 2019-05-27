# ExtractNetpipe4mb
package MMTests::ExtractNetpipe4mb;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractNetpipe4mb";
	$self->{_DataType}   = DataTypes::DATA_MBITS_PER_SECOND;
	$self->{_PlotType}   = "client-errorlines";
	$self->{_Operations} = [ "tput-1-2mb", "tput-2-3mb", "tput-3-4mb", "tput-g-4mb" ];
        $self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $nr_samples = 0;

	my $file = "$reportDir/netpipe.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;
		$line =~ s/^\s+//;
		my @elements = split(/\s+/, $line);

		if ($elements[0] > 1000000 && $elements[0] <= 2000000) {
			$self->addData("tput-1-2mb", ++$nr_samples, $elements[1]);
		}
		if ($elements[0] > 2000000 && $elements[0] <= 3000000) {
			$self->addData("tput-2-3mb", ++$nr_samples, $elements[1]);
		}
		if ($elements[0] > 3000000 && $elements[0] <= 4000000) {
			$self->addData("tput-3-4mb", ++$nr_samples, $elements[1]);
		}
		if ($elements[0] > 4000000) {
			$self->addData("tput-g-4mb", ++$nr_samples, $elements[1]);
		}
	}
	close INPUT;
}

1;
