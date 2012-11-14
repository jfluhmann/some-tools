#!/usr/bin/perl -w

use strict;
use Getopt::Long;

my $seek_file = '/tmp/seek';
my $archive_location = '/var/log/nagios3/archive';

# Get current date/time
my ($sec, $min, $hr, $day, $mon, $year) = localtime;
$mon += 1;
$year += 1900;

# Set defaults and grab any passed parameters
my $seek     = 1;                       # We're 'seeking' by default (seeking from last read position)
my $file     = '/var/log/nagios3/nagios.log';
my $help     = 0;
my $reset    = 0;                       # --reset|r will reset the seek position to "first run"
my $pretty   = 0;
my $messages = 0;                       # We're not printing 'messages ($5)' from Nagios log, unless --messages|m is passed

GetOptions( 'seek!'     => \$seek,      # 'seek position' will be 0 if --noseek is passed, new seek position is not saved
            'file=s'    => \$file,
            'reset'     => \$reset,     # 'reset' starts seek at '0' and saves new seek position
            'pretty'    => \$pretty,    # prints a 'human-readable' timestamp
            'messages!' => \$messages,
            'help'      => \$help);

usage() if $help;

# Exit if log file doesn't exist
if ( ! -e $file ) {
    print "$file doesn't exist!";
    usage();
}


# Grab previously stored seek position
my $current_seek_position = grab_seek_pos($seek_file);
$current_seek_position    = 0 if $reset;
my $seek_pos  = 0;
$seek_pos     = $current_seek_position if $seek;     # if passed, --noseek ignores SEEK position and runs from beginning of file (without resetting SEEK position)

# Grab log file size
my $file_size = (stat($file))[7];

# Make sure we're not trying to 'seek' beyond the file
if ( $seek_pos > $file_size ) {     # Log file has likely been rotated
    if ( $hr == 0 ) {               # Check if we're after midnight (we rotate nagios logs daily, at midnight)
        
        # We running just after midnight, grab the previous log and reset $seek_pos to 0
        my $archive_file = $archive_location."/nagios-$mon-$day-$year-00.log";
        parse_log( $archive_file, $seek_pos );
        $seek_pos = 0;
    }
}

exit unless $seek_pos < $file_size;     # We don't need to parse unless there's new data

parse_log( $file, $seek_pos );
set_seek_pos($seek_file, $current_seek_position) if !$seek;     # set the seek position back, since we ran --noseek




####
# 
# We all live in a yellow subroutine
#
####

sub parse_log {
    my ($file,$seek_pos) = @_;
    open ( my $LOG_FILE, $file );
    seek($LOG_FILE, $seek_pos,0);
    
    my ($timestamp,$msg_type,$info,$status,$message,@info_bits,$host,$service,$state);
    while (my $line = <$LOG_FILE>) {
        if ($line =~ /\[(\d+)\] ([\w\s]+): ([\w\-;]+);(.*)$/) {
            $timestamp = $1;
            $msg_type  = $2;
            $info      = $3;
            $message   = $4 || '';
            ($host,$state,$service) = parse_bits($msg_type, (split ';', $info) );
            $timestamp = pretty_timestamp($timestamp) if $pretty;
            print $timestamp,"\t",$msg_type,"\t",$host,"\t",$state,"\t",$service,"\t";#,$status,"\t",$info;
            print "\t",$info;
            print "\t",$message if $messages;
            print "\n";
        }
    }

    # Store our current position in the file for the next run
    set_seek_pos($seek_file, tell($LOG_FILE));
    close $LOG_FILE;
}

sub pretty_timestamp {
    my $ts = shift;
    my ($sec, $min, $hr, $day, $mon, $year) = gmtime($ts);
    $mon +=1;
    $year +=1900;
    $mon = '0'.$mon if $mon < 10;
    $day = '0'.$day if $day < 10;
    $hr  = '0'.$hr if $hr < 10;
    $min = '0'.$min if $min < 10;
    $sec = '0'.$sec if $sec < 10;
    return "$mon/$day/$year $hr:$min:$sec";
}



sub parse_bits {
    my ($msg_type,@info_bits) = @_;
    
    # Match info_bits parsing of host, state, and service to Message Types
    my %types = (
        'HOST ALERT'              => { 'host' => '0', 'state' => '1', 'service' => '-1' },
        'HOST NOTIFICATION'       => { 'host' => '1', 'state' => '2', 'service' => '-1' },
        'CURRENT HOST STATE'      => { 'host' => '0', 'state' => '1', 'service' => '-1' },
        'INITIAL HOST STATE'      => { 'host' => '0', 'state' => '1', 'service' => '-1' },
        'HOST FLAPPING ALERT'     => { 'host' => '0', 'state' => '1', 'service' => '-1' },
        'SERVICE ALERT'           => { 'host' => '0', 'state' => '2', 'service' => '1' },
        'SERVICE FLAPPING ALERT'  => { 'host' => '0', 'state' => '2', 'service' => '1' },
        'SERVICE NOTIFICATION'    => { 'host' => '1', 'state' => '3', 'service' => '2' },
        'CURRENT SERVICE STATE'   => { 'host' => '0', 'state' => '2', 'service' => '1' },
        'INITIAL SERVICE STATE'   => { 'host' => '0', 'state' => '2', 'service' => '1' },
#         'HOST DOWNTIME ALERT'   => { 'host' => '', 'state' => '', 'service' => '' },
#         'SVC DOWNTIME ALERT'    => { 'host' => '', 'state' => '', 'service' => '' },
#         'SCHEDULE SVC DOWNTIME' => { 'host' => '', 'state' => '', 'service' => '' },
#         'SCHEDULE FORCED SVC CHECK' => { 'host' => '', 'state' => '', 'service' => '' },
#        'EXTERNAL COMMAND'  # Looks like::
                #[1351881949] EXTERNAL COMMAND: SCHEDULE_FORCED_HOST_CHECK;web9;1351881947
                #[1351882302] EXTERNAL COMMAND: DISABLE_HOST_SVC_NOTIFICATIONS;web2
                #[1351882302] EXTERNAL COMMAND: DISABLE_HOST_NOTIFICATIONS;web2
                #[1351901138] EXTERNAL COMMAND: SCHEDULE_FORCED_HOST_SVC_CHECKS;queue12;1351901138
                #[1352230051] EXTERNAL COMMAND: ENABLE_HOST_AND_CHILD_NOTIFICATIONS;web2
                #[1352230112] EXTERNAL COMMAND: ENABLE_HOST_SVC_NOTIFICATIONS;web2
                #[1352230112] EXTERNAL COMMAND: ENABLE_HOST_NOTIFICATIONS;web2
    );
    
    push @info_bits, 'HOST' if $msg_type =~ /HOST/;    # push in HOST as 'service'
    my ($host,$state,$service) = ('','','');
    if ( grep $msg_type, keys %types ) {
        $host    = $info_bits[$types{$msg_type}{'host'}]     if defined $types{$msg_type};
        $state   = $info_bits[$types{$msg_type}{'state'}]    if defined $types{$msg_type};
        $service = $info_bits[$types{$msg_type}{'service'}]  if defined $types{$msg_type};
    }
    return ($host,$state,$service);
}

sub grab_seek_pos {
    my $file = shift;
    if ( ! -e $file ) {
        print "$file doesn't exist. Looks like this is our first run\n";
        set_seek_pos($file);
    }
    open ( my $SEEK, $seek_file );
    chomp( my @seek_pos = <$SEEK> );
    close $SEEK;
    return $seek_pos[0];
}

sub set_seek_pos {
    my ($file,$pos) = @_;
    $pos = 0 unless $pos;
    open (my $SEEK_FILE, ">$file");
    print $SEEK_FILE $pos;
    close $SEEK_FILE;
}

sub usage {
    print "\n$0 [options]\n";
    print "\t--noseek            Don't start from previous 'last' read position in log file (start from beginning)\n";
    print "\t                    and don't set 'new' seek position (ie. dry run)\n\n";
    print "\t--file  | -f        Log file to read. Defaults to /var/log/nagios3/nagios.log\n\n";
    print "\t--reset | -r        Reset starting 'read' position to 0 and save new 'last read' position of log file\n\n";
    print "\t--messages | -m     We're not printing extended Nagios message by default. Using this flag will output\n";
    print "\t                    the extended message(s)\n\n";
    print "\t--pretty | -p       Print the timestamp as a human-readable date/time\n\n";
    print "\t--help | -h         Print this help message\n\n";
    exit;
}