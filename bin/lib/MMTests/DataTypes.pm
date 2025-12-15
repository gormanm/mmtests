package DataTypes;

use base qw(Exporter);

our @EXPORT = qw(LABEL_TIME_NSECONDS LABEL_TIME_USECONDS LABEL_TIME_MSECONDS LABEL_TIME_SECONDS LABEL_KBYTES_PER_SECOND LABEL_KBYTES LABEL_OPS_PER_SECOND LABEL_OPS_PER_MINUTE LABEL_TRANS_PER_SECOND LABEL_MBITS_PER_SECOND LABEL_KBYTES_PER_SECOND LABEL_MBYTES_PER_SECOND LABEL_GBYTES_PER_SECOND LABEL_FAILURES LABEL_OPS_SPREAD);

use constant LABEL_TIME_NSECONDS	=> "Time (nsec)";
use constant LABEL_TIME_USECONDS	=> "Time (usec)";
use constant LABEL_TIME_MSECONDS	=> "Time (msec)";
use constant LABEL_TIME_SECONDS		=> "Time (sec)";
use constant LABEL_KBYTES_PER_SECOND	=> "KBytes/sec";
use constant LABEL_KBYTES		=> "KiB";
use constant LABEL_OPS_PER_SECOND	=> "Ops/sec";
use constant LABEL_OPS_PER_MINUTE	=> "Ops/min";
use constant LABEL_OPS_SPREAD		=> "Ops spread";
use constant LABEL_TRANS_PER_SECOND	=> "Transactions/sec";
use constant LABEL_MBITS_PER_SECOND	=> "Mbits/sec";
use constant LABEL_KBYTES_PER_SECOND	=> "KBytes/sec";
use constant LABEL_MBYTES_PER_SECOND	=> "MBytes/sec";
use constant LABEL_GBYTES_PER_SECOND	=> "GBytes/sec";
use constant LABEL_FAILURES		=> "Failures";

sub getDataTypeLabel($) {
	no strict;
	return &{"LABEL_" . $_[0]}();
}

1;
