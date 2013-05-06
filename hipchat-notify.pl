#!/usr/bin/perl -w

use strict;
use Getopt::Std;
use WWW::Hipchat::API;

$API_TOKEN = '';

our ($opt_m,$opt_r,$opt_f) = ('','','');
getopts('m:r:f:');
die "\t-r <room> and -m <message> are required\n\t-f <from> is optional\n" if $opt_m eq '' || $opt_r eq '';

my $room_id = $opt_r;
my $color   = '';
my $from    = $opt_f || 'Notify';
my $notify  = 0;
my $message = $opt_m;

my $hipchat   = WWW::Hipchat::API->new( auth_token => $API_TOKEN );
my $response  = $hipchat->send(
	'room_id'    => $room_id,
	'color'      => $color,
	'from'       => $from,
	'notify'     => $notify,
	'message'    => $message
);

if ($response !~ /Success!/) {
    print $response,"\n";
}

