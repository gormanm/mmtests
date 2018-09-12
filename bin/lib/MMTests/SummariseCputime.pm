# SummariseCputime.pm
package MMTests::SummariseCputime;
use MMTests::SummariseMultiops;
use VMR::Stat;
our @ISA = qw(MMTests::SummariseMultiops);
use strict;

sub initialise() {
	my ($self, $reportDir, $testName) = @_;

	$self->{_DataType} = DataTypes::DATA_TIME_SECONDS;
	$self->SUPER::initialise($reportDir, $testName);

	my $fieldLength = $self->{_FieldLength} = 12;
	$self->{_SummaryLength} = $fieldLength;
	$self->{_PlotLength} = $fieldLength;
	$self->{_PlotType} = "operation-candlesticks";
	$self->{_PlotXaxis}  = "TestName";
	$self->{_PlotHeaders} = [ "LowStddev", "Min", "Max", "HighStddev", "Mean" ];
	$self->{_MultiInclude} = { "Elapsed" => 1 };
}

sub extractReport() {
	my ($self, $reportDir, $reportName, $profile) = @_;
	my ($user, $system, $elapsed, $cpu);
	my $file = "$reportDir/$profile/time";
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

		push @{$self->{_ResultData}}, [ "User",    $cnt, $user    ];
		push @{$self->{_ResultData}}, [ "System",  $cnt, $system  ];
		push @{$self->{_ResultData}}, [ "Elapsed", $cnt, $elapsed ];
		push @{$self->{_ResultData}}, [ "CPU",     $cnt, $cpu     ];
		$cnt++;
	}
	close INPUT;

	$self->{_Operations} = [ "User", "System", "Elapsed", "CPU" ];
}

1;
