# ExtractSqlite.pm
package MMTests::ExtractSqlite;
use MMTests::SummariseVariableops;
use VMR::Report;
our @ISA = qw(MMTests::SummariseVariableops);

use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractSqlite",
		_DataType    => MMTests::Extract::DATA_TRANS_PER_SECOND,
		_ResultData  => [],
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;

	my $file = "$reportDir/noprofile/sqlite.log";
	open(INPUT, $file) || die("Failed to open $file\n");
	my $nr_sample = 0;
	while (<INPUT>) {
		my @elements = split(/\s+/);
		next if $elements[0] eq "warmup";
		push @{$self->{_ResultData}}, ["Trans", $nr_sample++, $elements[1]];
	}

	$self->{_Operations} = [ "Trans" ];
	close INPUT;
}
1;
