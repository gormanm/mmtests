#!/usr/bin/perl

use FindBin qw($Bin);
use lib "$Bin/lib";
use Sub::Util 'subname';
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use strict;

my $opt_methods;
my $opt_ascii;
my $opt_module;
my $opt_fromroot;
my $opt_help;
my $opt_manual;

GetOptions(
	'methods|m'   => \$opt_methods,
	'ascii|a'     => \$opt_ascii,
	'module|M=s'  => \$opt_module,
	'from-root|r' => \$opt_fromroot,
	'help|h'      => \$opt_help,
	'manual'      => \$opt_manual,
) or die "Error in command line arguments\n";

pod2usage(-exitstatus => 0, -verbose => 0) if $opt_help;
pod2usage(-exitstatus => 0, -verbose => 2) if $opt_manual;

my $UP_AND_RIGHT = "\x{2514}";
my $HORIZONTAL = "\x{2500}";
my $VERTICAL = "\x{2502}";
my $VERTICAL_AND_RIGHT = "\x{251c}";

sub up_and_right {
	my $unicode = $UP_AND_RIGHT . $HORIZONTAL x 2;
	my $ascii = "`--";
	return $opt_ascii ? $ascii : $unicode;
}

sub vertical_and_right {
	my $unicode = $VERTICAL_AND_RIGHT . $HORIZONTAL x 2;
	my $ascii = "|--";
	return $opt_ascii ? $ascii : $unicode;
}

sub vertical {
	my $unicode = $VERTICAL . " " x 2;
	my $ascii = "|  ";
	return $opt_ascii ? $ascii : $unicode;
}

sub get_pmname {
	my ($moduleFileName) = @_;
	my $moduleName = $moduleFileName =~ s+.*(MMTests/.*)+\1+r;
	$moduleName =~ s+/+::+;
	$moduleName =~ s/\.pm$//;
	return $moduleName;
}

sub loadpm {
	my ($moduleFileName) = @_;
	my $moduleName = get_pmname($moduleFileName);
	eval {
		require $moduleFileName;
		1;
	} or do {
		print STDERR "Could not load $moduleName\n";
	};
}

sub get_funcs {
	my ($moduleName) = @_;
	my @pmfuncs = ();
	my %symtab = do {
		no strict "refs";
		%{"${moduleName}::"};
	};
	my $coderef = undef;
	for my $elem (keys %symtab) {
		eval {
			# Not all symbol table values are typeglobs.
			# Those that aren't, are not interesting, but break the
			# *{$symtab{$elem}} statement. So catch the error and move on.
			# Alternatively one could check if ref($symtab{$elem}) gives
			# 'GLOB', but that doesn't seem to work. (BTW, why?)
			$coderef = *{$symtab{$elem}}{CODE};
			1;
		} or do {
			next;
		};
		# Sub::Util::subname gives the name of the function qualified with
		# its original package, not the package it was imported in. It's the
		# only way to know where a function comes from.
		if(defined($coderef) && subname($coderef) =~ /^${moduleName}::/) {
			push(@pmfuncs, subname($coderef) =~ s/^${moduleName}:://r);
		}
	}
	return \@pmfuncs;
}

sub get_parent {
	my ($moduleFileName) = @_;
	loadpm($moduleFileName);
	my $moduleName = get_pmname($moduleFileName);
	my %symtab = do {
		no strict "refs";
		%{"${moduleName}::"};
	};
	my $res;
	if (exists $symtab{"ISA"}) {
		# Take first parent, we don't use multiple inheritance
		$res = *{$symtab{"ISA"}}{ARRAY}[0];
	} else {
		$res = undef;
	}
	return $res;
}

sub get_parents {
	my @files = glob("$Bin/lib/MMTests/*.pm");
	my %parents = ();
	for my $file (@files) {
		my $parent = get_parent($file);
		my $pmname = get_pmname($file);
		$parents{$pmname} = $parent;
	}
	return \%parents;
}

sub get_tree {
	my ($node, $parents) = @_;
	my $tree = {};
	my $funcs = get_funcs($node);
	if (scalar @$funcs) {
		$tree->{"methods"} = $funcs;
	}
	for my $pm (keys %$parents) {
		if ($parents->{$pm} eq $node) {
			$tree->{"subclasses"}->{$pm} = get_tree($pm, $parents);
		}
	}
	return $tree;
}

sub remove_external {
	my ($parents) = @_;
	# Some modules inherits from external perl modules (eg. Exporter).
	# Consider them as root modules.
	for my $k (keys %$parents) {
		if (defined($parents->{$k}) && ! exists $parents->{$parents->{$k}}) {
			$parents->{$k} = undef;
		}
	}
}

sub _pprint {
	my ($node, $pad) = @_;
	my $line;
	my $has_subclasses;
	my @ks;
	if (exists $node->{"subclasses"}) {
		@ks = sort(keys %{$node->{"subclasses"}});
		$has_subclasses = 1;
	}
	if ($opt_methods){
		if (exists $node->{"methods"}) {
			my @ms = sort @{$node->{"methods"}};
			my $more_pad = $has_subclasses ? vertical_and_right() : up_and_right();
			$line = $pad . $more_pad . " " . "<METHODS>";
			print("$line\n");
			$more_pad = ($has_subclasses ? vertical() : (" " x 3)) . " " x 2;
			for (my $i = 0; $i < scalar(@ms) - 1; $i++) {
				$line = $pad . $more_pad . vertical_and_right() . " " . $ms[$i];
				print("$line\n");
			}
			$line = $pad . $more_pad . up_and_right() . " " . $ms[-1];
			print("$line\n");
		}
	}
	if (! $has_subclasses) {
		return;
	}
	my $k;
	for (my $i = 0; $i < scalar(@ks) - 1; $i++) {
		$k = $ks[$i];
		$line = $pad . vertical_and_right() . " " . ($k =~ s/^MMTests:://r);
		print("$line\n");
		_pprint($node->{"subclasses"}->{$k}, $pad . vertical() . " ");
	}
	$k = $ks[-1];
	$line = $pad . up_and_right() . " " . ($k =~ s/^MMTests:://r);
	print("$line\n");
	_pprint($node->{"subclasses"}->{$k}, $pad . " " x 4 , 1);
}

sub get_subtree {
	my ($node, $target) = @_;
	my $found;
	if (exists($node->{"subclasses"}) && exists($node->{"subclasses"}->{$target})) {
		return $node->{"subclasses"}->{$target};
	} else {
		for my $k (keys %{$node->{"subclasses"}}) {
			$found = get_subtree($node->{"subclasses"}->{$k}, $target);
			last if $found;
		}
	}
	return $found;
}

sub get_ancestors {
	my ($parents, $target) = @_;
	my @ancestors = ();
	while ($parents->{$target}) {
		push @ancestors, $parents->{$target};
		$target = $parents->{$target};
	}
	return [reverse @ancestors];
}

sub get_trimtree {
	my ($tree, $ancestors, $module, $subtree) = (@_);
	my $trimtree = {"subclasses" => {}};
	my $cast = $trimtree->{"subclasses"};
	my $mold = $tree->{"subclasses"};
	for my $a (@$ancestors) {
		if (exists $mold->{$a}->{"methods"}) {
			$cast->{$a}->{"methods"} = $mold->{$a}->{"methods"};
		}
		if (exists $mold->{$a}->{"subclasses"}) {
			$mold = $mold->{$a}->{"subclasses"};
			$cast->{$a}->{"subclasses"} = {};
			$cast = $cast->{$a}->{"subclasses"};
		}
	}
	$cast->{$module} = $subtree;
	return $trimtree;
}

sub pprint {
	my ($tree, $parents, $module, $fromroot) = @_;
	if ($module) {
		my $subtree = get_subtree($tree, $module);
		if ($subtree) {
			if (! $fromroot) {
				print("$opt_module\n");
				_pprint($subtree, " ");
			} else {
				my $ancestors = get_ancestors($parents, $module);
				my $trimtree = get_trimtree($tree, $ancestors, $module, $subtree);
				print("<ROOT>\n");
				_pprint($trimtree, " ");
			}
		} else {
			print STDERR "Couldn't find module $opt_module\n";
		}
	} else {
		print("<ROOT>\n");
		_pprint($tree, " ");
	}
}

if (! $opt_ascii) {
	binmode(STDOUT, "encoding(UTF-8)");
}

if ($opt_module) {
	# The user may or may not prefix the module name with MMTests::
	# If the prefix isn't there, we add it.
	$opt_module =~ s/^MMTests:://;
	$opt_module = "MMTests::" . $opt_module;
}

if ($opt_fromroot && ! $opt_module) {
	print STDERR "The --from-root option is available only with --module MODULE";
}

my $p = get_parents();
remove_external($p);

my $tree;
$tree = get_tree(undef, $p);
pprint($tree, $p, $opt_module, $opt_fromroot);

# Below this line is help and manual page information
__END__
=head1 NAME

gen-class-hierarchy.pl - Show class hierarchy of the MMTests library

=head1 DESCRIPTION

The MMTests library contains hundreds of modules, one for each supported
benchmark. In principle every benchmark needs its own subroutine to parse
results, but some functionality is shared and benchmark modules are organized
in a class hierarchy. gen-class-hierarchy.pl helps visualizing this hierarchy
and identifying where new modules should be placed. The hierarchy is extracted
by looking at the @ISA array of each package. Packages which inherit from
external modules (such as Exporter) are shown as root packages: the program
only looks at subclass relationships within the MMTests library.

The program can optionally display class methods, as well as showing only a
subset of the entire tree.

=head1 SYNOPSIS

gen-class-hierachy.pl [options]

 Options:
 -m, --methods			Show class methods in addition to subclasses
 -a, --ascii			Use only the ASCII charset in the output
 -M MODULE, --module MODULE	Show only the subtree rooted at MODULE
 -r, --from-root		Used in conjunction with -M, show ancestors as well
 -h, --help			Print help message
 --manual			Print manual page

=head1 OPTIONS

=over 8

=item B<-m, --methods>

Show all functions defined in each package. Inheritance rules apply, so
sub-packages get all methods of their ancestors. If a package overrides a
inherited method, the method will appear in its methods list.

=item B<-a, --ascii>

By default the output uses unicode box-drawing characters. With this option,
ASCII characters are used instead.

=item B<-M MODULE, --module MODULE>

By default the entire class hierarchy is shown. With this option, only MODULE
and its subclasses are shown.

=item B<-r, --from-root>

This option is meaningful only in conjunction with --module MODULE. It will
show a hierarchy based at the root class of MODULE, pruning everything except
MODULE's ancestors. If --module isn't used, it won't have any effect.

=item B<-h, --help>

Print a help message and exit.

=item B<-m, --manual>

Show this manual page.

=back

=head1 EXAMPLES

=over 8

=item B<Default invocation>

Without any argument, the class hierarchy of the entire MMTests library will
be shown:

        $ ./gen-class-hierarchy.pl
        
        <ROOT>
         |-- Blessless
         |-- Compare
         |-- CompareFactory
         |-- DataTypes
         |-- Extract
         |   |-- ExtractMonitor
         |   `-- Summarise
         |       |-- MonitorFtrace
         |       |   |-- MonitorFtraceextfrag
         |       |   |-- MonitorFtracenumabalance
         |       |   |-- MonitorFtracenumatraffic
         |       |   |-- MonitorFtracenumatraffictotal
         |       |   |-- MonitorFtracepairlatency
         |       |   |   |-- MonitorFtraceallocstall
         |       |   |   |-- MonitorFtracecompactstall
         |       |   |   `-- MonitorFtraceshrinkerstall
         |       |   |-- MonitorFtracereclaimcompact
         |       |   |-- MonitorFtraceschedmigrate
         |       |   `-- MonitorFtracesinglelatency
         |       |       |-- MonitorFtracebalancedirtypagesstall
         |       |       |-- MonitorFtracecongestionwaitstall
         |       |       `-- MonitorFtracewaitiffcongestedstall
         ...

=item B<Subtrees>

The display can be limited to just the subclasses of a given module:

        $ ./gen-class-hierarchy.pl --module MonitorFtrace
        
        MonitorFtrace
         |-- MonitorFtraceextfrag
         |-- MonitorFtracenumabalance
         |-- MonitorFtracenumatraffic
         |-- MonitorFtracenumatraffictotal
         |-- MonitorFtracepairlatency
         |   |-- MonitorFtraceallocstall
         |   |-- MonitorFtracecompactstall
         |   `-- MonitorFtraceshrinkerstall
         |-- MonitorFtracereclaimcompact
         |-- MonitorFtraceschedmigrate
         `-- MonitorFtracesinglelatency
             |-- MonitorFtracebalancedirtypagesstall
             |-- MonitorFtracecongestionwaitstall
             `-- MonitorFtracewaitiffcongestedstall

=item B<Ancestors of module>

When a subtree is shown, it is possible to display ancestor of the selected module:

        $ ./gen-class-hierarchy.pl --module MonitorFtrace --from-root
        
        <ROOT>
         `-- Extract
             `-- Summarise
                 `-- MonitorFtrace
                     |-- MonitorFtraceextfrag
                     |-- MonitorFtracenumabalance
                     |-- MonitorFtracenumatraffic
                     |-- MonitorFtracenumatraffictotal
                     |-- MonitorFtracepairlatency
                     |   |-- MonitorFtraceallocstall
                     |   |-- MonitorFtracecompactstall
                     |   `-- MonitorFtraceshrinkerstall
                     |-- MonitorFtracereclaimcompact
                     |-- MonitorFtraceschedmigrate
                     `-- MonitorFtracesinglelatency
                         |-- MonitorFtracebalancedirtypagesstall
                         |-- MonitorFtracecongestionwaitstall
                         `-- MonitorFtracewaitiffcongestedstall

=item B<Class methods>

In addition to subclasses, methods can also be shown:

        $ ./gen-class-hierarchy.pl --module MonitorFtracesinglelatency --methods
        
        MonitorFtracesinglelatency
         |-- <METHODS>
         |    |-- add_regex
         |    |-- add_regex_noverify
         |    |-- ftraceCallback
         |    |-- ftraceInit
         |    |-- initialise
         |    |-- set_delay_threshold
         |    `-- set_jiffie_multiplier
         |-- MonitorFtracebalancedirtypagesstall
         |   `-- <METHODS>
         |        |-- ftraceInit
         |        |-- ftraceReport
         |        `-- initialise
         |-- MonitorFtracecongestionwaitstall
         |   `-- <METHODS>
         |        |-- ftraceInit
         |        `-- ftraceReport
         `-- MonitorFtracewaitiffcongestedstall
             `-- <METHODS>
                  |-- ftraceInit
                  `-- ftraceReport

=back

=head1 AUTHOR

Written by Giovanni Gherdovich <ggherdovich@suse.cz>

=head1 REPORTING BUGS

Report bugs to the author.

=cut
