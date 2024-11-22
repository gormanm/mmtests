# ExtractCputime.pm
package MMTests::ExtractCputime;
use MMTests::SummariseMultiops;
use MMTests::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $subHeading) = @_;

	$self->{_PlotYaxis} = DataTypes::LABEL_TIME_SECONDS;
	$self->SUPER::initialise($subHeading);

	my $fieldLength = $self->{_FieldLength} = 12;
	$self->{_PlotLength} = $fieldLength;
	$self->{_PlotType} = "operation-candlesticks";
	$self->{_PlotXaxis}  = "TestName";
	$self->{_RatioOperations} = [ "Elapsed" ];
}

sub extractReport() {
	my ($self, $reportDir) = @_;
	my ($user, $system, $elapsed, $cpu);
	my $file = "$reportDir/time";
	my $cnt = 0;

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my $line = $_;
		next if $line !~ /elapsed/;

		$line =~ tr/[a-zA-Z]%//d;
		($user, $system, $elapsed, $cpu) = split(/\s/, $line);
		my @elements = split(/:/, $elapsed);
		my ($hours, $minutes, $seconds);
		if ($#elements == 1) {
			$hours = 0;
			($minutes, $seconds) = @elements;
		} else {
			($hours, $minutes, $seconds) = @elements;
		}
		$elapsed = $hours * 60 * 60 + $minutes * 60 + $seconds;

		$self->addData("User", $cnt, $user);
		$self->addData("System", $cnt, $system);
		$self->addData("Elapsed", $cnt, $elapsed);
		$self->addData("CPU", $cnt, $cpu);
		$cnt++;
	}
	close INPUT;
}

1;
