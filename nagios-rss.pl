#!/usr/bin/perl -w

use strict;
use POSIX qw(strftime);
use XML::RSS;
use Getopt::Std;

our ($opt_t,$opt_d) = ('','');
getopt('t:d:');
usage() if $opt_t eq '' || $opt_d eq '';

my $nagios_link = 'http://mon1.ops/nagios/';
my $file = '/var/www/nagios.rss';

my $rss = XML::RSS->new(version => '2.0');
$rss->parsefile($file) if -e $file;

$rss->channel(
    title          => 'Nagios Alerts',
    link           => $nagios_link,
    description    => 'Nagios alerts for production',
    language       => 'en-us',
    pubDate        => 'Wed, 19 Dec 2012 11:59:43 CST',
    lastBuildDate  => (strftime "%a, %d %b %Y %H:%M:%S %Z", localtime),
);

$rss->add_item(
    title => $opt_t,
    guid  => $opt_t . time,
    description => $opt_d,
    link        => $nagios_link,
    mode        => 'insert',
    pubDate     => (strftime "%a, %d %b %Y %H:%M:%S %Z", localtime),
);

$rss->save($file);

sub usage {
    print qq{\n$0 -t [title] -d [description]\n};
    print qq{Example:\n\t $0 -t "\$NOTIFICATIONTYPE\$ Host Alert: \$HOSTNAME\$ is \$HOSTSTATE\$" -d "Notification Type: \$NOTIFICATIONTYPE\$\\nHost: \$HOSTNAME\$\\nState: \$HOSTSTATE\$\\nAddress: \$HOSTADDRESS\$\\nInfo: \$HOSTOUTPUT\$\\n\\nDate/Time: \$LONGDATETIME\$"\n\n};
    exit;
}
