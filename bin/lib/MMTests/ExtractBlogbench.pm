# ExtractBlogbench.pm
package MMTests::ExtractBlogbench;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractBlogbench";
	$self->{_PlotYaxis}  = "Score";
	$self->{_PlotType}   = "operation-candlesticks";
	$self->{_PreferredVal} = "Higher";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my $recent = 0;

	my @files = <$reportDir/blogbench-*.log*>;
	my $iteration = 1;
	foreach my $file (@files) {
		my $input = $self->SUPER::open_log($file);
		while (<$input>) {
			my $line = $_;
			next if $line !~ /^Final score/;
			my @elements = split(/\s+/, $line);

			$self->addData("ReadScore", $iteration, $elements[-1]) if $line =~ /reads/;
			$self->addData("WriteScore", $iteration, $elements[-1]) if $line =~ /writes/;

		}
		close $input;
	}
}

1;
