# ExtractDbench4.pm
package MMTests::ExtractDbench4opslatency;
use MMTests::SummariseSingleops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseSingleops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractDbench4opslatency",
		_DataType    => DataTypes::DATA_TIME_MSECONDS,
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_Opname} = "latency";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($tm, $tput, $latency);
	my $readingOperations = 0;
	my %dbench_ops = ("NTCreateX"	=> 1, "Close"	=> 1, "Rename"	=> 1,
			  "Unlink"	=> 1, "Deltree"	=> 1, "Mkdir"	=> 1,
			  "Qpathinfo"	=> 1, "WriteX"	=> 1, "ReadX"	=> 1,
			  "Qfileinfo"	=> 1, "Qfsinfo"	=> 1, "Flush"	=> 1,
			  "Sfileinfo"	=> 1, "LockX"	=> 1, "UnlockX"	=> 1,
			  "Find"	=> 1);
	my @clients = $self->discover_scaling_parameters($reportDir, "dbench-", ".log.gz");

	my $index = 1;
	foreach my $header ("count", "avg", "max") {
		$index++;
		foreach my $client (@clients) {
			my $file = "$reportDir/dbench-$client.log.gz";

			my $input = $self->SUPER::open_log("$reportDir/dbench-$client.log");
			while (<$input>) {
				my $line = $_;
				if ($line =~ /Operation/) {
					$readingOperations = 1;
				}

				if ($readingOperations != 1) {
					next;
				}

				my @elements = split(/\s+/, $line);
				if ($dbench_ops{$elements[1]} == 1) {
					$self->addData("$header-$elements[1]-$client", 0, $elements[$index]);
				}
			}
			close($input);
		}
	}

}

1;
