#! /bin/bash
#
# Script to check Internet connection speed using speedtest
#
# The old speedtest-cli doesn't work anymore as Ookla decommitionned php webpages
# containing speedtest servers list previously used by speedtest-cli.
# This new plugin use now the new speedtest cli provided by Ookla https://www.speedtest.net/apps/cli
#
#	Based on old check_speedtest-cli.sh by John Witts
#	https://github.com/jonwitts/nagios-speedtest
#
# TheITguy21 - https://github.com/TheITguy21/check_speedtest.sh
#
#########################################################################################################################################################
#
# Nagios Exit Codes
#
# 0	=	OK		= The plugin was able to check the service and it appeared to be functioning properly
# 1	=	Warning		= The plugin was able to check the service, but it appeared to be above some warning
#				threshold or did not appear to be working properly
# 2	=	Critical	= The plugin detected that either the service was not running or it was above some critical threshold
# 3	=	Unknown		= Invalid command line arguments were supplied to the plugin or low-level failures internal
#				to the plugin (such as unable to fork, or open a tcp socket) that prevent it from performing the specified operation.
#				Higher-level errors (such as name resolution errors, socket timeouts, etc) are outside of the control of plugins
#				and should generally NOT be reported as UNKNOWN states.
#
########################################################################################################################################################

plugin_name="Nagios speedtest.sh plugin"
version="1.0 2023031814:30"

#####################################################################
#
#	CHANGELOG
#
#	Version 1.0 - Initial Release
#		New updated plugin based on old check_speedtest-cli.sh by John Witts
#		https://github.com/jonwitts/nagios-speedtest
#
#####################################################################
# function to output script usage
usage()
{
	cat << EOF
	******************************************************************************************

	$plugin_name - Version: $version

	OPTIONS:
	-h	Show this message
	-w	Download Warning Level - *Required* - integer or floating point
	-c	Download Critical Level - *Required* - integer or floating point
	-W	Upload Warning Level - *Required* - integer or floating point
	-C	Upload Critical Level - *Required* - integer or floating point
	Server: Use specific target server (optional)
		Run "speedtest --servers" to list your nearest servers
	    -s	Use a specific Server ID integer to use speedtest test against
	    -o	Use a specific Server FQDN to use speedtest test against
	
	-p	Output Performance Data
        -m      Download Maximum Level - *Required if you request perfdata* - integer or floating point
                Provide the maximum possible download level in Mbit/s for your connection
        -M      Upload Maximum Level - *Required if you request perfdata* - integer or floating point
                Provide the maximum possible upload level in Mbit/s for your connection
	-v	Output plugin version
	-V	Output debug info for testing

	This script will output the Internet Connection Speed using speedtest to Nagios.

	You need to have installed speedtest on your system first and ensured that it is
	working by calling "speedtest".

	See here: https://www.speedtest.net/apps/cli for info about speedtest cli

	The speedtest can take some time to return its result. I recommend that you set the
	service_check_timeout value in your main nagios.cfg to 120 to allow time for
	this script to run; but test yourself and adjust accordingly.

	You also need to have access to "bc" package on your system for this script to work and that it
	exists in your path.

	Your warning levels must be higher than your critical levels for both upload and download.

	Performance Data will output upload and download speed against matching warning and
	critical levels.

	Jon Witts & TheITguy21

	******************************************************************************************
EOF
}

#####################################################################
# function to output error if speedtest binary location not found
locundef()
{
	cat << EOF
	******************************************************************************************

	$plugin_name - Version: $version

	Could not find path to SpeedTest binary. Is speedtest package correctly installed?
	Go to https://www.speedtest.net/apps/cli to install package

	******************************************************************************************
EOF
}

#####################################################################
# function to check if a variable is numeric
# expects variable to check as first argument
# and human description of variable as second
isnumeric()
{
	re='^[0-9]+([.][0-9]+)?$'
	if ! [[ $1 =~ $re ]]; then
		echo $2" with a value of: "$1" is not a number!"
		usage
		exit 3
	fi
}

#####################################################################
# functions for floating point operations - requires bc!

#####################################################################
# Default scale used by float functions.

float_scale=3

#####################################################################
# Evaluate a floating point number expression.

function float_eval()
{
    local stat=0
    local result=0.0
    if [[ $# -gt 0 ]]; then
	result=$(echo "scale=$float_scale; $*" | bc -q 2>/dev/null)
	stat=$?
	if [[ $stat -eq 0  &&  -z "$result" ]]; then stat=1; fi
    fi
    echo $result
    return $stat
}

#####################################################################
# Evaluate a floating point number conditional expression.

function float_cond()
{
    local cond=0
    if [[ $# -gt 0 ]]; then
	cond=$(echo "$*" | bc -q 2>/dev/null)
	if [[ -z "$cond" ]]; then cond=0; fi
	if [[ "$cond" != 0  &&	"$cond" != 1 ]]; then cond=0; fi
    fi
    local stat=$((cond == 0))
    return $stat
}

########### End of functions ########################################


#####################################################################
# Check prerequisites.
#
# Get speedtest binaty path
STb="$(which speedtest)"
if [[ -z $STb ]]
then
	locundef
	exit 3
fi
# echo speedtest binary path for debug
if [ "$debug" == "TRUE" ]; then
	echo "SpeedTest binary path: $STb"
fi
#
# Check if binary bc is installed
type bc >/dev/null 2>&1 || { echo >&2 "Error: bc binary missing. Please install package 'bc' (in order to do floating point operations)"; exit 3; }
#####################################################################


# Set up the variables to take the arguments
DLw=
DLc=
ULw=
ULc=
serverID=
host=
PerfData=
MaxDL=
MaxUL=
debug=

# Retrieve the arguments using getopts
while getopts "hw:c:W:C:s:o:pm:M:vV" OPTION
do
	case $OPTION in
	h)
		usage
		exit 3
		;;
	w)
		DLw=$OPTARG
		;;
	c)
		DLc=$OPTARG
		;;
	W)
		ULw=$OPTARG
		;;
	C)
		ULc=$OPTARG
		;;
	s)
		serverID=$OPTARG
		;;
	o)
		host=$OPTARG
		;;
	p)
		PerfData="TRUE"
		;;
        m)
                MaxDL=$OPTARG
                ;;
        M)
                MaxUL=$OPTARG
                ;;
	v)
		echo "$plugin_name. Version number: $version"
		exit 3
		;;
	V)
		debug="TRUE"
		;;
esac
done

# Check for empty arguments and exit to usage if found
if  [[ -z $DLw ]] || [[ -z $DLc ]] || [[ -z $ULw ]] || [[ -z $ULc ]]
then
	echo "Invalid arguments!"
	usage
	exit 3
fi

# Check for empty upload and download maximum arguments if perfdata has been requested
if [ "$PerfData" == "TRUE" ]; then
        if [[ -z $MaxDL ]] || [[ -z $MaxUL ]]
	then
		usage
		exit 3
        fi
fi

# Check for non-numeric arguments
isnumeric $DLw "Download Warning Level"
isnumeric $DLc "Download Critical Level"
isnumeric $ULw "Upload Warning Level"
isnumeric $ULc "Upload Critical Level"
# Only check upload and download maximums if perfdata requested
if [ "$PerfData" == "TRUE" ]; then
	isnumeric $MaxDL "Download Maximum Level"
	isnumeric $MaxUL "Upload Maximum Level"
fi

# Check that warning levels are not less than critical levels
if float_cond "$DLw < $DLc"; then
	echo "\$DLw is less than \$DLc!"
	usage
	exit 3
elif float_cond "$ULw < $ULc"; then
	echo "\$ULw is less than \$ULc!"
	usage
	exit 3
fi

# Check if not both server ID and server FQDN have been specified
if [ $serverID ] && [ $host ]; then
	echo "You cannot specify both server ID and server FQDN!"
	usage
	exit 3
fi

# Output arguments for debug
if [ "$debug" == "TRUE" ]; then
	echo "Download Warning Level = "$DLw
	echo "Download Critical Level = "$DLc
	echo "Upload Warning Level = "$ULw
	echo "Upload Critical Level = "$ULc
	if [ -z $serverID ] && [ -z $host ]; then
		echo "No specific target server defined"
	elif [ $serverID ]; then
		echo "Server ID = "$serverID
	elif [ $host ]; then
		echo "Server FQDN = "$host
	fi
fi



#Set and run command depending upon arguments
if [ $serverID ]; then
	if [ "$debug" == "TRUE" ]; then
		echo "Target server ID defined to '$serverID'"
	fi
	command=$($STb --simple --server-id=$serverID)
elif [ $host ]; then
	if [ "$debug" == "TRUE" ]; then
		echo "Target server FQDN defined to '$host'"
	fi
	command=$($STb --simple --host=$host)
else
	command=$($STb --simple)
fi


# Check if $command returned valid output
if [ -z "$(echo "$command" | grep -o 'Speedtest by Ookla')" ]; then
	echo "$command"
#	echo "You do not have the expected output from SpeedTest. Is it correctly installed? Try running the check with the -V argument to see what is going wrong."
#	usage
	exit 3
fi

# echo contents of speedtest for debug
if [ "$debug" == "TRUE" ]; then
	echo "Command output:"
	echo "$command"
fi

# Extract/parse values from output
ping="$(echo "$command" | sed -nr '/Latency/{s/^.+: +([0-9\.]+) (.+) +\(.+$/\1/;p}')"
pingUOM="$(echo "$command" | sed -nr '/Latency/{s/^.+: +([0-9\.]+) (.+) +\(.+$/\2/;p}')"
download="$(echo "$command" | sed -nr '/Download/{s/^.+: +([0-9\.]+) (.+) +\(.+$/\1/;p}')"
downloadUOM="$(echo "$command" | sed -nr '/Download/{s/^.+: +([0-9\.]+) (.+) +\(.+$/\2/;p}')"
upload="$(echo "$command" | sed -nr '/Upload/{s/^.+: +([0-9\.]+) (.+) +\(.+$/\1/;p}')"
uploadUOM="$(echo "$command" | sed -nr '/Upload/{s/^.+: +([0-9\.]+) (.+) +\(.+$/\2/;p}')"

# echo each parsed returned values for debug
if [ "$debug" == "TRUE" ]; then
	echo "Extracted values:"
	echo "Ping = "$ping
	echo "Download = "$download
	echo "Upload = "$upload
fi

#set up our nagios status and exit code variables
status=
nagcode=

# now we check to see if returned values are within defined ranges
# we will make use of bc for our math!
if float_cond "$download < $DLc"; then
	if [ "$debug" == "TRUE" ]; then
		echo "Download less than critical limit. \$download = $download and \$DLc = $DLc "
	fi
	status="CRITICAL"
	nagcode=2
elif float_cond "$upload < $ULc"; then
	if [ "$debug" == "TRUE" ]; then
		echo "Upload less than critical limit. \$upload = $upload and \$ULc = $ULc"
	fi
	status="CRITICAL"
	nagcode=2
elif float_cond "$download < $DLw"; then
	if [ "$debug" == "TRUE" ]; then
		echo "Download less than warning limit. \$download = $download and \$DLw = $DLw"
	fi
	status="WARNING"
	nagcode=1
elif float_cond "$upload < $ULw"; then
	if [ "$debug" == "TRUE" ]; then
		echo "Upload less than warning limit. \$upload = $upload and \$ULw = $ULw"
	fi
	status="WARNING"
	nagcode=1
else
	if [ "$debug" == "TRUE" ]; then
		echo "Everything within bounds!"
	fi
	status="OK"
	nagcode=0
fi

nagout="$status - Ping = $ping $pingUOM Download = $download $downloadUOM Upload = $upload $uploadUOM"

# append perfout if argument was passed to script
if [ "$PerfData" == "TRUE" ]; then
	if [ "$debug" == "TRUE" ]; then
		echo "PerfData requested!"
	fi
	#perfout="|'download'=$download;$DLw;$DLc;0;$(echo $MaxDL*1.05|bc) 'upload'=$upload;$ULw;$ULc;0;$(echo $MaxUL*1.05|bc)"
	perfout="|'latency'=$ping 'download'=$download;$DLw;$DLc;0;$(echo $MaxDL*1.05|bc) 'upload'=$upload;$ULw;$ULc;0;$(echo $MaxUL*1.05|bc)"
	nagout=$nagout$perfout
fi

echo $nagout
exit $nagcode
