#!/usr/bin/perl -l
# Generate one or more files with random words inside.

use strict;
use warnings;
use threads;

use Getopt::Long qw(GetOptionsFromArray);


my $BRUIT_MAXLENGTH = 10;

sub bruit_generate
{
    my ($fd, $w) = @_;
    my $length = 1 + int(rand($BRUIT_MAXLENGTH));
    my $buffer = '';
    my ($i, $c);

    for ($i = 0; $i < $length; $i++) {
	$c = 65 + int(rand(26));
	$buffer .= chr($c);
    }

    printf($fd "%s\n", $buffer);
}


my %DISTRIBUTION = (
    a => 8.16, b => 1.49, c => 2.78, d => 4.25, e => 12.70,
    f => 2.22, g => 2.01, h => 6.09, i => 6.96, j => 0.15,
    k => 0.77, l => 4.02, m => 2.40, n => 6.74, o => 7.50,
    p => 1.92, q => 0.09, r => 5.98, s => 6.32, t => 9.05,
    u => 2.75, v => 0.97, w => 2.36, x => 0.15, y => 1.97,
    z => 0.07
    );

my %LENGTH_PROBA = (
    1  => 5,  2  => 5,  3  => 15,
    4  => 20, 5  => 20, 6  => 15,
    7  => 10, 8  => 5,  9  => 2,
    10 => 2,  11 => 1
    );

sub generate_english
{
    my ($i, $prob, $key);
    my $buffer = '';
    my $length;

    $prob = rand(100);
    foreach $key (keys(%LENGTH_PROBA)) {
	$prob -= $LENGTH_PROBA{$key};
	if ($prob < 0) {
	    $length = $key;
	    last;
	}
    }

    for ($i = 0; $i < $length; $i++) {
	$prob = rand(100);
	foreach $key (keys(%DISTRIBUTION)) {
	    $prob -= $DISTRIBUTION{$key};
	    if ($prob < 0) {
		$buffer .= $key;
		last;
	    }
	}
    }

    return $buffer;
}


my %DICT_MAP;

sub dict_generate
{
    my ($fd, $w) = @_;
    my $word;

    if ($w == 0) {
	%DICT_MAP = ();
    }

    do {
	$word = generate_english();
    } while (defined($DICT_MAP{$word}));
    $DICT_MAP{$word} = 1;

    printf($fd "%s\n", $word);
}


my @TEXT_LIST;

sub text_generate
{
    my ($fd, $w) = @_;
    my $retake = (rand(100) < 5);
    my ($index, $word);

    if ($w == 0) {
	@TEXT_LIST = ();
    }

    if ($retake && scalar(@TEXT_LIST)) {
	$index = int(rand(scalar(@TEXT_LIST)));
	$word = $TEXT_LIST[$index];
    } else {
	$word = generate_english();
	push(@TEXT_LIST, $word);
    }

    printf($fd "%s\n", $word);
}


sub usage
{
    return <<'EOF'
Usage: ./generate-words.pl [--word-count <count>] [--proba-model <model>]
		       [--file-count <count>] [--file-pattern <pattern>]
		       [--threads <count>]
Generate one or more files containing randomly generated words. The precise
amount of word, file and the way they are generated are controlled by the
options.

Options:
  -h, --help                       Print this help message, then exit

  -w, --word-count <count>         The amount of word generated per file. Note
				   this is not the amount of *different* words.
				   The collision rate is controller by the -m
				   option. Default = 500

  -m, --proba-model <model>        The probability model to generate the words.
				   The available models are :
				   - bruit : each word is generated
					     independently with equiprobable
					     characters
				   - dict : each word is generated with no
					    possible collision with english
					    language character probability
				   - text : same than dict but each word has
					    5% chance to be a doublon
				   Default = bruit

  -f, --file-count <count>         The amount of generated file. If only one,
				   and no -p option is specified, write on the
				   standard output. Default = 1

  -p, --file-pattern <pattern>     The pattern of filepaths to write on. The
				   last '%d' sequence is replaced by a number
				   from 1 to the value of -f option.
				   Default = generated-%d.txt

  -t, --threads <count>            The amount of thread to use to generate the
				   files. Default = 8
EOF
}


sub error
{
    my ($message, $retcode) = @_;

    if (!defined($message)) {
	$message = 'undefined error';
    }

    if (!defined($retcode)) {
	$retcode = 1;
    }

    printf(STDERR "%s: %s\nPlease type '%s --help' for more informations\n",
	   $0, $message, $0);

    exit ($retcode);
}


my @THREAD_POOL;
my $MAX_THREADS = 8;

sub register_thread
{
    my ($tid) = @_;
    my ($t, @pool);

    if (scalar(@THREAD_POOL) >= $MAX_THREADS) {
	foreach $t (@THREAD_POOL) {
	    if ($t->is_joinable()) {
		$t->join();
	    } else {
		push(@pool, $t);
	    }
	}

	@THREAD_POOL = @pool;
    }

    if (scalar(@THREAD_POOL) >= $MAX_THREADS) {
	$t = pop(@THREAD_POOL);
	$t->join();
    }

    push(@THREAD_POOL, $tid);
}

sub wait_threads
{
    my $tid;

    foreach $tid (@THREAD_POOL) {
	$tid->join();
    }
}

sub main
{
    my ($wcount, $probam, $fcount, $fpattern, $fdefpat);
    my ($ret, $generator, $f, $w, $path, $fd);
    my ($tid);
    my %generators = (
	'bruit' => \&bruit_generate,
	'dict'  => \&dict_generate,
	'text'  => \&text_generate
	);

    $ret = GetOptionsFromArray(
	\@_,
	'h|help'           => sub { printf("%s", usage()); exit (0); },
	'w|word-count=i'   => \$wcount,
	'm|proba-model=s'  => \$probam,
	'f|file-count=i'   => \$fcount,
	'p|file-pattern=s' => \$fpattern,
	't|threads=i'      => \$MAX_THREADS
	);

    $fdefpat = defined($fpattern);
    if (!defined($wcount))   { $wcount = 500; }
    if (!defined($probam))   { $probam = 'bruit'; }
    if (!defined($fcount))   { $fcount = 1; }
    if (!defined($fpattern)) { $fpattern = 'generated-%d.txt'; }

    $generator = $generators{$probam};


    if ($wcount < 1) { error("invalid --word-count option '$wcount'"); }
    if ($fcount < 1) { error("invalid --file-count option '$wcount'"); }

    if (!($fpattern =~ m|%d|)) {
	error("invalid --file-pattern option '$fpattern'");
    }

    if (!defined($generator)) {
	error("invalid --proba-model option '$probam'");
    }

    for ($f = 0; $f < $fcount; $f++) {
	$tid = async {
	    srand($f);

	    if (!$fdefpat && $fcount == 1) {
		$fd = \*STDOUT;
	    } else {
		$path = $fpattern;
		$path =~ s|^(.*)%d(.*)$|$1$f$2|;
		if (!open($fd, '>', $path)) {
		    error("cannot open '$path' : $!");
		}
	    }

	    for ($w = 0; $w < $wcount; $w++) {
		$generator->($fd, $w);
	    }

	    close($fd);
	};

	register_thread($tid);
	printf(STDERR "\r--> generating %d files", $f);
    }

    wait_threads();
    printf(STDERR "\n");

    return 0;
}

exit (main(@ARGV));
