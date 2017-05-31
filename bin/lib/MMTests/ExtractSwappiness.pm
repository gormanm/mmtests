# ExtractSwappiness.pm
package MMTests::ExtractSwappiness;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	$self->{_ModuleName} = "ExtractSwappiness";
	$self->{_DataType}   = DataTypes::DATA_ACTIONS;
	$self->{_PlotType}   = "operation-candlesticks";

	$self->SUPER::initialise($reportDir, $testName);
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;

	my @swappiness;
	my @files = <$reportDir/$profile/vmstat-*>;
        foreach my $file (@files) {
                my @split = split /-/, $file;
                $split[-1] =~ s/.log//;
                push @swappiness, $split[-1];
        }
        @swappiness = sort { $a <=> $b } @swappiness;

	foreach my $swappy (@swappiness) {
		my $file = "$reportDir/$profile/vmstat-$swappy";
		open(INPUT, $file) || die("Failed to open $file\n");
		my $samples = 0;
		my $first = 1;
		while (!eof(INPUT)) {
			my $line = <INPUT>;
			next if $line =~ /[a-zA-Z]/;
			if ($first) {
				$first = 0;
				next;
			}

			$line =~ s/^\s+//;
			
			my @elements = split(/\s+/, $line);
			push @{$self->{_ResultData}}, [ "si-$swappy", $samples, $elements[6] ];
			push @{$self->{_ResultData}}, [ "so-$swappy", $samples, $elements[7] ];
			push @{$self->{_ResultData}}, [ "st-$swappy", $samples, $elements[6] + $elements[7]];
		}
		close(INPUT);
	}

	my @ops;
	foreach my $op ("si", "so", "st") {
		foreach my $swappy (@swappiness) {
			push @ops, "$op-$swappy";
		}
	}

	$self->{_Operations} = \@ops;
}

1;
