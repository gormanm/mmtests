package MMTests::ExtractDbench4tput;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} 		= "ExtractDbench4tput";
	$self->{_DataType}   		= DataTypes::DATA_MBYTES_PER_SECOND;
	$self->{_PlotType}   		= "client-errorlines";
	$self->{_SubheadingPlotType}	= "simple-clients";
        $self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	$reportDir =~ s/4tput/4/;
	my @clients;

	my @files = <$reportDir/dbench-*.log*>;
	if ($files[0] eq "") {
		@files = <$reportDir/tbench-*.log*>;
	}
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log.*//;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $file = "$reportDir/dbench-$client.log";
		if (! -e $file) {
			$file = "$reportDir/dbench-$client.log.gz";
		}
		if (! -e $file) {
			$file = "$reportDir/tbench-$client.log";
		}
		if (! -e $file) {
			$file = "$reportDir/tbench-$client.log.gz";
		}
		if ($file =~ /.*\.gz$/) {
			open(INPUT, "gunzip -c $file|") || die("Failed to open $file\n");
		} else {
			open(INPUT, $file) || die("Failed to open $file\n");
		}

		while (<INPUT>) {
			my $line = $_;
			$line =~ s/^\s+//;
			if ($line =~ /sec  execute/) {
				my @elements = split(/\s+/, $line);

				$self->addData("$client", $elements[5], $elements[2]);

				next;
			}
		}
		close INPUT;
	}
}

1;
