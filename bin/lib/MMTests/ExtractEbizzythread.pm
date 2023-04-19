# ExtractEbizzythread.pm
package MMTests::ExtractEbizzythread;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractEbizzythread",
		_DataType    => DataTypes::DATA_ACTIONS_PER_SECOND,
	};
	bless $self, $class;
	return $self;
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	foreach my $instance ($self->discover_scaling_parameters($reportDir, "ebizzy-", "-1.log")) {
		my $sample = 0;

		my @files = <$reportDir/ebizzy-$instance-*>;
		foreach my $file (@files) {
			my $input = $self->SUPER::open_log($file);
			while (<$input>) {
				my $line = $_;
				if ($line =~ /([0-9]*) records.*/) {
					my @elements = split(/\s+/, $line);
					for (my $i = 2; $i <= $#elements; $i++) {
						$self->addData("Rsec-$instance", $sample, $elements[$i]);
						$sample++;
					}
				}
			}
			close $input;
		}
	}
}

1;
