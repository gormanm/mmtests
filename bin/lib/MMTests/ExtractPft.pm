# ExtractPft.pm
package MMTests::ExtractPft;
use MMTests::Extract;
our @ISA = qw(MMTests::Extract); 

use constant DATA_PFT		=> 200;
use VMR::Stat;
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName  => "ExtractPft",
		_DataType    => DATA_PFT,
		_ResultData  => []
	};
	bless $self, $class;
	return $self;
}

my $_pagesize = "base";

sub printDataType() {
	print "Pft";
}

sub initialise() {
	my ($self, $reportDir, $testName) = @_;
	my @clients;

	my @files = <$reportDir/noprofile/$_pagesize/pft-*.log>;
	foreach my $file (@files) {
		my @split = split /-/, $file;
		$split[-1] =~ s/.log//;
		push @clients, $split[-1];
	}
	@clients = sort @clients;
	$self->{_Clients} = \@clients;

	my $fieldLength = 12;
	$self->{_TestName} = $testName;
	$self->{_FieldLength} = $fieldLength;
	$self->{_FieldHeaders} = ["Clients", "User", "System", "Elapsed", "Faults/cpu", "Faults/sec"];
	$self->{_SummaryHeaders} = $self->{_FieldHeaders};
	$self->{_FieldFormat} = [ "%-8d", "%-${fieldLength}.2f", "%-${fieldLength}.2f", "%-${fieldLength}.2f", "%-${fieldLength}.3f", "%-${fieldLength}.3f" ];
	$self->{_FieldHeaderFormat} = [ "%-8s", "%-${fieldLength}s", "%-${fieldLength}s", "%-${fieldLength}s", "%-${fieldLength}s", "%-${fieldLength}s" ];
	$self->{_PrintHandler} = MMTests::Print->new();
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @data = @{$self->{_ResultData}};
	my @clients = @{$self->{_Clients}};
	my $fieldLength = $self->{_FieldLength};
	my @formatList = @{$self->{_FieldFormat}};

	foreach my $client (@clients) {
		my (@user, @system, @wallTime, @faultsCpu, @faultsSec);
		foreach my $row (@{$data[$client]}) {
			my @columns = @$row;
			push @user,	$columns[0];
			push @system,	$columns[1];
			push @wallTime,	$columns[2];
			push @faultsCpu,$columns[3];
			push @faultsSec,$columns[4];
		}

		push @{$self->{_SummaryData}}, [$client,
					calc_mean(@user),
					calc_mean(@system),
					calc_mean(@wallTime),
					calc_mean(@faultsCpu),
					calc_mean(@faultsSec)];
	}
	return 1;
}

sub printReport() {
	my ($self, $reportDir) = @_;
	my @clients = @{$self->{_Clients}};
	$self->_printClientReport($reportDir, @clients);
}

sub extractReport($$$) {
	my ($self, $reportDir, $reportName) = @_;
	my ($user, $system, $wallTime, $faultsCpu, $faultsSec);
	my $dummy;
	my @clients = @{$self->{_Clients}};

	foreach my $client (@clients) {
		my $file = "$reportDir/noprofile/$_pagesize/pft-$client.log";
		open(INPUT, $file) || die("Failed to open $file\n");
		while (<INPUT>) {
			my $line = $_;
			$line =~ tr/s//d;
			if ($line =~ /[a-zA-Z]/) {
				next;
			}

			# Output of program looks like
			# MappingSize  Threads CacheLine   UserTime  SysTime WallTime flt/cpu/s fault/wsec
			($dummy, $dummy, $dummy, $dummy,
		 	$user, $system, $wallTime,
		 	$faultsCpu, $faultsSec) = split(/\s+/, $line);

			push @{$self->{_ResultData}[$client]}, [ $user, $system, $wallTime, $faultsCpu, $faultsSec ];
		}
		close INPUT;
	}
}

1;
