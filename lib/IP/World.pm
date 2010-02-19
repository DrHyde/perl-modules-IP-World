package IP::World;

# World.pm - the Perl part of the IP::World module
#   this module maps from IP addresses to country codes, 
#   using the free WorldIP database (wipmania.com)

use strict;
use warnings;
use Carp;
use File::ShareDir qw(module_dir);

require DynaLoader;
# Exporter is not needed because we're object-oriented
our @ISA = qw(DynaLoader);

our $VERSION = '0.17';

sub new {
    my ($pkg, $mode) = @_;
    my $dd = module_dir('IP::World');
    if (!$dd) {croak "Can't locate directory containing database file"}
    my $filepath = "$dd/ipworld.dat";
    my $fileLen;

    if (!-e $filepath
     || !($fileLen = -s $filepath)) {
        croak "$filepath doesn't exist or has 0 length\n";
    }
    # call the C (XS) part of new to read the file into memory
    my $self = allocNew ($filepath, $fileLen, $mode);
    
    # bless the returned value from allocNew to be an object, and return it to the caller
    bless (\$self, $pkg);
    return \$self;
}
##### the 'getcc' and 'DESTROY' subroutines/functions/methods are completely 
##### implemented in the IP/World.xs file.

bootstrap IP::World $VERSION;
1;  # shows package is OK