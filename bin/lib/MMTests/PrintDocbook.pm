# PrintDocbook.pm
package MMTests::PrintDocbook;

my $_colspan;

sub new($) {
	my $class = shift;
	if ($_[0] == 1) {
		$_colspan = 2;
	} else {
		$_colspan = 1;
	}
	my $self = {};
	bless $self, $class;
}

sub printTop($)
{
	print "<table frame='all'>\n";
}

sub printBottom($)
{
	print "</tbody>\n";
	print "</tgroup>\n";
	print "</table>\n";
}

sub printHeaders($$$) {
	my $self = shift;
	my $fieldLength = shift;
	my @fieldHeaders = @{ $_[0] };
	my @formatList = @{ $_[1] };
	my $header;

	print "<row>";
	my $headerIndex = 0;
	foreach $header (@fieldHeaders) {
		if (defined $formatList[$headerIndex]) {
			for (my $i = 0; $i < $_colspan; $i++) {
				my $format = "<entry>$formatList[$headerIndex]</entry>";
				printf($formatList[$headerIndex], $header);
			}
		} else {
			printf("<entry>%${fieldLength}s</entry>", $header);
		}
		$headerIndex++;
	}
	print "</row>\n";
}

sub _printRow($$@) {
	my ($self, $dataRef, $fieldLength, $elementOpen, $elementClose, $elementSpan, $formatColumnRef) = @_;
	my (@formatColumnList, @formatRowList);
	my $rowIndex = 1;
	@formatColumnList = @{$formatColumnRef};

	foreach my $row (@{$dataRef}) {
		my $columnIndex = 0;

		print "<row>";
		foreach my $column (@$row) {
			my $elementExtra = "";

			if ($elementSpan > 0) {
				my $st = $columnIndex * $elementSpan + 1;
				$elementExtra = " namest=\"col" . ($st) . "\" nameend=\"col" . ($st + 1) . "\"";
			}

			if (defined $formatColumnList[$columnIndex]) {
				my $format = $formatColumnList[$columnIndex];
				my $cellcolor = "";

				if ($column =~ /:SIG:$/) {
					$column =~ s/:SIG:$//;
					if ($column > 0) {
						$cellcolor = "bgcolor=\"#A0FFA0\"";
					} else {
						$cellcolor = "bgcolor=\"#FFA0A0\"";
					}
				}
				$column =~ s/:NSIG:$//;

				$cellcolor = "";

				$format = "<$elementOpen$elementExtra$cellcolor>$format</$elementClose>";
				printf($format, $column);
			} else {
				printf("<$elementOpen$elementExtra>%${fieldLength}.2f</$elementClose>", $column);
			}
			$columnIndex++;
		}
		print "</row>\n";
		$rowIndex++;
	}
}

sub printHeaderRow($$@) {
	my ($self, $dataRef, $fieldLength, $formatColumnRef) = @_;

	my @rows = @{$dataRef};
	my @tests = @{$rows[0]};
	my $nr_col = $#tests * 2 + $_colspan;

	print "<title></title>\n";
	print "<tgroup cols='$nr_col' align='left' colsep='1' rowsep='1'>\n";
	for (my $i = 1; $i <= $nr_col; $i++) {
		print "<colspec colnum=\"$i\" colname=\"col$i\" />\n";
	}
	print "<thead>\n";
	for (my $i = 0; $i < $_colspan; $i++) {
		$self->_printRow($dataRef, $fieldLength, "entry", "entry", 2, $formatColumnRef);
	}
	print "</thead>\n";
	print "<tbody>\n";
}

sub printRow($$@) {
	my ($self, $dataRef, $fieldLength, $formatColumnRef) = @_;
	$self->_printRow($dataRef, $fieldLength, "entry", "entry", 0, $formatColumnRef);
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
