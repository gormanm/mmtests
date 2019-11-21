# MonitorMpstat.pm
package MMTests::MonitorMpstat;
use MMTests::SummariseMonitor;
use Visualise::VisualiseFactory;
our @ISA = qw(MMTests::SummariseMonitor);
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName	=> "MonitorMpstat",
		_DataType	=> DataTypes::DATA_USAGE_PERCENT,
		_PlotType	=> "simple",
		_PlotXaxis	=> "Time",
		_PlotYaxis	=> "Total CPU Percentage",
		_DefaultPlot	=> "allcpus-usage",
	};
	bless $self, $class;
	return $self;
}

sub extractReport($$$$) {
	my ($self, $reportDir, $testBenchmark, $subHeading, $rowOrientated) = @_;
	my $nid;
	
	die if $subHeading !~ /^node-([0-9]*)/;
	$nid = $1;

	my $modelFactory = Visualise::VisualiseFactory->new();
	my $model = $modelFactory->loadModule("model", "topology");
	$model->parse("$reportDir/cpu-topology-mmtests.txt");

	my $renderFactory = Visualise::VisualiseFactory->new();
	my $renderer = $renderFactory->loadModule("render", "mmtests");
	$renderer->setCutoff($subHeading);
	$renderer->setOutput($self);

	my $logparserFactory = Visualise::VisualiseFactory->new();
	my $logparser = $logparserFactory->loadModule("extract", "mpstat");
	$logparser->start("$reportDir/mpstat-$testBenchmark");
	while ($logparser->parseOne($model)) {
		$renderer->renderOne($model, $logparser->getTimestamp());
		$model->clearValues();
	}
	$logparser->end("$reportDir/mpstat-$testBenchmark");
}

1;
