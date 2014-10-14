# CompareVmrstream.pm
package MMTests::CompareVmrstream;
use MMTests::Compare;
our @ISA = qw(MMTests::Compare);

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "CompareVmrstream",
		_DataType    => MMTests::Compare::DATA_OPSSEC,
		_FieldLength => 12,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

sub _generateTitleTable() {
	my ($self) = @_;
	my @titleTable;

	my @extractModules = @{$self->{_ExtractModules}};
	my @summaryHeaders = @{$extractModules[0]->{_SummaryHeaders}};
	my $baselineRef = $extractModules[0]->{_SummaryData};
	my @baseline = @{$baselineRef};

	for (my $column = 1; $column <= $#summaryHeaders; $column++) {
		for (my $row = 0; $row <= $#baseline; $row++) {
			my $size = $summaryHeaders[$column] * 1024;
			if ($size > 1024 && $size < 1048576) {
				$size = int($size / 1024) . "K";
			} elsif ($size > 1048576) {
				$size = int($size / 1048576) . "M";
			}
			push @titleTable, [$baseline[$row][0], $size];
		}
	}

	$self->{_TitleTable} = \@titleTable;
}

1;
