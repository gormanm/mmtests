package Visualise::Visualise;
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName	=> "Visualise",
	};
	bless $self, $class;
	return $self;
}

sub initialise() {
	my ($self) = @_;
}

sub getModuleName() {
	my ($self) = @_;
	return $self->{_ModuleName};
}

sub open_file() {
	my ($self, $file) = @_;
	my $fh;

	$file =~ s/\.gz$//;
	$file =~ s/\.xz$//;
	if (-e "$file.gz") {
		open($fh, "gunzip -c $file.gz|") || die("Failed to open $file.gz: $! XXX\n");
	} elsif (-e "$file.xz") {
		open($fh, "unxz -c $file.xz|") || die("Failed to open $file.xz: $!\n");
	} elsif (-e $file) {
		open($fh, $file) || die("Failed to open $file: $!\n") || die("Failed to open $file");
	}

	return $fh;
}

1;
