#!/usr/bin/perl -w

use strict;
use LWP::Simple;
use XML::Simple;
use POSIX::strptime;
use POSIX qw(mktime);

use WWW::Hipchat::API;

my %services = (
    'AWS' => {
        'feed' => 'http://status.aws.amazon.com/rss/all.rss',
        'file' => 'aws-all.rss',
    },
    'Twitter' => {
        'feed' => 'http://status.twitter.com/rss',
        'file' => 'twitter-status.rss',
    }
);

my $max_updates   =  5;                 # show at most 5 new items

my $xs = XML::Simple->new(
    keyattr => [],
    ForceArray => ['item']);

print `date`;
foreach my $feed (keys %services) {
    process_feed($feed);
}
print "\n";



####
##  We all live in a yellow subroutine
####

sub process_feed {
    my $feed_service = shift;
    my $file    = $services{$feed_service}->{'file'};
    my $feed    = $services{$feed_service}->{'feed'};
    print "Processing: $feed_service\n\tFeed: $feed\n\tLocal file: $file\n";
    
    my $data = '';
    my $last_reported = '';                 # will store most recent 'item' from local file to compare to rss feed
    if (-e $file) {
        
        # Get the last updated item's pubDate
        $data = $xs->XMLin($file);
        for my $item (@{$data->{'channel'}->{'item'}}) {
            $last_reported = $item->{'pubDate'} if $last_reported eq '';
            $last_reported = newest_date($last_reported, $item->{'pubDate'});
        }      
        print "\tLast Item date:\t $last_reported\n";
    } else {
        # This is a first run and we do not want to alert on the feed, yet
        #   Just get a copy of the feed and return
        print "\tFirst Run.  Saving local copy of feed\n";
        getstore($feed, $file);
        return;
    }
    
    # Grab latest feed
    getstore($feed, $file);
    undef $data;
    $data = $xs->XMLin($file);
    
    
    my $i       = 0;
    my $service = '';
    #  We want to iterate through the items, starting with the oldest, and start alerting when we come to the fist "new" one
    for my $item (reverse @{$data->{'channel'}->{'item'}}) {
        next if less_date($item->{'pubDate'},$last_reported);
        $i++;
        print "\t\t$i:pubDate:\t",$item->{'pubDate'},"\n";
        
        $service = $feed_service;
        $service = $1 if $item->{'guid'} =~ m/#(\S+)_/;            # <guid>http://status.aws.amazon.com/#ec2-us-east-1_1355821828
        
        my $title = $item->{'title'};
        $title = $item->{'title'}->{'content'} if $feed_service =~ /^AWS$/;
        
        hipchat_notify($service,$title, $item->{'description'},$item->{'pubDate'});
        last if $i == $max_updates;
    }
}

sub hipchat_notify {
    my $service     = shift;        # Should be changed to 'service' (shouldn't pass guid once we start monitoring other "services")
    my $title       = shift;
    my $description = shift;
    my $pubDate     = shift;
    my $color       = 'red';
    $color = 'green' if $title =~ m/Service is operating normally/ || $description =~ m/(issue has been resolved|service is now operating normally)/;
    
    my $message   = "<strong>$pubDate - $service Status Update</strong><br /><strong>Title: </strong>$title<br /><strong>Description: </strong>$description";
    my $hipchat   = WWW::Hipchat::API->new( auth_token => 'HIPCHAT_API_AUTH_TOKEN' );
    my $response  = $hipchat->send(
        'room_id'    => 'Alerts',
        'color'      => $color,
        'from'       => 'Alerts',
        'notify'     => 1,
        'message'    => $message,
    );
}

sub less_date {
    my $pubDate      = shift;
    my $last_updated = shift;
    my $format       = "%a, %d %b %Y %H:%M:%S %Z";
    
    # Return true if item's pubDate is less than the last updated item on the local file
    return 1 if (mktime POSIX::strptime($pubDate,$format)) le (mktime POSIX::strptime($last_updated,$format));
    return 0;
}


sub newest_date {
    my $date1   = shift;
    my $date2   = shift;
    my $format  = "%a, %d %b %Y %H:%M:%S %Z";
    return (
        (mktime POSIX::strptime($date1,$format)) le (mktime POSIX::strptime($date2,$format)) ? $date2 : $date1
    );
}
