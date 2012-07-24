# ExtractStresshighalloc.pm
package MMTests::ExtractStresshighalloc;
use MMTests::Extract;
use MMTests::Print;
our @ISA = qw(MMTests::Extract); 

use constant DATA_STRESSHIGHALLOC	=> 400;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractStresshighalloc",
		_DataType    => DATA_STRESSHIGHALLOC,
		_ResultData  => [],
		_ExtraData   => [],
	};
	bless $self, $class;
	return $self;
}

sub printDataType() {
	print "PercentageAllocated";
}

sub initialise() {
	my ($self, $reportDir) = @_;

	$self->SUPER::initialise();
	my $fieldLength = $self->{_FieldLength};
	$self->{_FieldHeaders} = [ "Pass", "Success" ];
	$self->{_FieldFormat} = [ "%-${fieldLength}d", "%${fieldLength}d" ];
	$self->{_ExtraHeaders} = [ "Pass", "Attempt", "Result", "Latency" ];
	$self->{_ExtraLength} = $self->{_FieldLength};
	$self->{_ExtraFormat} = [ "%-${fieldLength}d", "%-${fieldLength}d", "%${fieldLength}s" , "%${fieldLength}d" ];
}

sub printSummary() {
	my ($self, $subHeading) = @_;
	$self->printReport();
}

sub printReport() {
	my ($self) = @_;
	$self->{_PrintHandler}->printGeneric($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my $file = "$reportDir/noprofile/log.txt";
	my $pass = 0;

	open(INPUT, $file) || die("Failed to open $file\n");
	while (<INPUT>) {
		my ($dummy, $success);

		if ($_ =~ /Results Pass 1/) {
			$pass = 1;
			next;
		}
		if ($_ =~ /Results Pass 2/) {
			$pass = 2;
			next;
		}
		if ($_ =~ /while Rested/) {
			$pass = 3;
			next;
		}

		if ($_ =~ /^([0-9]+) (\w+) ([0-9]+)/) {
			if ($2 eq "success" || $2 eq "failure") {
				push @{$self->{_ExtraData}}, [ $pass, $1, $2, $3 ];
			}
		}

		if ($_ =~ /% Success/) {
			($dummy, $dummy, $success) = split(/\s+/, $_);
			push @{$self->{_ResultData}}, [ $pass, $success ];
		}
	}
	close INPUT;
}

1;
