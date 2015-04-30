#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

my $opt_interface = '';
my $opt_all;
my $opt_ipv4;
my $opt_ipv6;
my $opt_mtu;
my $opt_scope = '';
my $opt_listup;
my $file = '';

GetOptions(
	"interface|i=s"	=> \$opt_interface,
	"all|a"		=> \$opt_all,
	"ipv4|4"	=> \$opt_ipv4,
	"ipv6|6"	=> \$opt_ipv6,
	"mtu|m"		=> \$opt_mtu,
	"scope|s=s"	=> \$opt_scope,
	"list-up|u"	=> \$opt_listup,
	"filename|f=s"	=> \$file,
	);

if ($file eq '') {
	die("Please provide a file\n");
} elsif (-e $file) {
	open(INPUT, $file) || die("Failed to open $file: $!\n");
} else {
	die("$file doesn't exist\n");
}

if ($opt_all) {
	$opt_ipv4 = 1;
	$opt_ipv6 = 1;
	$opt_scope = '';
	$opt_mtu = 1;
}

if ($opt_scope && (!$opt_ipv4 && !$opt_ipv6)) {
	$opt_ipv4 = 1;
	$opt_ipv6 = 1;
}

if ($opt_interface && (!$opt_ipv4 && !$opt_ipv6 && !$opt_mtu)) {
	$opt_ipv4 = 1;
	$opt_ipv6 = 1;
}

# Parse the output of 'ip addr'
my $ifname;
my %iflist;

while (<INPUT>) {
	if ($_ =~ /^[0-9]+:/) {
		my @fields = split(/[:\s]+/, $_);

		$ifname = $fields[1];

		$iflist{$ifname}{'mtu'} = $fields[4];
		$iflist{$ifname}{'state'} = $fields[8]

	} elsif ($_ =~ /^\s+inet/) {
		my @fields = split(/[\/\s]+/, $_);
		my $type;
		my $ip;
		my $scope;

		if ($fields[1] eq 'inet') {
			$type = 'ipv4';
			$ip = $fields[2];
			$scope = $fields[7];

		} elsif ($fields[1] eq 'inet6') {
			$type = 'ipv6';
			$ip = $fields[2];
			$scope = $fields[5];
		}

		my $iplist_ref;
		$iplist_ref = \@{ $iflist{$ifname}{$type}{$scope} };
		$$iplist_ref[++$#$iplist_ref] = $ip;
	}
}

# Print the result
sub show_contents (\%$$) {
	my($list_ref, $ifname, $show_name) = @_;

	if (!$$list_ref{$ifname}) {
		return;
	}

	if ($opt_listup && $$list_ref{$ifname}{'state'} eq 'DOWN') {
		return;
	}

	if ($opt_scope &&
	    (!($opt_ipv4 && $$list_ref{$ifname}{'ipv4'}{$opt_scope}) &&
	     !($opt_ipv6 && $$list_ref{$ifname}{'ipv6'}{$opt_scope}))) {
		return;
	}

	if ($show_name) {
		print "$ifname ";
	}

	if ($opt_ipv4) {
		foreach my $scope (sort keys %{ $$list_ref{$ifname}{'ipv4'} }) {
			if ($opt_scope eq '' || $scope eq $opt_scope) {
				print "@{ $$list_ref{$ifname}{'ipv4'}{$scope} } ";
			}
		}
	}
	if ($opt_ipv6) {
		foreach my $scope (sort keys %{ $$list_ref{$ifname}{'ipv6'} }) {
			if ($opt_scope eq '' || $scope eq $opt_scope) {
				print "@{ $$list_ref{$ifname}{'ipv6'}{$scope} } ";
			}
		}
	}
	if ($opt_mtu) {
		print "$$list_ref{$ifname}{'mtu'} ";
	}

	print "\n";
}

if ($opt_interface eq '') {
	foreach my $ifname (sort keys %iflist) {
		show_contents(%iflist, $ifname, 1);
	}
} else {
	show_contents(%iflist, $opt_interface, 0);
}

close(INPUT);
