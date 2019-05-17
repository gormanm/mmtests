# ExtractFsmarkoverhead.pm
package MMTests::ExtractFsmarkoverhead;
use MMTests::SummariseMultiops;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractFsmarkoverhead";
	$self->{_DataType}   = DataTypes::DATA_TIME_USECONDS;

	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($user, $system, $elapsed, $cpu);
	$reportDir =~ s/overhead//;
	my $iteration = 1;

	$reportDir =~ s/fsmark-singleoverhead/fsmark-single/;
	$reportDir =~ s/fsmark-threadedoverhead/fsmark-threaded/;

	my @clients;
	my @files = <$reportDir/fsmark-*.log>;
	foreach my $file (@files) {
		if ($file =~ /-cmd-/) {
			next;
		}
		$file =~ s/.log$//;
		my @split = split /-/, $file;
		push @clients, $split[-1];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $preamble = 1;
		my $file = "$reportDir/fsmark-$client.log";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			if ($preamble) {
				if ($line !~ /^FSUse/) {
					next;
				}
				$preamble = 0;
				next;
			}

			my @elements = split(/\s+/, $_);
			$self->addData("overhead-$client", ++$iteration, $elements[5]);
		}
		close INPUT;
	}
}

1;
