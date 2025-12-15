# ExtractFactory.pm
package MMTests::ExtractFactory;
use FindBin qw($Bin);
use MMTests::Report;
use strict;

sub new() {
	my $class = shift;
	my $self = { };

	bless $self, $class;
	return $self;
}

sub loadModule($$$) {
	my ($self, $type, $moduleName, $testName, $subheading) = @_;
	printVerbose("Loading module $moduleName\n");

	# Construct module name
	my $loadModule;
	my $pmName = ucfirst($moduleName);
	$pmName =~ s/-//g;
	$pmName =~ s/Bonnie\+\+/Bonniepp/;
	$type = ucfirst($type);
	$loadModule = "MMTests/$type$pmName.pm";

	# Load specific module if available or generic extraction
	# module if YAML configuration exists
	my $className;
	my $shellpackRoot = "$Bin/../shellpack_src/src/" . lc($moduleName);
	my $shellpackConfig = $shellpackRoot . "/shellpack.yaml";
	if (eval "require \"$loadModule\"") {
		printVerbose("Import  specific module MMTests::$type$pmName\n");
		$pmName->import();
		$className = "MMTests::$type$pmName";
        } else {
		die("Extraction module $type$pmName does not exist and generic extraction not configured with shellpack.yaml") if (! -e $shellpackConfig);
		$loadModule = "MMTests/${type}Shellpack.pm";
		$className = "MMTests::${type}Shellpack";
		$pmName = "Shellpack";
		require $loadModule;
		$pmName->import();
		printVerbose("Import  generic module MMTests::ExtractShellpack\n");
	}

	# Common module configuration
	my $classInstance = $className->new(0);
	$classInstance->{_ModuleName} = "$type$pmName";
	$classInstance->{_TestName} = $testName;
	$classInstance->{_ShellpackRoot} = $shellpackRoot;
	if (-e $shellpackConfig) {
		$classInstance->{_ShellpackConfig} = $shellpackConfig;
		$classInstance->{_ShellpackParser} = $classInstance->{_ShellpackRoot}  . "/parse-results";
		die("Shellpack config ($shellpackConfig) exists but parse-results does not exist") if (! -f $classInstance->{_ShellpackParser});
		die("Shellpack config ($shellpackConfig) exists but parse-results is not executable") if (! -x $classInstance->{_ShellpackParser});
		printVerbose("YAML    config $shellpackConfig\n");
	}
	$classInstance->initialise($subheading);
	$classInstance->setFormat("generic");

	printVerbose("Loaded  module " . $classInstance->getModuleName() . "\n");

	bless $classInstance, $className;
}

1;
