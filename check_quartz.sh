#!/bin/bash

# cmdline-jmxclient-0.10.3.jar available from - http://crawler.archive.org/cmdline-jmxclient/cmdline-jmxclient-0.10.3.jar
# List available objects by running /usr/bin/java -jar cmdline-jmxclient-0.10.3.jar - localhost:1099
# /usr/lib/nagios/plugins/check_quartz.sh -H localhost -P 1099 -O \
# quartz:instance=ip-10-0-12-2201364523129403,name=SpringScheduler,type=QuartzScheduler -A Started -R true

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4
# or source utils.sh ??

NAGIOS_PLUGINS='/usr/lib/nagios/plugins'

JMXHOST='localhost'
JMXPORT='1099'
JMXCREDS='-'

JMXCLIENT_VERSION='0.10.3'
JMXCLIENT="cmdline-jmxclient-${JMXCLIENT_VERSION}.jar"
JMXCLIENT_URL="http://crawler.archive.org/cmdline-jmxclient/$JMXCLIENT"
GREP='/bin/grep'
ECHO='/bin/echo'
JAVA=`which java`

if [ -z "$JAVA" ]
then
    if [ -x "$JAVA_HOME/bin/java" ]; then
        JAVA=$JAVA_HOME/bin/java
    else
        echo "JMX CRITICAL - java not found."
        exit $STATE_CRITICAL
    fi
fi

# Check for nagios plugins directory and jmxclient
if [ ! -d "$NAGIOS_PLUGINS" ]; then
    echo "JMX CRITICAL - $NAGIOS_PLUGINS not found (you may need to set NAGIOS_PLUGIN to appropriate value)"
    exit $STATE_CRITICAL
elif [ ! -e "$NAGIOS_PLUGINS/$JMXCLIENT" ]; then
    #cd $NAGIOS_PLUGINS
    #wget -q $JMXCLIENT_URL
    #curl -O $JMXCLIENT_URL
    #mv $JMXCLIENT $NAGIOS_PLUGINS/$JMXCLIENT
    echo; echo "You need to download the jmxclient from $JMXCLIENT_URL"
    echo "and put it in $NAGIOS_PLUGINS (or wherever your Nagios plugins are located, and "
    echo "set NAGIOS_PLUGINS in this script to that directory)"; echo
    exit $STATE_CRITICAL
fi

usage() {
    echo "Usage: ${0##*/} -O <object_name> -A <attribute_name> -R <expected value>"
    echo "    [-H <host>] [-P <port>] [-u <username>] [-p <password>]"
    exit $STATE_OK
}


while getopts "O:A:R:H:P:u:p:" optName; do
    case "$optName" in
        "O") JMXOBJECT="$OPTARG";;
        "A") JMXATTRIBUTE="$OPTARG";;
        "R") EXPECTRESULT="$OPTARG";;
        "H") JMXHOST="$OPTARG";;
        "P") JMXPORT="$OPTARG";;
        "u") JMXUSER="$OPTARG";;
        "p") JMXPASS="$OPTARG";;
        *) usage;;
    esac
done

[[ -z "$JMXOBJECT" ]] && usage
[[ -z "$JMXATTRIBUTE" ]] && usage
[[ -z "$EXPECTRESULT" ]] && usage
[[ "$JMXUSER" ]] && [[ "$JMXPASS" ]] && JMXCREDS="$JMXUSER:$JMXPASS"

URL="service:jmx:rmi:///jndi/rmi://${JMXHOST}:${JMXPORT}/jmxrmi"

CMD_TMPL="$JAVA -jar $JMXCLIENT $JMXCREDS $JMXHOST:$JMXPORT $JMXOBJECT $JMXATTRIBUTE"
RESULT=$($CMD_TMPL 2>&1 | $GREP $JMXATTRIBUTE)
RESULT=${RESULT##*${JMXATTRIBUTE}: }

if [ "$RESULT" = "$EXPECTRESULT" ]; then
    $ECHO "Results OK - '$JMXATTRIBUTE' is $RESULT; expected $EXPECTRESULT"
    exitstatus=$STATE_OK
else
    $ECHO "Results CRITICAL - '$JMXATTRIBUTE' is $RESULT; expected $EXPECTRESULT"
    exitstatus=$STATE_CRITICAL
fi

exit $exitstatus
