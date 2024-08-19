package MMTests::Cache;
require Exporter;
use vars qw (@ISA @EXPORT);
use Cwd 'abs_path';
use Digest::MD5 qw(md5_hex);
use File::Path qw(make_path);
use File::Slurp;
use strict;

@ISA    = qw(Exporter);
@EXPORT = qw(&new &load);

my $cacheMMTests = $ENV{"CACHE_MMTESTS"};

sub new() {
	my $class = shift;
	my ($namespace, $modulename, $reportDir, $subHeading) = @_;
	my $mkpathErr;

	my $self = {};
	bless $self, $class;
	return $self if ($cacheMMTests eq "");

	eval {
		require Sereal::Encoder;
		require Sereal::Decoder;
	} or do {

		warn("ENV:MMTESTS specified but unable to load Sereal");
		return $self;
	};

	if ($cacheMMTests eq "") {
		return $self;
	}
	if ($modulename eq "" ) {
		warn("MMTests::Cache unable to be uniquely identified from $modulename, disabling cache");
		$cacheMMTests = "";
		return $self;
	}

	if (! -e $cacheMMTests) {
		make_path($cacheMMTests, {error => \$mkpathErr});
		if ($mkpathErr && @$mkpathErr) {
			warn "Failed to create cache root specified by ENV::CACHE_MMTESTS, disabling cache";
			$cacheMMTests = "";
			return $self;
		}
	} elsif (! -d $cacheMMTests) {
		warn("MMTests::Cache specified by ENV::CACHE_MMTESTS is not a directory, disabling cache");
		$cacheMMTests = "";
		return $self;
	}

	if (! -e "$reportDir/../../tests-timestamp") {
		warn("MMTests::Cache Report directory $reportDir does not appear to have tests-timestamp at $reportDir/../../, disabling cache");
		$cacheMMTests = "";
		return $self;
	}

	if (!defined $namespace) {
		warn("MMTests::Cache No namespace specified for cache, using 'incognito'");
		$namespace = "incognito";
	}

	my $absDir = abs_path($reportDir);
	my $timestamp = read_file("$reportDir/../../tests-timestamp") || die "Failed to read $reportDir/../../tests-timestamp";
	my $checksum = md5_hex($absDir, $modulename, $subHeading, $timestamp);
	my $cacheRoot = "$cacheMMTests/$namespace";
	my $cacheFile = "$cacheRoot/$checksum";
	make_path($cacheRoot, {error => \$mkpathErr});
	if ($mkpathErr && @$mkpathErr) {
		warn "Failed to create cache namespace at $cacheRoot, disabling cache";
		$cacheMMTests = "";
		return $self;
	}

	$self->{_cacheRoot} = $cacheRoot;
	$self->{_cacheFile} = $cacheFile;
	$self->{_CUID} = $checksum;

	return $self;
}

sub load() {
	my ($self, $targetObj) = @_;
	return 0 if ($cacheMMTests eq "");
	return 0 if (! -e $self->{_cacheFile});

	my $decoder = Sereal::Decoder->new({ incremental => 1 });
	my $serealDoc = read_file($self->{_cacheFile});

	while (length $serealDoc) {
		my ($value, $name);
		$decoder->decode_with_header($serealDoc, $value, $name);
		$targetObj->{$name} = $value;
	}
	return 1;
}

sub save() {
	my ($self, $targetObj, $refFields) = @_;
	return 0 if ($cacheMMTests eq "");

	my @fields = @{$refFields};
	my $encoder = Sereal::Encoder->new({ compress => Sereal::Encoder->SRL_ZSTD });
	my $serealDoc;

	foreach my $field (@fields) {
		if (defined $targetObj->{$field}) {
			$serealDoc .= $encoder->encode($targetObj->{$field}, $field);
		}
	}
	write_file($self->{_cacheFile}, $serealDoc);
	return 0;
}

1;
