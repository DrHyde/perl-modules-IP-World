# script to set up for installation of IP::World

use strict;
use warnings;
use Module::Build;
use Config;

my @ccflags = ();
my $opt;
my $cc = $Config{'cc'};
$cc =~ s/\s+-.+$//; #remove possible trailing options
my @ccs = split /\s+/, $cc;

# test which cc optimize flags are allowed
# move '#' from following line to next line for debugging 
# for my $s ('-g') {  
for my $s ('-O3', '-O2', $Config{'optimize'}) {
    if (!$s) {last}
    if (!(system(@ccs, '-c', $s, 'test.c') >> 8)) {
        $opt = $s;
        last;
}   }
# see if this system includes Mmap
if (!(system(@ccs, '-c', 'test_mmap.c') >> 8)) {
    push @ccflags, extra_compiler_flags => ["-DMMAPOK"];
}
unlink('test.o', 'test_mmap.o');

my $class = Module::Build->subclass(code => <<'ZZZZ');
use File::Copy;
# this is called during each Build step
sub process_dat_files {
    my $self = shift;
    my $invoked = $self->invoked_action();
    my $current = $self->current_action();
    # print "invoked action is '${invoked}', current action is '${current}'\n";
    if ($current eq 'code') {
    
        # create destination directories as necessary
        my $dest = '';
        for ('blib/lib/auto', '/IP', '/World') {
            if (!-d ($dest .= $_)) {
                mkdir $dest or die "Can't make dir $dest: $!";
        }   }
        $dest .= '/ipworld.dat';

        # select source file based on this machine's endianness
        my $bigend = pack('L', 1) eq pack('N', 1);
        my $srcdir = 'lib/auto/IP/World';
        my $src = "$srcdir/ipworld." .($bigend ? 'be' : 'le');
        
        # get the proper mod time for the file from an accompanying file
        my ($src_mod, $dest_mod);
        my $fn = "$srcdir/modtime.dat";
        open DAT, "<$fn" or die "Can't open $fn for read: $!";
        read (DAT, $src_mod, 4)==4 or die "Can't read from $fn: $!";
        close DAT;
        $src_mod = unpack 'N', $src_mod;
        
        # set the mod times of the included files (in case someone copies)
        for ('be', 'le') {
            $fn = "$srcdir/ipworld.$_";
            utime($src_mod, $src_mod, $fn)==1
                or die "Can't set mod time of $fn: $!";
        }
        # copy database if necessary
        if (!-e $dest 
         || $src_mod > ($dest_mod = (CORE::stat $dest)[9])
         || $src_mod == $dest_mod
         && -s $src != -s $dest) {

            # copy the file
            copy ($src, $dest) 
                or die "Can't copy $src to $dest: $!";
            utime($src_mod, $src_mod, $dest)==1 
                or die "Can't set mod time of $dest";
            print "Copying $src -> $dest\n";
        }
        # temporary until the M::B guys include docs in test
        if ($invoked eq 'test') {$self->depends_on('docs')} 
    }
    if ($invoked eq 'install') {
    
        # run maint_ip_world_db to update the database if necessary          
        my $tail = $self->is_unixish() ? ' 2>&1' : '';
        print "Checking for database update (may rebuild)...\n";        
        my $result = `script/maint_ip_world_db -t$tail`;
        print $result;
}   }
ZZZZ

my $build = $class->new(
    build_requires     => {'ExtUtils::CBuilder' => 0,
                           'File::Copy'         => 0,
                           'Module::Build'      => '0.36',
                           'Probe::Perl'        => 0,
                           'Test::More'         => 0},
    configure_requires => {'Config'             => 0},
    dist_author        => 'Craig MacKenna <craig@animalhead.com>',
    dynamic_config     => 1,
    license            => 'perl',
    module_name        => 'IP::World',
    requires           => {'perl'           => '5.7.3',
                           'Carp'           => 0,
                           'File::ShareDir' => 0,
                           'LWP::UserAgent' => 0,
                           'HTTP::Status'   => 0,
                           'Time::HiRes'    => 0},
    script_files        => 'script',
    @ccflags
);
# send the optimize code determined above to the C compiler
if ($opt) {$build->config(optimize => $opt)}

# this arranges for 'process_dat_files' (and thus maint_ip_world_db) 
#   to be called during the Build step
$build->add_build_element('dat');

# ask whether the user wants maint_ip_world_db to run a command when the DB is updated
my $cmd = $build->prompt("Should the DB-update utility run a command when the "
                       . "DB is updated?\nIf so enter it (if not just return):", "");

# if so, store the command to run in the config_data structure(s)
if ($cmd) {$build->config_data(cmd => $cmd)}

$build->create_build_script;
