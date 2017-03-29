#
# Blessless.pm
#
# Provides utility function to take a blessed hash reference and create an
# unblessed hash whose values are references to those of the original hash.
#
# The original object is unmodified. The returned hash is identical to it
# except for the blessing. The hash values are not copies, but shared between
# the blessed and the unblessed hash. This is suitable for JSON-serializing
# multi-gigabyte objects that cannot be copied in memory as they wouldn't fit.

package VMR::Blessless;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;

@ISA    = qw(Exporter);
@EXPORT = qw(&blessless);

sub blessless {
	my ($obj) = @_;
	my $hash;
	for my $key (keys %$obj) {
		if (ref $obj->{$key} || ref \($obj->{$key}) eq "SCALAR") {
			$hash->{$key} = $obj->{$key};
		} else {
			$hash->{$key} = \($obj->{$key});
		}
	}
	return $hash;
}
