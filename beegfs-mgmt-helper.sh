#!/usr/bin/env bash

################################################################################
##                                                                            ##
##   BeeGFS Administrator's Helper                                            ##
##   Purpose: Easily manage and monitor the Famous BeeGFS (Parallel HPC FS)   ##
##   Writen by: Viktor Zhuromskyy < victor @ goldhub . ca                     ##
##   Inspired by BeeGFS: http://www.beegfs.com                                ##
##   Version: 1.0-r1         Released: 2016-11-29                             ##
##   Licenced under GPLv2                                                     ##
##                                                                            ##
##   Download: https://github.com/devdesco-ceo/beegfs-mgmt-helper             ##
##   Issues: https://github.com/devdesco-ceo/beegfs-mgmt-helper/issues        ##
##                                                                            ##
################################################################################

################################################################################
##                                                                            ##
##   Credits on code snippets:                                                ##
##   Coloring scheme - https://github.com/RootService/tuning-primer           ##
##                                                                            ##
################################################################################

################################################################################
##                                                                            ##
##    Usage: execute ./beegfs-mgmt-helper.sh and follow menu prompts          ##
##                                                                            ##
################################################################################

PATH=/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/bin

## Assign NodeID's and Mirror Group ID for META nodes
root_mount_point="/var/data/gfs"
meta_mirrorgroupid=1
meta_nodeids=( 1 2 )
storage_mirrorgroupids=( 1 2 3 )
storage_targetids=( 1101 2101 3101 4101 3201 4201 )


## -- DO NOT TOUCH ANYTHING BELLOW !!! ##

## Intercept Keyboard Input
trap '' SIGINT
trap ''  SIGQUIT
trap '' SIGTSTP

## Define Terminal Message colour
export black='\033[0m'
export boldblack='\033[1;0m'
export red='\033[31m'
export boldred='\033[1;31m'
export green='\033[32m'
export boldgreen='\033[1;32m'
export yellow='\033[33m'
export boldyellow='\033[1;33m'
export blue='\033[34m'
export boldblue='\033[1;34m'
export magenta='\033[35m'
export boldmagenta='\033[1;35m'
export cyan='\033[36m'
export boldcyan='\033[1;36m'
export white='\033[37m'
export boldwhite='\033[1;37m'

## Check for presence of all needed executables
#export gfsctl='beegfs-ctl'
#export gfsnet='beegfs-net'
#export gfscs='beegfs-check-servers'
#export gfsdf='beegfs-df'
#export gfsfsck='beegfs-fsck'

for bin in ioping fio awk bc ps du echo find grep ls wc netstat printf sleep sysctl tput uname beegfs-ctl; do
    which "$bin" > /dev/null
    if [ "$?" = "0" ] ; then
	bin_path="$(which $bin)"
	export bin_$bin="$bin_path"
    else
	echo "Error: Needed command \"$bin\" not found in PATH $PATH"
	exit 1
    fi
done

## Function to easliy print colored text
cecho () {
    local var1="$1" # message
    local var2="$2" # color

    local default_msg="No response reveived"

    message="${var1:-$default_msg}"
    color="${var2:-black}"

    case "$color" in
	black)
	    $bin_printf "$black" ;;
	boldblack)
	    $bin_printf "$boldblack" ;;
	red)
	    $bin_printf "$red" ;;
	boldred)
	    $bin_printf "$boldred" ;;
	green)
	    $bin_printf "$green" ;;
	boldgreen)
	    $bin_printf "$boldgreen" ;;
	yellow)
	    $bin_printf "$yellow" ;;
	boldyellow)
	    $bin_printf "$boldyellow" ;;
	blue)
	    $bin_printf "$blue" ;;
	boldblue)
	    $bin_printf "$boldblue" ;;
	magenta)
	    $bin_printf "$magenta" ;;
	boldmagenta)
	    $bin_printf "$boldmagenta" ;;
	cyan)
	    $bin_printf "$cyan" ;;
	boldcyan)
	    $bin_printf "$boldcyan" ;;
	white)
	    $bin_printf "$white" ;;
	boldwhite)
	    $bin_printf "$boldwhite" ;;
    esac

    $bin_printf "%s" "$message"
    $bin_tput sgr0
    $bin_printf "$black"

    return
}

cechon () {
    local var1="$1" # message
    local var2="$2" # color

    local default_msg="No response reveived"

    message="${var1:-$default_msg}"
    color="${var2:-black}"

    case "$color" in
	black)
	    $bin_printf "$black" ;;
	boldblack)
	    $bin_printf "$boldblack" ;;
	red)
	    $bin_printf "$red" ;;
	boldred)
	    $bin_printf "$boldred" ;;
	green)
	    $bin_printf "$green" ;;
	boldgreen)
	    $bin_printf "$boldgreen" ;;
	yellow)
	    $bin_printf "$yellow" ;;
	boldyellow)
	    $bin_printf "$boldyellow" ;;
	blue)
	    $bin_printf "$blue" ;;
	boldblue)
	    $bin_printf "$boldblue" ;;
	magenta)
	    $bin_printf "$magenta" ;;
	boldmagenta)
	    $bin_printf "$boldmagenta" ;;
	cyan)
	    $bin_printf "$cyan" ;;
	boldcyan)
	    $bin_printf "$boldcyan" ;;
	white)
	    $bin_printf "$white" ;;
	boldwhite)
	    $bin_printf "$boldwhite" ;;
    esac

    $bin_printf "%s\n" "$message"
    $bin_tput sgr0
    $bin_printf "$black"

    return

}
## Divide two intigers
divide () {
    local var1="$1"
    local var2="$2"
    local var3="$3"
    local var4="$4"

    usage="$0 dividend divisor '$variable' scale"

    if [ $((var1 >= 1)) -ne 0 ] ; then
	dividend="$var1"
    else
	cechon "Invalid Dividend" red
	cechon "$usage"
	exit 1
    fi

    if [ $((var2 >= 1)) -ne 0 ] ; then
	divisor="$var2"
    else
	cechon "Invalid Divisor" red
	cechon "$usage"
	exit 1
    fi

    if [ ! -n "$var3" ] ; then
	cechon "Invalid variable name" red
	cechon "$usage"
	exit 1
    fi

    if [ -z "$var4" ] ; then
	scale="2"
    elif [ $((var4 >= 0)) -ne 0 ] ; then
	scale="$var4"
    else
	cechon "Invalid scale" red
	cechon "$usage"
	exit 1
    fi

    export "$var3"="$($bin_echo "scale=$scale ; $dividend / $divisor" | $bin_bc -l)"
}

## Make sizes human readable
human_readable () {
    local var1="$1"
    local var2="$2"
    local var3="$3"

    scale="$var3"

    if [ $((var1 >= 1073741824)) -ne 0 ] ; then
	if [ -z "$var3" ] ; then
	    scale="2"
	fi
	divide "$var1" "1073741824" "$var2" "$scale"
	unit="G"
    elif [ $((var1 >= 1048576)) -ne 0 ] ; then
	if [ -z "$var3" ] ; then
	    scale="0"
	fi
	divide "$var1" "1048576" "$var2" "$scale"
	unit="M"
    elif [ $((var1 >= 1024)) -ne 0 ] ; then
	if [ -z "$var3" ] ; then
	    scale="0"
	fi
	divide "$var1" "1024" "$var2" "$scale"
	unit="K"
    else
	export "$var2"="$var1"
	unit="bytes"
    fi
}

## System Info
get_system_info () {
    export OS="$($bin_uname)"

    # Get information for various flavours of Linux
    if [ "$OS" = "Linux" ] ; then
	export memory="$($bin_awk '/^MemTotal/ { printf("%.0f", $2*1024) }' < /proc/meminfo)"
	export memory_free="$($bin_awk '/^MemFree/ { printf("%.0f", $2*1024) }' < /proc/meminfo)"
	export memory_available="$($bin_awk '/^MemAvailable/ { printf("%.0f", $2*1024) }' < /proc/meminfo)"
    fi
}

## Get status of BeeGFS processes
mgmtd_status () {
    service="beegfs-mgmtd"
    is_running=`ps aux | grep -v grep| grep -v "$service" | grep "beegfs"| wc -l | awk '{print $1}'`
    if [ $is_running != "0" ]
	then
	    cecho "$service " green
	fi
}
admon_status () {
    service="beegfs-admon"
    is_running=`ps aux | grep -v grep| grep -v "$service" | grep "beegfs"| wc -l | awk '{print $1}'`
    if [ $is_running != "0" ]
	then
	    cecho "$service " green
	fi
}
meta_status () {
    service="beegfs-meta"
    is_running=`ps aux | grep -v grep| grep -v "$service" | grep "beegfs"| wc -l | awk '{print $1}'`
    if [ $is_running != "0" ]
	then
	    cecho "$service " green
	fi
}
storage_status () {
    service="beegfs-storage"
    is_running=`ps aux | grep -v grep| grep -v "$service" | grep "beegfs"| wc -l | awk '{print $1}'`
    if [ $is_running != "0" ]
	then
	    cecho "$service " green
	fi
}
helperd_status () {
    service="beegfs-helperd"
    is_running=`ps aux | grep -v grep| grep -v "$service" | grep "beegfs"| wc -l | awk '{print $1}'`
    if [ $is_running != "0" ]
	then
	    cecho "$service " green
	fi
}

## Banner
banner () {
    cechon " " ; cechon " " ; cechon " "
    cechon "______________________________________________________" green ; cechon " "
    cechon "     BeeGFS Administrator's Helper (v. 1.0.0-r1)      " boldgreen
    cechon " " ; cechon " " ;

    get_system_info
    human_readable "$memory" memoryHR
    human_readable "$memory_free" memory_freeHR
    human_readable "$memory_available" memory_availableHR
    cecho "Memory: " ; cecho "$memoryHR $unit" green ; cecho " Installed / "
    cecho "$memory_freeHR $unit" green ; cecho " Free / "
    cecho "$memory_availableHR $unit" green ; cechon " Available (Free + Buffers + Cached)"

    cecho "Active local BeeGFS services: " ; mgmtd_status ; admon_status ; meta_status ; storage_status helperd_status
    cechon " "
    cechon "______________________________________________________" green ; cechon " "
}
 
## Display Menu and process command prompts
pause(){
    local m="$@"
    echo "$m"
    read -p "Press [ ENTER ] key to return to commands index ..." key
}
proper_action="Select proper action key"

while :
do
    clear
    banner ; cechon " " ; cechon " "
    cechon "         SELECT ONE OF THE ACTIONS AVAILABLE         " boldred ; cechon " "
    cecho "1. Show" ; cecho " Extended Status " red ; cechon "of META, STORAGE nodes"
    cecho "2. Show" ; cecho " Buddy / Mirror Groups " red ; cechon "for META, STORAGE nodes"
    cecho "3. Check" ; cecho " Connectivity / Reachability " red ; cechon "of META, STORAGE nodes and CLIENTS" ; cechon " "
    cecho "4. Fetch" ; cechon " Live IO Stats " red
    cechon "   Caution: Live IO Stats are CPU / RAM and DISK IO intensive" yellow ; cechon " "
    cecho "5. Check" ; cecho " RESYNC Status " red ; cechon "of META, STORAGE nodes"
    cecho "6. Perform" ; cechon " DIAGNOSTICS, CLEANUP and AUTO  REPAIR" red
    cecho "7. Run BeeGFS" ; cechon " PARALLEL FILE SYSTEM BENCHMARKS " red

    cechon "q. Exit"
    cechon "______________________________________________________"
    cecho  " " ; read -r -p "Enter your choice [1-7], or [q] to exit : " c
    # take action
    case $c in
	1)  clear
	    cechon " " ; cechon "Extended Status of META nodes" boldred
	    beegfs-ctl --listtargets --longnodes --state --pools --nodesfirst --spaceinfo --mirrorgroups --nodetype=meta
	    cechon " " ; cechon " " ; cechon "Extended status of STORAGE nodes" boldred
	    beegfs-ctl --listtargets --longnodes --state --pools --nodesfirst --spaceinfo --mirrorgroups --nodetype=storage
	    cechon " " ; pause;;
	2)  clear
	    cechon " " ; cechon "Buddy / Mirror Groups for META nodes" boldred
	    beegfs-ctl --listmirrorgroups --nodetype=meta
	    cechon " " ; cechon " " ; cechon "Buddy / Mirror Groups for STORAGE nodes" boldred
	    beegfs-ctl --listmirrorgroups --nodetype=storage
	    cechon " " ; pause;;
        3)  while :
                do
                    clear
                    banner ; cechon " " ; cechon " "
                    cechon "         SELECT ONE OF THE ACTIONS AVAILABLE         " boldred ; cechon " "
                    cecho "1. Check META nodes" ; cechon " Connectivity / Reachability " red
                    cecho "2. Check STORAGE nodes" ; cechon " Connectivity / Reachability " red
                    cecho "3. Check CLIENTS" ; cechon " Connectivity / Reachability " red
                    cechon "q. Return to Main Menu"
                    cechon "______________________________________________________"
                    cechon " " ; read -r -p "Enter your choice [1-3], or [q] to return to Main Menu: " cc
                    case $cc in
                        1)  clear
                            cechon " " ; cechon "Connectivity / Reachability of META nodes" boldred
                            beegfs-ctl --listnodes --nodetype=meta --nicdetails --route --reachable --showversion
                            cechon " " ; pause;;
                        2)  clear
                            cechon " " ; cechon "Connectivity / Reachability of STORAGE nodes" boldred
                            beegfs-ctl --listnodes --nodetype=storage --nicdetails --route --reachable --showversion
                            cechon " " ; pause;;
                        3)  clear
                            cechon " " ; cechon "Connectivity / Reachability of known CLIENTS" boldred
                            beegfs-ctl --listnodes --nodetype=CLIENT --nicdetails --route --reachable --showversion
                            cechon " " ; pause;;
                        q)  clear ; break;;
                        *)  pause "$proper_action"
                esac
            done;;
        4)  while :
                do
                    clear
                    banner ; cechon " " ; cechon " "
                    cechon "         Live IO Stats are CPU / RAM and DISK IO intensive!" boldred
                    cechon "         Continuous fetching of the IO Stats will negatively affect performance of BeeGFS..." boldred
                    cechon "         To stop Live IO Stats Stream, press any key to stop the madness!" boldred ; cechon " "
                    cechon "         SELECT ONE OF THE ACTIONS AVAILABLE         " boldred ; cechon " "

                    cecho "1. Fetch" ; cecho " Live IO Stats " red ; cechon "on META nodes"
                    cecho "2. Fetch" ; cecho " Live IO Stats " red ; cechon "on STORAGE nodes"
                    cecho "3. Fetch" ; cecho " Live IO Stats " red ; cechon "on META nodes for all connected CLIENT nodes accessing BeeGFS mounts"
                    cecho "4. Fetch" ; cecho " Live IO Stats " red ; cechon "on STORAGE nodes for all connected CLIENT nodes accessing BeeGFS mounts"
                    cecho "5. Fetch" ; cecho " Live IO Stats " red ; cechon "on META nodes for all SYSTEM USERS accessing BeeGFS mounts"
                    cecho "6. Fetch" ; cecho " Live IO Stats " red ; cechon "on STORAGE nodes for all SYSTEM USERS accessing BeeGFS mounts"
                    cechon "q. Return to Main Menu"
                    cechon "______________________________________________________"
                    cechon " " ; read -r -p "Enter your choice [1-6], or [q] to return to Main Menu: " cc
                    case $cc in
                        1)  clear
                            cechon " " ; cechon "Live IO Stats for META nodes (last 60 seconds, updated every 10 seconds)" boldred
                            cechon "Press any key to stop the Live output stream" boldred
                            beegfs-ctl --serverstats --perserver --names --nodetype=metadata --history=60 --interval=10
                            cechon " " ; pause;;
                        2)  clear
                            cechon " " ; cechon "Live IO Stats for STORAGE nodes (last 60 seconds, updated every 10 seconds)" boldred
                            cechon "Press any key to stop the Live output stream" boldred
                            beegfs-ctl --serverstats --perserver --names --nodetype=storage --history=60 --interval=10
                            cechon " " ; pause;;
                        3)  clear
                            cechon " " ; cechon "Live IO Stats on META nodes for all connected CLIENT nodes accessing BeeGFS mounts (last 60 seconds, updated every 10 seconds)" boldred
                            cechon "Press any key to stop the Live output stream" boldred
                            beegfs-ctl --clientstats --names --nodetype=meta --interval=10 --perinterval=60
                            cechon " " ; pause;;
                        4)  clear
                            cechon " " ; cechon "Live IO Stats on STORAGE nodes for all connected CLIENT nodes accessing BeeGFS mounts (last 60 seconds, updated every 10 seconds)" boldred
                            cechon "Press any key to stop the Live output stream" boldred
                            beegfs-ctl --clientstats --names --nodetype=storage --interval=10 --perinterval=60
                            cechon " " ; pause;;
                        5)  clear
                            cechon " " ; cechon "Live IO Stats on META nodes for all SYSTEM USERS accessing BeeGFS mounts (last 60 seconds, updated every 10 seconds)" boldred
                            cechon "Press any key to stop the Live output stream" boldred
                            beegfs-ctl --userstats --names --nodetype=meta --interval=10 --perinterval=60
                            cechon " " ; pause;;
                        6)  clear
                            cechon " " ; cechon "Live IO Stats on STORAGE nodes for all SYSTEM USERS accessing BeeGFS mounts (last 60 seconds, updated every 10 seconds)" boldred
                            cechon "Press any key to stop the Live output stream" boldred
                            beegfs-ctl --userstats --names --nodetype=storage --interval=10 --perinterval=60
                            cechon " " ; pause;;
                        q)  clear ; break;;
                        *)  pause "$proper_action"
                esac
            done;;
        5)  while :
                do
                    clear
                    banner ; cechon " " ; cechon " "
                    cechon "         SELECT ONE OF THE ACTIONS AVAILABLE         " boldred ; cechon " "
                    cecho "1." ; cecho " RESYNC Status " red ; cechon "of META nodes"
                    cecho "2." ; cecho " RESYNC Status " red ; cechon "of STORAGE nodes"
                    cechon "q. Return to Main Menu"
                    cechon "______________________________________________________"
                    cechon " " ; read -r -p "Enter your choice [1-3], or [q] to return to Main Menu: " cc
                    case $cc in
                        1)  clear
                            cechon " " ; cechon "RESYNC Status of META Mirror Group ID #$meta_mirrorgroupid" boldred
                            beegfs-ctl --resyncstats --nodetype=metadata --mirrorgroupid=$meta_mirrorgroupid
                            for i in "${meta_nodeids[@]}"
                                do
                                    cechon " " ; cechon "RESYNC Status of META Node ID #$i" boldred
                                    beegfs-ctl --resyncstats --nodetype=metadata --target=$i --mirrorgroupid=$meta_mirrorgroupid
                                done
                            cechon " " ; pause;;
                        2)  clear
                            for i in "${storage_mirrorgroupids[@]}"
                                do
                                    cechon " " ; cechon "RESYNC Status of STORAGE Mirror Group ID #$i" boldred
                                    beegfs-ctl --resyncstats --nodetype=metadata --target=$i --mirrorgroupid=$meta_mirrorgroupid
                                done
                            for i in "${storage_targetids[@]}"
                                do
                                    cechon " " ; cechon "RESYNC Status of STORAGE Target ID #$i" boldred
                                    beegfs-ctl --resyncstats --nodetype=metadata --target=$i --mirrorgroupid=$meta_mirrorgroupid
                                done
                            cechon " " ; pause;;
                        q)  clear ; break;;
                        *)  pause "$proper_action"
                esac
            done;;
        6)  while :
                do
                    clear
                    banner ; cechon " " ; cechon " "
                    cechon "         SELECT ONE OF THE ACTIONS AVAILABLE         " boldred ; cechon " "
                    cecho "1." ; cechon " Look for Unused Inodes and Dispose the Orphants" red
                    cecho "2." ; cechon " Check for Errors in BeeGFS File System without any Repair Attempts" red
                    cecho "3." ; cechon " Check for Errors in BeeGFS File System, and attempt Automatic Repairs (online)" red ; cechon " "
                    cecho "4." ; cechon " Check for Errors in BeeGFS File System, and attempt Automatic Repairs (offline)" red
                    cechon "   Caution: The repairs to be run in offline mode, which disables the " yellow
                    cechon "   modification logging, (otherwise false errors might be reported)." yellow
                    cechon "   Use this only if you are sure there is no user access to the file" yellow
                    cechon "   system while the check is running." yellow ; cechon " "
                    cechon "q. Return to Main Menu"
                    cechon "______________________________________________________"
                    cechon " " ; read -r -p "Enter your choice [1-3], or [q] to return to Main Menu: " cc
                    case $cc in
                        1)  clear
                            cechon " " ; cechon "Find and Dispose Unused / Orphant Inodes" boldred
                            beegfs-ctl  --disposeunused --printstats --printnodes --dispose
                            cechon " " ; pause;;
                        2)  clear
                            cechon " " ; cechon "Check for Errors in BeeGFS File System without any Repair Attempts" boldred
                            beegfs-fsck --checkfs --overwriteDbFile --readOnly
                            cechon " " ; pause;;
                        3)  clear
                            cechon " " ; cechon "Check for Errors in BeeGFS File System and Automatic Repairs (online)" boldred
                            beegfs-fsck --checkfs --overwriteDbFile --automatic
                            cechon " " ; pause;;
                        4)  clear
                            cechon " " ; cechon "Check for Errors in BeeGFS File System and Automatic Repairs (offline)" boldred
                            beegfs-fsck --checkfs --overwriteDbFile --runoffline --automatic
                            cechon " " ; pause;;
                        q)  clear ; break;;
                        *)  pause "$proper_action"
                esac
            done;;
        7)  while :
                do
                    clear
                    banner ; cechon " " ; cechon " "
                    cechon "         SELECT ONE OF THE ACTIONS AVAILABLE         " boldred ; cechon " "
                    cecho "1." ; cecho " STEP 1.1: Launch BeeGFS filesystem Benchmark on" green ; cecho " WRITE " red ; cechon "operations" green ; cechon " "
                    cecho "2." ; cecho " STEP 1.2: Launch BeeGFS filesystem Benchmark on" green ; cecho " READ " red ; cechon "operations" green
                    cechon "   Notice: READ Benchmark requires you to run WRITE Benchmark in the first place." yellow
                    cechon "   You also must ensure the WRITE Benchmark is completely finished. It is easy to check" yellow
                    cechon "   completion of your Benchmark by executing STEP 2 of the Benchmarking Menu Section." yellow
                    cechon "   After all the WRITE benchmarks are reported to be finished, collect your WRITE" yellow
                    cechon "   Benchmark Results, executing STEP 2, and then proceed to READ Benchmark." yellow ; cechon " "
                    cecho "3." ; cecho " STEP 2: Monitor and collect WRITE / READ Benchmark" green ; cechon " RESULTS " red ; cechon " "
                    cecho "4." ; cechon " Cleanup the BeegFS File System" red
                    cechon "   After all the WRITE / READ Benchmarks are complete, and Results / Statistics are collected," yellow
                    cechon "   you are urged to free up disk space by running the Automatic CLEANUP of BeeGFS File System," yellow
                    cechon "   in order to get rid of multi-gigabyte files created in each Storage Tagret." yellow ; cechon " "
                    cechon "q. Return to Main Menu"
                    cechon "______________________________________________________"
                    cechon " " ; read -r -p "Enter your choice [1-3], or [q] to return to Main Menu: " cc
                    case $cc in
                        1)  clear
                            cechon " " ; cechon "STEP 1.1: Launching BeeGFS filesystem Benchmark on ALL STORAGE TARGETS for WRITE operations with blocksize=64K, file space of 10GB, and 12 CPU threads" boldred
                            beegfs-ctl --storagebench --alltargets --write --blocksize=64K --size=10G --threads=12
                            cechon " " ; pause;;
                        2)  clear
                            cechon " " ; cechon "STEP 1.1: Launching BeeGFS filesystem Benchmark on ALL STORAGE TARGETS for READ operations with blocksize=64K, file space of 10GB, and 12 CPU threads" boldred
                            beegfs-ctl --storagebench --alltargets --read --blocksize=64K --size=10G --threads=12
                            cechon " " ; pause;;
                        3)  clear
                            cechon " " ; cechon "Collecting WRITE / READ Benchmark Results" boldred
                            beegfs-ctl --storagebench --status --alltargets --verbose
                            cechon " " ; pause;;
                        4)  clear
                            cechon " " ; cechon "Cleaning up the BeegFS File System for freeing up space after performed Benchmarks" boldred
                            beegfs-ctl --storagebench --cleanup --alltargets
                            cechon " " ; pause;;
                        q)  clear ; break;;
                        *)  pause "$proper_action"
                esac
            done;;
	q)  clear ; break;;
	*) pause "$proper_action"
    esac
done
