# PrintGeneric.pm
package MMTests::PrintGeneric;

sub new() {
	my $class = shift;
	my $self = {};
	bless $self, $class;
}

sub printTop($)
{
}

sub printBottom($)
{
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

sub printRow($$@) {
	my ($self, $dataRef, $fieldLength, $formatColumnRef, $formatRowRef, $prefix) = @_;
	my (@formatColumnList, @formatRowList);
	my $rowIndex = 1;
	@formatColumnList = @{$formatColumnRef};
	@formatRowList = @{$formatRowRef};

	foreach my $row (@{$dataRef}) {
		my $columnIndex = 0;
		my @rowArr = @$row;

		if ($prefix ne "") {
			unshift @rowArr, $prefix;
		}

		foreach my $column (@rowArr) {
			my $out;
			$column =~ s/:SIG:$//;
			$column =~ s/:NSIG:$//;
			if (defined $formatColumnList[$columnIndex]) {
				my $format = $formatColumnList[$columnIndex];
				if ($format eq "ROW") {
					$format = $formatRowList[$rowIndex];
				}
				$out = sprintf($format, $column);
			} else {
				$out = sprintf("%${fieldLength}.2f", $column);
			}
			print (defined $column ? $out : " "x(length $out));
			$columnIndex++;
		}
		print "\n";
		$rowIndex++;
	}
}

sub printHeaderRow($$@) {
	my ($self, $dataRef, $fieldLength, $formatColumnRef, $formatRowRef) = @_;
	$self->printRow($dataRef, $fieldLength, $formatColumnRef, $formatRowRef);
}

sub printRowFineFormat($$@) {
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

sub printFooters() {
}

1;
