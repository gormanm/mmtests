# ExtractEbizzyrange.pm
package MMTests::ExtractEbizzyrange;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops); 
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractEbizzyrange",
		_DataType    => MMTests::Extract::DATA_RECORDS_PER_SECOND,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	$reportDir =~ s/ebizzyrange/ebizzy/;
	my @clients;
	my @files = <$reportDir/noprofile/ebizzy-*-1.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-2] =~ s/.log//;
		push @clients, $split[-2];
	}
	@clients = sort { $a <=> $b } @clients;

	foreach my $client (@clients) {
		my $sample = 0;

		my @files = <$reportDir/noprofile/ebizzy-$client-*>;
		foreach my $file (@files) {
			open(INPUT, $file) || die("Failed to open $file\n");
			while (<INPUT>) {
				my $line = $_;
				if ($line =~ /([0-9]*) records.*/) {
					my @elements = split(/\s+/, $line);
					shift @elements;
					shift @elements;
					push @{$self->{_ResultData}}, [ "spread-$client", $sample, calc_range(@elements) ];
					$sample++;
				}
			}
			close INPUT;
		}
	}

	my @ops;
	foreach my $client (@clients) {
		push @ops, "spread-$client";
	}
	$self->{_Operations} = \@ops;
}

1;
