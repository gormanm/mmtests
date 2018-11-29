# CompareFactory.pm
package MMTests::CompareFactory;
use MMTests::Report;
use strict;

sub new() {
	my $class = shift;
	my $self = { };

	bless $self, $class;
	return $self;
}

sub loadModule($$$) {
	my ($self, $moduleName, $format, $extractModules) = @_;
	printVerbose("Loading module $moduleName\n");

	my $pmName = $moduleName;
	$pmName = ucfirst($pmName);
	$pmName =~ s/-//g;
	my $modName = "MMTests/Compare$pmName.pm";
	if (!eval "require \"$modName\"") {
		$pmName = "";
		require "MMTests/Compare.pm";
	} else {
		require "MMTests/Compare$pmName.pm";
	}

	my $className = "MMTests::Compare$pmName";
	my $classInstance = $className->new();
	$classInstance->initialise($extractModules);
	$classInstance->setFormat($format);
	printVerbose("Loaded  module " . $classInstance->getModuleName() . "\n");

	bless $classInstance, "MMTests::Compare$pmName";
}

1;
