#!/usr/bin/perl -w

use strict;
use Amazon::SNS;
use Getopt::Std;

our ($opt_m,$opt_t) = ('','');
getopt('m:t:');
usage() if $opt_m eq '' || $opt_t eq '';

my $AWS_KEY    = "AWS KEY";
my $AWS_SECRET = "AWS SECRET";

my $sns = Amazon::SNS->new({'key' => $AWS_KEY, 'secret' => $AWS_SECRET});
$sns->service('http://sns.us-east-1.amazonaws.com');

my $topic = get_arn($opt_t);

my $notification = $sns->GetTopic($topic);
$notification->Publish($opt_m);

print $sns->error,"\n" if $sns->error;



######
##  We all live in a yellow subroutine
######

sub usage {
    print qq{\n$0 -m [message] -t [topic]\n};
    print qq{Example:\t $0 -m "example message" -t testAlert\n\n};
    exit;
}

sub get_arn {
    my $query  = shift;
    my @topics = $sns->ListTopics;
    foreach my $topic (@topics) {
        return $topic->arn if $topic->arn =~ $query;
    }
    die "Couldn't find the topic $topic\n";
}
