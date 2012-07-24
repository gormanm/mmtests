# Print.pm
package MMTests::Print;

sub new() {
	my $class = shift;
	my $self = {};
	bless $self, $class;
}

sub printHeaders($$$) {
	my $self = shift;
	my $fieldLength = shift;
	my @fieldHeaders = @{ $_[0] };
	my @formatList = @{ $_[1] };
	my $header;

	my $headerIndex = 0;
	foreach $header (@fieldHeaders) {
		if (defined $formatList[$headerIndex]) {
			printf($formatList[$headerIndex], $header);
		} else {
			printf("%${fieldLength}s", $header);
		}
		$headerIndex++;
	}
	print "\n";
}

sub printGenericRow($$@) {
	my ($self, $dataRef, $fieldLength, $formatColumnRef, $formatRowRef) = @_;
	my (@formatColumnList, @formatRowList);
	my $rowIndex = 1;
	@formatColumnList = @{$formatColumnRef};
	@formatRowList = @{$formatRowRef};

	foreach my $row (@{$dataRef}) {
		my $columnIndex = 0;

		foreach my $column (@$row) {
			if (defined $formatColumnList[$columnIndex]) {
				my $format = $formatColumnList[$columnIndex];
				if ($format eq "ROW") {
					$format = $formatRowList[$rowIndex];
				}
				printf($format, $column);
			} else {
				printf("%${fieldLength}.2f", $column);
			}
			$columnIndex++;
		}
		print "\n";
		$rowIndex++;
	}
}


sub printGeneric($$@) {
	my ($self, $dataRef, $fieldLength, $formatRef, $prefixFormat, $prefixData) = @_;
	my @formatList;
	if (defined $formatRef) {
		@formatList = @{$formatRef};
	}

	foreach my $row (@{$dataRef}) {
		my $columnIndex = 0;
		if (defined $prefixFormat) {
			printf($prefixFormat, $prefixData);
			$columnIndex++;
		}
		foreach my $column (@$row) {
			if (defined $formatList[$columnIndex]) {
				printf("$formatList[$columnIndex]", $column);
			} else {
				printf("%${fieldLength}.2f", $column);
			}
			$columnIndex++;
		}
		print "\n";
	}
}

1;
