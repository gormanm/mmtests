# ExtractSqlite.pm
package MMTests::ExtractSqlite;
use MMTests::SummariseVariableops;
our @ISA = qw(MMTests::SummariseVariableops);

use strict;

sub initialise() {
	my ($self, $subHeading) = @_;
	$self->{_ModuleName} = "ExtractSqlite";
	$self->{_DataType} = DataTypes::DATA_TRANS_PER_SECOND,
	$self->{_PlotType} = "simple";
	$self->SUPER::initialise($subHeading);
}

sub extractReport() {
	my ($self, $reportDir) = @_;

	my $input = $self->SUPER::open_log("$reportDir/sqlite.log");
	while (<$input>) {
		my @elements = split(/\s+/);
		next if $elements[0] eq "warmup";

		$self->addData("Trans", $elements[1], $elements[3]);
	}
	close INPUT;
}
1;
