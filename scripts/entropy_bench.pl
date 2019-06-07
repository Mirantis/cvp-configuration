#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell
# $Id: entropy-random-bench,v 1.7 2014/11/27 21:58:22 dpchrist Exp $
#######################################################################
# Argument defaults -- edit to suit:

my $entropy             = '/proc/sys/kernel/random/entropy_avail';
my $random              = '/dev/urandom';
my $duration            =   60.0;       # seconds
my $entropy_upper       = 4095;         # bits
my $entropy_lower       =    0;         # bits
my $nap_upper           =   10.0;       # seconds
my $nap_lower           =    1.0E-06;   # seconds
my $gain                =   10.0;       # seconds / bit

#######################################################################
# The rest of the script should not be edited:

use strict;
use warnings;

use Getopt::Long                qw(
                                    :config
                                    auto_help
                                    auto_version
                                );
use Pod::Usage;
use Time::HiRes         qw( sleep time );

$| = 1;

our $VERSION    = sprintf("%d.%03d", q$Revision: 1.7 $ =~ /(\d+)/g);
my $man;

GetOptions(
    "entropy=s"         => \$entropy,
    "random=s"          => \$random,
    "duration=f"        => \$duration,
    "entropy-upper=f"   => \$entropy_upper,
    "entropy-lower=f"   => \$entropy_lower,
    "nap-upper=f"       => \$nap_upper,
    "nap-lower=f"       => \$nap_lower,
    "gain=f"            => \$gain,
    "man"               => \$man,
) or pod2usage(2);
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

my $entropy_span        = $entropy_upper - $entropy_lower;
my $entropy_setpoint    = $entropy_upper / 2;
my $nap_span            = $nap_upper - $nap_lower;
my $nap_offset          = $nap_upper / 2;

my $err;
my $buf;
my $e1;
my $e2;
my $t1;
my $t2;
my $rate;
my $dt;
my $signal;
my $nap                 = $nap_lower;
my $lastprint;

open(my $random_fh, $random) or die "error opening $random: $!";
$err = sysread($random_fh, $buf, 1);
die "error reading $random: $!" unless defined $err && $err;

### /proc/sys/kernel/random/entropy_avail is not world-readable, but
### 'cat' can read it (?)
$e1 = `cat $entropy`;
chomp $e1;

print "time (seconds)  entropy (bits)  random (bytes/second)\n",
      "==============  ==============  ======================\n";
my $begin = $lastprint = $t1 = time();
my $end = $begin + $duration;
do {
    sleep($nap);

    $err = sysread($random_fh, $buf, 1);
    die "error reading $random: $!" unless defined $err;

    $e2 = `cat $entropy`;
    chomp $e2;

    $t2 = time();
    $dt = $t2 - $t1;
    $rate = 1.0 / $dt;
    if ($dt && ($lastprint + 1 < $t2)) {
        $lastprint = $t2;
        printf "%14.06f  %14i  %22.6f\n",
            $t2 - $begin,
            $e2,
            $rate;
    }
    $signal = ($e2 - $entropy_setpoint) / $entropy_span;
    $nap = -1.0 * $gain * $signal * $nap_span + $nap_offset;
    $nap = $nap_lower if $nap       < $nap_lower;
    $nap = $nap_upper if $nap_upper < $nap;
    $e1 = $e2;
    $t1 = $t2;
} while ($t2 < $end);
DONE:

__END__

=head1 NAME

entropy-random-bench - Linux entropy pool / random number benchmark

=head1 SYNOPSIS

 entropy-random-bench.pl [options]

  Options:
   --entropy                    path to entropy availble file
   --random                     path to random number file
   --duration                   duration of benchmark
   --entropy-upper              upper range value of entropy available
   --entropy-lower              lower range value of entropy available
   --nap-upper                  upper range value for sleep() calls
   --nap-lower                  upper range value for sleep() calls
   --gain                       timing loop proportional gain
   --man                        print manual page and exit
   --help, -?                   print usage message and exit

=head1 DESCRIPTION

Interactive benchmark for Linux entropy pool
and random number generator.

$Revision: 1.7 $

=head1 SEE ALSO

=head1 AUTHOR

David Paul Christensen, E<lt>dpchrist@holgerdanske.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by David Paul Christensen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut

