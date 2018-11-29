# ExtractTiobenchlatency.pm
package MMTests::ExtractTiobenchlatency;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractTiobench",
		_DataType    => DataTypes::DATA_TIME_MSECONDS,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my $max_read = -1;
	$reportDir =~ s/tiobenchlatency-/tiobench-/;

	my @clients;
	my @files = <$reportDir/$profile/tiobench-*-1.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $reading = 0;
		my @files = <$reportDir/$profile/tiobench-$client-*.log>;
		foreach my $file (@files) {
			my $op;
			my @split = split /-/, $file;
			$split[-1] =~ s/.log//;
			my $iteration = $split[-1];
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;

				if ($reading) {
					my @elements = split(/\s+/, $_);
					if ($elements[6] =~ /#/) {
						$elements[6] = -1;
					}
					push @{$self->{_ResultData}}, [ "$op-avglat-$client", $iteration, $elements[6] ];
					push @{$self->{_ResultData}}, [ "$op-maxlat-$client", $iteration, $elements[7] ];
					$reading = 0;
					next;
				}

				chomp($line);
				if ($line eq "Sequential Reads") {
					$reading = 1;
					$op = "SeqRead";
					next;
				}
				if ($line eq "Random Reads") {
					$reading = 1;
					$op = "RandRead";
					next;
				}
				if ($line eq "Sequential Writes") {
					$reading = 1;
					$op = "SeqWrite";
					next;
				}
				if ($line eq "Random Writes") {
					$reading = 1;
					$op = "RandWrite";
					next;
				}
			}
			close INPUT;
		}
	}

	my @ops;
	foreach my $heading ("avglat", "maxlat") {
		foreach my $op ("SeqRead-$heading", "RandRead-$heading", "SeqWrite-$heading", "RandWrite-$heading") {
			foreach my $client (@clients) {
				push @ops, "$op-$client";
			}
		}
	}
	$self->{_Operations} = \@ops;
}

1;
