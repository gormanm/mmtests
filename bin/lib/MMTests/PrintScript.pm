# PrintScript.pm
package MMTests::PrintScript;

sub new() {
	my $class = shift;
	my $self = {};
	bless $self, $class;
}

sub printTop($) { }

sub printBottom($) { }

sub printHeaders($$$) {}

sub printRow($$@) {
	my ($self, $dataRef, $fieldLength, $formatColumnRef) = @_;
	my @formatColumnList = @{$formatColumnRef};;
	my $outBuffer;
	my $checkSig = (defined $self->{_CompareTable});

	foreach my $row (@{$dataRef}) {
		my $columnIndex = 0;

		foreach my $column (@$row) {
			$outBuffer .= "$column ";
		}
		$outBuffer .= "\n";
	}
	print $outBuffer;
}

sub printHeaderRow($$@) { }

sub printRowFineFormat($$@) { }

sub printFooters() { }

1;
