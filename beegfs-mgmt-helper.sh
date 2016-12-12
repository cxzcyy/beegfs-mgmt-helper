#!/usr/bin/env bash

################################################################################
##                                                                            ##
##   BeeGFS Administrator's Helper                                            ##
##   Purpose: Easily manage and monitor the Famous BeeGFS (Parallel HPC FS)   ##
##   Writen by: Viktor Zhuromskyy < victor @ goldhub . ca                     ##
##   Inspired by BeeGFS: http://www.beegfs.com                                ##
##   Version: 1.0.0-rc5       Released: 2016-12-12                            ##
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


#### EDIT VARIABLES BELLOW, TO FIT YOUR ENVIRONMENT ####

## Assign Node / Target ID's and Mirror Group ID for your META and STORAGE nodes
meta_nodeids=( 1 2 )        # Array of Metadata NodeID's
meta_mirrorgroupid=1        # Metadata Mirror Buddy Group ID
storage_targetids=( 1101 2101 3101 4101 3102 4102 ) # Array of Storage Target ID's
storage_mirrorgroupids=( 1 2 4 ) # Array of Storage Mirror Buddy Group ID

## BeeGFS' Mount Points
beegfs_mount=/var/data/gfs  # Mount point from your /etc/beegfs/beegfs-mounts.conf
fio_bench_point=/www        # set the variable to an existing path inside the mounted
                            # beegfs_mount location you want to run FIO benchmarks on
beegfs_storage_base=/var/data/beegfs_fio_test     # set the variable to the mount point of your storage target data location on this local machine
                                                  # if you want to run FIO benchmarks on the machine's file system for doing comparison of NAS vs LOCAL
                                                  # In order to simplify the benchmarking process, I suggest symlinking your /dev/sdXX mounts to something
                                                  # like /var/data/sdX_fio_test


## BeeGFS' IOPS Benchmark variables
beegfs_bench_blocksize=32K # I set it to be half of the minimal possible BeeGFS chunk size
beegfs_bench_size=8G       # set your test file size in multiple of BeeGFS chunk size
beegfs_bench_threads=6     # number of workers

## FIO IOPS Benchmark variables
bench_res_dir=bench_results # crete named directory in the same location where the beegfs-mgmt-helper.sh is being executed at,
                            # and save benchmarking results of FIO and IOPING
fio_blocksize=64k           # default: 4k, but you can set it to be, let's say, half of the minimal possible BeeGFS chunk size of 64K
                            # make sure your block size can divide fio_size evenly
fio_ioengine=libaio         # libaio Linux native asynchronous I/O. This ioengine defines engine specific options.
fio_runtime=120             # maximum time for running a given test
fio_rwmixread=75            # for random direct read / write - 75%/25% ratio
fio_iodepth=8               # default: 1.  Number of I/O units to keep in flight against created file.
fio_size=4M                 # set your test file size to be double of average file size in BeeGFS storage, and be dividable by 4K (system block size)
                            # Use this command to find out: find ./ -size -100000c -ls | awk '{sum += $7; n++;} END {print sum/n;}'
fio_numjobs=12              # number of parallel benchmarks. Start slow with "fio_numjobs=2" and watch "util="
                            # in benchmark results, as well a actual RAM, CPU and Disk utilization in order
                            # not to hang/kill/freeze/swap your testing system! It is better to raise "fio_size"
                            # than to kill your machines with "fio_numjobs >=2"

## IOPING IOPS Benchmark related variables
ioping_maxiops=1000000      # max number of iops to schedule
ioping_time_period=5        # report raw tatistics every x seconds
ioping_interval=0           # set 0 for IOPS benchmarking. Default: 1 second


#### -- DO NOT TOUCH ANYTHING BELLOW !!! ####
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/bin

release="v. 1.0.0-rc5"
dt=$(date '+%Y-%m-%d.%H:%M')
uid=$(cat /proc/sys/kernel/random/uuid)


fio_netdev=$beegfs_mount$fio_bench_point
fio_block_dev=$fio_netdev/fio_bench_$uid.dat
fio_rwmixwrite=$((100 - $fio_rwmixread))
PWD_BR=$PWD/$bench_res_dir


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
for bin in awk bc ps du echo find grep ls wc netstat printf sleep sysctl tput uname tee fio ioping beegfs-ctl; do
    which "$bin" > /dev/null
    if [ "$?" = "0" ] ; then
	bin_path="$(which $bin)"
	export bin_$bin="$bin_path"
    else
	echo "Error: Needed command \"$bin\" not found in PATH $PATH"

	# install dependencies
	#sudo apt-get -y update
	#sudo apt-get install -y fio ioping

	exit 1
    fi
done

## Function to easliy print colored text
cecho () {
    local var1="$1" # message
    local var2="$2" # color

    local default_msg="NULL"

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

    local default_msg="NULL"

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
	unit="GB"
    elif [ $((var1 >= 1048576)) -ne 0 ] ; then
	if [ -z "$var3" ] ; then
	    scale="0"
	fi
	divide "$var1" "1048576" "$var2" "$scale"
	unit="MB"
    elif [ $((var1 >= 1024)) -ne 0 ] ; then
	if [ -z "$var3" ] ; then
	    scale="0"
	fi
	divide "$var1" "1024" "$var2" "$scale"
	unit="KB"
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
    cpu_limit="5000" # limit in xx%*100
    ram_limit_mb="4096" # limit in xx MB
    is_running=`ps aux | grep -v grep| grep "beegfs" | grep "$service"| wc -l | awk '{print $1}'`
    app_pid=`ps aux | grep $service | grep -v grep | awk {'print $2'}`
    app_cpu=`ps aux | grep $service | grep -v grep | awk {'print $3*100'}`
    if [ $is_running != "0" ]
        then
            for p in $(pgrep $service); do ram_used=$(($total + $(awk '/VmSize/ { print $2 }' /proc/$p/status))); done
            ram_used_mb=$(($ram_used / 1024))
            if [[ $ram_used_mb -gt $ram_limit_mb ]]; then rcolor="red" ; else rcolor="green" ; fi
            if [[ $app_cpu -gt $cpu_limit ]]; then ccolor="red" ; else ccolor="green" ; fi
            cpu_used=$(($app_cpu / 100))
            human_readable "$(($ram_used * 1024 ))" memoryHR
            cecho "$service" green ; printf '\t' ; cecho "  RAM: " ; cecho "$memoryHR" $rcolor ; cecho " $unit" $rcolor ; printf '\t' ; cecho " CPU: " ; cecho "$cpu_used" $ccolor ; cecho "% " $ccolor; printf '\t' ; cecho "PID: $app_pid" ; cechon " " ; printf '\t\t'
            unset ram_used ; unset app_cpu ; unset app_pid
        fi
}
admon_status () {
    service="beegfs-admon"
    cpu_limit="5000" # limit in xx%*100
    ram_limit_mb="2048" # limit in xx MB
    is_running=`ps aux | grep -v grep| grep "beegfs" | grep "$service"| wc -l | awk '{print $1}'`
    app_pid=`ps aux | grep $service | grep -v grep | awk {'print $2'}`
    app_cpu=`ps aux | grep $service | grep -v grep | awk {'print $3*100'}`
    if [ $is_running != "0" ]
        then
            for p in $(pgrep $service); do ram_used=$(($total + $(awk '/VmSize/ { print $2 }' /proc/$p/status))); done
            ram_used_mb=$(($ram_used / 1024))
            if [[ $ram_used_mb -gt $ram_limit_mb ]]; then rcolor="red" ; else rcolor="green" ; fi
            if [[ $app_cpu -gt $cpu_limit ]]; then ccolor="red" ; else ccolor="green" ; fi
            cpu_used=$(($app_cpu / 100))
            human_readable "$(($ram_used * 1024 ))" memoryHR
            cecho "$service" green ; printf '\t' ; cecho "  RAM: " ; cecho "$memoryHR" $rcolor ; cecho " $unit" $rcolor ; printf '\t' ; cecho " CPU: " ; cecho "$cpu_used" $ccolor ; cecho "% " $ccolor; printf '\t' ; cecho "PID: $app_pid" ; cechon " " ; printf '\t\t'
            unset ram_used ; unset app_cpu ; unset app_pid
        fi
}
meta_status () {
    service="beegfs-meta"
    cpu_limit="5000" # limit in xx%*100
    ram_limit_mb="6144" # limit in xx MB
    is_running=`ps aux | grep -v grep| grep "beegfs" | grep "$service"| wc -l | awk '{print $1}'`
    app_pid=`ps aux | grep $service | grep -v grep | awk {'print $2'}`
    app_cpu=`ps aux | grep $service | grep -v grep | awk {'print $3*100'}`
    if [ $is_running != "0" ]
        then
            for p in $(pgrep $service); do ram_used=$(($total + $(awk '/VmSize/ { print $2 }' /proc/$p/status))); done
            ram_used_mb=$(($ram_used / 1024))
            if [[ $ram_used_mb -gt $ram_limit_mb ]]; then rcolor="red" ; else rcolor="green" ; fi
            if [[ $app_cpu -gt $cpu_limit ]]; then ccolor="red" ; else ccolor="green" ; fi
            cpu_used=$(($app_cpu / 100))
            human_readable "$(($ram_used * 1024 ))" memoryHR
            cecho "$service" green ; printf '\t' ; cecho "  RAM: " ; cecho "$memoryHR" $rcolor ; cecho " $unit" $rcolor ; printf '\t' ; cecho " CPU: " ; cecho "$cpu_used" $ccolor ; cecho "% " $ccolor; printf '\t' ; cecho "PID: $app_pid" ; cechon " " ; printf '\t\t'
            unset ram_used ; unset app_cpu ; unset app_pid
        fi
}
storage_status () {
    service="beegfs-storage"
    cpu_limit="5000" # limit in xx%*100
    ram_limit_mb="4096" # limit in xx MB
    is_running=`ps aux | grep -v grep| grep "beegfs" | grep "$service"| wc -l | awk '{print $1}'`
    app_pid=`ps aux | grep $service | grep -v grep | awk {'print $2'}`
    app_cpu=`ps aux | grep $service | grep -v grep | awk {'print $3*100'}`
    if [ $is_running != "0" ]
        then
            for p in $(pgrep $service); do ram_used=$(($total + $(awk '/VmSize/ { print $2 }' /proc/$p/status))); done
            ram_used_mb=$(($ram_used / 1024))
            if [[ $ram_used_mb -gt $ram_limit_mb ]]; then rcolor="red" ; else rcolor="green" ; fi
            if [[ $app_cpu -gt $cpu_limit ]]; then ccolor="red" ; else ccolor="green" ; fi
            cpu_used=$(($app_cpu / 100))
            human_readable "$(($ram_used * 1024 ))" memoryHR
            cecho "$service" green ; printf '\t' ; cecho "  RAM: " ; cecho "$memoryHR" $rcolor ; cecho " $unit" $rcolor ; printf '\t' ; cecho " CPU: " ; cecho "$cpu_used" $ccolor ; cecho "% " $ccolor; printf '\t' ; cecho "PID: $app_pid" ; cechon " " ; printf '\t\t'
            unset ram_used ; unset app_cpu ; unset app_pid
        fi
}
helperd_status () {
    service="beegfs-helperd"
    cpu_limit="5000" # limit in xx%*100
    ram_limit_mb="2048" # limit in xx MB
    is_running=`ps aux | grep -v grep| grep "beegfs" | grep "$service"| wc -l | awk '{print $1}'`
    app_pid=`ps aux | grep $service | grep -v grep | awk {'print $2'}`
    app_cpu=`ps aux | grep $service | grep -v grep | awk {'print $3*100'}`
    if [ $is_running != "0" ]
        then
            for p in $(pgrep $service); do ram_used=$(($total + $(awk '/VmSize/ { print $2 }' /proc/$p/status))); done
            ram_used_mb=$(($ram_used / 1024))
            if [[ $ram_used_mb -gt $ram_limit_mb ]]; then rcolor="red" ; else rcolor="green" ; fi
            if [[ $app_cpu -gt $cpu_limit ]]; then ccolor="red" ; else ccolor="green" ; fi
            cpu_used=$(($app_cpu / 100))
            human_readable "$(($ram_used * 1024 ))" memoryHR
            cecho "$service" green ; printf '\t' ; cecho "  RAM: " ; cecho "$memoryHR" $rcolor ; cecho " $unit" $rcolor ; printf '\t' ; cecho " CPU: " ; cecho "$cpu_used" $ccolor ; cecho "% " $ccolor; printf '\t' ; cecho "PID: $app_pid" ; cechon " " ; printf '\t\t'
            unset ram_used ; unset app_cpu ; unset app_pid
        fi
}


## Banner
banner () {
    cechon " " ; cechon " "
    cechon "_______________________________________________________________________________" green
    cechon "              -- BeeGFS Administrator's Helper ($release) --" boldgreen
    cechon " "

    get_system_info
    human_readable "$memory" memoryHR
    human_readable "$memory_free" memory_freeHR
    human_readable "$memory_available" memory_availableHR
    cecho "System Memory:  " ; cecho "$memoryHR $unit" green ; cecho " / "
    cecho "$memory_freeHR $unit" green ; cecho " / "
    cecho "$memory_availableHR $unit" green ; cechon " (Installed/Free/Available)"
    cecho "Local Services:" ; printf '\t' ; mgmtd_status ; admon_status ; meta_status ; storage_status ; helperd_status ; cechon " "
    cechon "_______________________________________________________________________________" green
}
 
## Display Menu and process command prompts
pause(){
    local m="$@"
    echo "$m"
    read -p "Press [ ENTER ] key to return to the menu ..." key
}
proper_action="Select proper action key"
select_option="SELECT ONE OF THE ACTIONS AVAILABLE:"
return_to_main="q. Return to Main Menu"
stop_live_output="Press any key to stop the Live Output"
meta_name="Meta Data"
storage_name="Storage"
clients_name="Clients"

while :
do
    clear
    banner ; cechon " " ; cechon " "
    cechon "$select_option" boldgreen
    cecho "1. Show" ; cecho " Extended Status " green ; cechon "of $meta_name, $storage_name nodes"
    cecho "2. Show" ; cecho " Buddy / Mirror Groups " green ; cechon "for $meta_name, $storage_name nodes"
    cecho "3. Check" ; cecho " Connectivity / Reachability " green ; cechon "of $meta_name, $storage_name nodes and $clients_name"
    cecho "4. Fetch" ; cechon " Live IO Stats " yellow
    cecho "5. Check" ; cecho " RESYNC Status " green ; cechon "of $meta_name, $storage_name nodes"
    cecho "6. Perform" ; cecho " Diagnostics, Clean Up and Auto Repair" red ; cechon " of BeeGFS File System"
    cecho "7. Run" ; cecho " Native Benchmarks " green ; cechon "(BeeGFS Network File System throughput benchmarking)"
    cecho "8. Run" ; cecho " FIO, IOPING Benchmarks " green ; cechon "(BeeGFS Network File System IOPS benchmarking with alternative tools)"
    cecho "9. Run" ; cecho " FIO, IOPING Benchmarks " green ; cechon "(benchmarking of underlying FS for local BeeGFS' $storage_name Target)" ; cechon " "
    cechon "q. Exit"
    cechon "_______________________________________________________________________________"
    cecho  " " ; read -r -p "Enter your choice [1-9], or [q] to exit : " c
    # take action
    case $c in
	1)  clear
	    cechon " " ; cechon "Extended Status of $meta_name nodes" boldgreen ; cechon " "
	    beegfs-ctl --listtargets --longnodes --state --pools --nodesfirst --spaceinfo --mirrorgroups --nodetype=meta
	    cechon " " ; cechon " " ; cechon "Extended status of $storage_name nodes" boldgreen ; cechon " "
	    beegfs-ctl --listtargets --longnodes --state --pools --nodesfirst --spaceinfo --mirrorgroups --nodetype=storage
	    cechon " " ; pause;;
	2)  clear
	    cechon " " ; cechon "Buddy / Mirror Groups for $meta_name nodes" boldgreen ; cechon " "
	    beegfs-ctl --listmirrorgroups --nodetype=meta
	    cechon " " ; cechon " " ; cechon "Buddy / Mirror Groups for $storage_name nodes" boldgreen ; cechon " "
	    beegfs-ctl --listmirrorgroups --nodetype=storage
	    cechon " " ; pause;;
        3)  while :
                do
                    clear
                    banner ; cechon " " ; cechon " "
                    cechon "$select_option" boldgreen
                    cecho "1. Check $meta_name nodes" ; cechon " Connectivity / Reachability " green
                    cecho "2. Check $storage_name nodes" ; cechon " Connectivity / Reachability " green
                    cecho "3. Check $clients_name" ; cechon " Connectivity / Reachability " green ; cechon " "
                    cechon "$return_to_main"
                    cechon "_______________________________________________________________________________"
                    cechon " " ; read -r -p "Enter your choice [1-3], or [q] to return to Main Menu: " cc
                    case $cc in
                        1)  clear
                            cechon " " ; cechon "Connectivity / Reachability of $meta_name nodes" boldgreen ; cechon " "
                            beegfs-ctl --listnodes --nodetype=meta --nicdetails --route --reachable --showversion
                            cechon " " ; pause;;
                        2)  clear
                            cechon " " ; cechon "Connectivity / Reachability of $storage_name nodes" boldgreen ; cechon " "
                            beegfs-ctl --listnodes --nodetype=storage --nicdetails --route --reachable --showversion
                            cechon " " ; pause;;
                        3)  clear
                            cechon " " ; cechon "Connectivity / Reachability of known $clients_name" boldgreen ; cechon " "
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
                    cechon "$select_option" boldgreen
                    cechon " Warning: Live IO Stats are CPU / RAM and DISK IO intensive" yellow ;
                    cechon "          Continuous fetching of the IO Stats will negatively affect performance of BeeGFS..." yellow
                    cechon "          To stop Live IO Stats Stream, press any key to stop the madness!" yellow ; cechon " "
                    cecho "1. Fetch basic requests Stats on" ; cechon " all $meta_name nodes" red
                    cecho "2. Fetch IO Stats on" ; cecho " $meta_name nodes for all connected CLIENT nodes " red ; cechon "accessing BeeGFS mounts"
                    cecho "3. Fetch IO Stats on" ; cecho " $meta_name nodes for all SYSTEM USERS " red ; cechon "accessing BeeGFS mounts" ; cechon " "
                    cecho "4. Fetch basic requests Stats on" ; cechon " all $storage_name nodes" red
                    cecho "5. Fetch IO Stats on" ; cecho " $storage_name nodes for all connected CLIENT nodes " red ; cechon "accessing BeeGFS mounts"
                    cecho "6. Fetch IO Stats on" ; cecho " $storage_name nodes for all SYSTEM USERS " red ; cechon "accessing BeeGFS mounts" ; cechon " "
                    cechon "$return_to_main"
                    cechon "_______________________________________________________________________________"
                    cechon " " ; read -r -p "Enter your choice [1-6], or [q] to return to Main Menu: " cc
                    case $cc in
                        1)  clear
                            cechon " " ; cechon "Basic Requests Stats for $meta_name nodes (last 60 seconds, updated every 10 seconds)" boldgreen ; cechon " "
                            cechon "$stop_live_output" red
                            beegfs-ctl --serverstats --perserver --names --nodetype=metadata --history=60 --interval=10
                            cechon " " ; pause;;
                        2)  clear
                            cechon " " ; cechon "Live IO Stats on $meta_name nodes for all connected CLIENT nodes accessing BeeGFS mounts (last 60 seconds, updated every 10 seconds)" boldgreen ; cechon " "
                            cechon "$stop_live_output" red
                            beegfs-ctl --clientstats --names --nodetype=meta --interval=10 --perinterval=60
                            cechon " " ; pause;;
                        3)  clear
                            cechon " " ; cechon "Live IO Stats on $meta_name nodes for all SYSTEM USERS accessing BeeGFS mounts (last 60 seconds, updated every 10 seconds)" boldgreen ; cechon " "
                            cechon "$stop_live_output" red
                            beegfs-ctl --userstats --names --nodetype=meta --interval=10 --perinterval=60
                            cechon " " ; pause;;
                        4)  clear
                            cechon " " ; cechon "Basic Requests Stats for $storage_name nodes (last 60 seconds, updated every 10 seconds)" boldgreen ; cechon " "
                            cechon "$stop_live_output" red
                            beegfs-ctl --serverstats --perserver --names --nodetype=storage --history=60 --interval=10
                            cechon " " ; pause;;
                        5)  clear
                            cechon " " ; cechon "Live IO Stats on $storage_name nodes for all connected CLIENT nodes accessing BeeGFS mounts (last 60 seconds, updated every 10 seconds)" boldgreen ; cechon " "
                            cechon "$stop_live_output" red
                            beegfs-ctl --clientstats --names --nodetype=storage --interval=10 --perinterval=60
                            cechon " " ; pause;;
                        6)  clear
                            cechon " " ; cechon "Live IO Stats on $storage_name nodes for all SYSTEM USERS accessing BeeGFS mounts (last 60 seconds, updated every 10 seconds)" boldgreen ; cechon " "
                            cechon "$stop_live_output" red
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
                    cechon "$select_option" boldgreen
                    cecho "1." ; cecho " RESYNC Status " green ; cechon "of $meta_name nodes"
                    cecho "2." ; cecho " RESYNC Status " green ; cechon "of $storage_name nodes" ; cechon " "

                    cecho "MR." ; cecho " Request RESYNC " red ; cecho "for $meta_name Nodes ("
                        for i in "${meta_nodeids[@]}"
                            do
                                cecho " #$i" red
                            done ; cecho " ) in Mirror Group " ; cechon "#$meta_mirrorgroupid" red

                    cechon "   Caution: If resyncing is active on Metadata Nodes, connected clients" yellow
                    cechon "   will experience lagged file access due to temporary blocking of metadata access." yellow
                    cechon "   Issue RESYNC request only if one of your $meta_name Nodes IS in a BAD Consistency." yellow ; cechon " "
                    cechon "$return_to_main"
                    cechon "_______________________________________________________________________________"
                    cechon " " ; read -r -p "Enter your choice [1-2, MR], or [q] to return to Main Menu: " cc
                    case $cc in
                        1)  clear
                            cechon " " ; cechon "RESYNC Status of $meta_name Mirror Group ID #$meta_mirrorgroupid" boldgreen ; cechon " "
                            beegfs-ctl --resyncstats --nodetype=metadata --mirrorgroupid=$meta_mirrorgroupid
                            for i in "${meta_nodeids[@]}"
                                do
                                    cechon " " ; cechon "RESYNC Status of $meta_name Node ID #$i" boldgreen ; cechon " "
                                    beegfs-ctl --resyncstats --nodetype=metadata --target=$i --mirrorgroupid=$meta_mirrorgroupid
                                done
                            cechon " " ; pause;;
                        2)  clear
                            for i in "${storage_mirrorgroupids[@]}"
                                do
                                    cechon " " ; cechon "RESYNC Status of $storage_name Mirror Group ID #$i" boldgreen ; cechon " "
                                    beegfs-ctl --resyncstats --nodetype=metadata --target=$i --mirrorgroupid=$meta_mirrorgroupid
                                done
                            for i in "${storage_targetids[@]}"
                                do
                                    cechon " " ; cechon "RESYNC Status of $storage_name Target ID #$i" boldgreen ; cechon " "
                                    beegfs-ctl --resyncstats --nodetype=metadata --target=$i --mirrorgroupid=$meta_mirrorgroupid
                                done
                            cechon " " ; pause;;

                        MR)  clear
                            cechon " " ; cechon "Sending RESYNC Request to $meta_name Nodes Group ID #$meta_mirrorgroupid" boldred
                            beegfs-ctl --startresync --nodetype=metadata --mirrorgroupid=$meta_mirrorgroupid
                            cechon " " ; pause;;
                        q)  clear ; break;;
                        *)  pause "$proper_action"
                esac
            done;;
        6)  while :
                do
                    clear
                    banner ; cechon " " ; cechon " "
                    cechon "$select_option" boldgreen
                    cecho "1." ; cechon " Look for Unused Inodes and Dispose the Orphants" red
                    cecho "2." ; cechon " Check for Errors in BeeGFS File System without any Repair Attempts" red
                    cecho "3." ; cechon " Check for Errors in BeeGFS File System, and attempt Automatic Repairs (online)" red ; cechon " "
                    cecho "4." ; cechon " Check for Errors in BeeGFS File System, and attempt Automatic Repairs (offline)" red
                    cechon "   Caution: The repairs to be run in offline mode, which disables the " yellow
                    cechon "   modification logging, (otherwise false errors might be reported)." yellow
                    cechon "   Use this only if you are sure there is no user access to the file" yellow
                    cechon "   system while the check is running." yellow ; cechon " "
                    cechon "$return_to_main"
                    cechon "_______________________________________________________________________________"
                    cechon " " ; read -r -p "Enter your choice [1-3], or [q] to return to Main Menu: " cc
                    case $cc in
                        1)  clear
                            cechon " " ; cechon "Find and Dispose Unused / Orphant Inodes" boldgreen ; cechon " "
                            beegfs-ctl  --disposeunused --printstats --printnodes --dispose
                            cechon " " ; pause;;
                        2)  clear
                            cechon " " ; cechon "Check for Errors in BeeGFS File System without any Repair Attempts" boldgreen ; cechon " "
                            beegfs-fsck --checkfs --overwriteDbFile --readOnly
                            cechon " " ; pause;;
                        3)  clear
                            cechon " " ; cechon "Check for Errors in BeeGFS File System and Automatic Repairs (online)" boldgreen ; cechon " "
                            beegfs-fsck --checkfs --overwriteDbFile --automatic
                            cechon " " ; pause;;
                        4)  clear
                            cechon " " ; cechon "Check for Errors in BeeGFS File System and Automatic Repairs (offline)" boldgreen ; cechon " "
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
                    cechon "$select_option" boldgreen
                    cechon "Warning: Benchmarking operations are CPU, Disk and Network intensive," yellow
                    cechon "         thus your users and / or applications will experience delayed FS access." yellow ; cechon " "
                    cecho "1." ; cecho " STEP 1.1: Launch BeeGFS filesystem Benchmark on all storage targets for" green ; cecho " WRITE " red ; cechon "operations with block size of $beegfs_bench_blocksize, file space of $beegfs_bench_size, and $beegfs_bench_threads CPU threads" green ; cechon " "
                    cecho "2." ; cecho " STEP 1.2: Launch BeeGFS filesystem Benchmark on all storage targets for" green ; cecho " READ " red ; cechon "operations with block size of $beegfs_bench_blocksize, file space of $beegfs_bench_size, and $beegfs_bench_threads CPU threads" green
                    cechon "   Notice: READ Benchmark requires you to run WRITE Benchmark in the first place." yellow
                    cechon "   You also must ensure the WRITE Benchmark is completely finished. It is easy to check" yellow
                    cechon "   completion of your Benchmark by executing STEP 2 of the Benchmarking Menu Section." yellow
                    cechon "   After all the WRITE benchmarks are reported to be finished, collect your WRITE" yellow
                    cechon "   Benchmark Results, executing STEP 2, and then proceed to READ Benchmark." yellow ; cechon " "
                    cecho "3." ; cecho " STEP 2: Monitor and collect WRITE / READ Benchmark" green ; cechon " RESULTS " red ; cechon " "
                    cecho "4." ; cechon " Stop currently running WRITE / READ Benchmark" boldred ; cechon " "
                    cecho "5." ; cechon " Cleanup the BeegFS File System" boldred
                    cechon "   Advise: After all the WRITE / READ Benchmarks are complete, and Results / Statistics are collected," yellow
                    cechon "   you are urged to free up disk space by running the Automatic CLEANUP of BeeGFS File System," yellow
                    cechon "   in order to get rid of multi-gigabyte files created in each Storage Tagret." yellow ; cechon " "
                    cechon "$return_to_main"
                    cechon "_______________________________________________________________________________"
                    cechon " " ; read -r -p "Enter your choice [1-3], or [q] to return to Main Menu: " cc
                    case $cc in
                        1)  clear
                            cechon " " ; cechon "STEP 1.1: Launching BeeGFS filesystem Benchmark on ALL $storage_name TARGETS for WRITE operations with block size of $beegfs_bench_blocksize, file space of $beegfs_bench_size, and $beegfs_bench_threads CPU threads" boldgreen ; cechon " "
                            beegfs-ctl --storagebench --alltargets --write --blocksize=$beegfs_bench_blocksize --size=$beegfs_bench_size --threads=$beegfs_bench_threads
                            cechon " " ; pause;;
                        2)  clear
                            cechon " " ; cechon "STEP 1.1: Launching BeeGFS filesystem Benchmark on ALL $storage_name TARGETS for READ operations with block size of $beegfs_bench_blocksize, file space of $beegfs_bench_size, and $beegfs_bench_threads CPU threads" boldgreen ; cechon " "
                            beegfs-ctl --storagebench --alltargets --read --blocksize=$beegfs_bench_blocksize --size=$beegfs_bench_size --threads=$beegfs_bench_threads
                            cechon " " ; pause;;
                        3)  clear
                            cechon " " ; cechon "Collecting WRITE / READ Benchmark Results" boldgreen ; cechon " "
                            beegfs-ctl --storagebench --status --alltargets --verbose
                            cechon " " ; pause;;
                        4)  clear
                            cechon " " ; cechon "Stopping currently running WRITE / READ Benchmarks" boldgreen ; cechon " "
                            beegfs-ctl --storagebench --alltargets --stop
                            cechon " " ; pause;;
                        5)  clear
                            cechon " " ; cechon "Cleaning up the BeegFS File System for freeing up space after performed Benchmarks" boldgreen ; cechon " "
                            beegfs-ctl --storagebench --cleanup --alltargets
                            cechon " " ; pause;;
                        q)  clear ; break;;
                        *)  pause "$proper_action"
                esac
            done;;
        8)  while :
                do
                    clear
                    banner ; cechon " " ; cechon " "
                    cechon "$select_option" boldgreen
                    cechon "Warning: Benchmarking operations are CPU, Disk and Network intensive," yellow
                    cechon "         thus your users and / or applications will experience delayed FS access." yellow ; cechon " "
                    cecho "1." ; cecho " Run timed ($fio_runtime sec.) FIO Benchmark of BeeGFS filesystem on" green ; cecho " RANDOM DIRECT READ / WRITE " red ; cechon "operations" green
                    cechon "   with read/write ratio of $fio_rwmixread/$fio_rwmixwrite, block size of $fio_blocksize, file space of $fio_size, $fio_numjobs process(es) at $fio_netdev" green ; cechon " "
                    cecho "2." ; cecho " Run timed ($fio_runtime sec.) FIO Benchmark of BeeGFS filesystem on" green ; cecho " RANDOM DIRECT READ " red ; cechon "operations" green
                    cechon "   with block size of $fio_blocksize, file space of $fio_size, $fio_numjobs process(es) at $fio_netdev" green ; cechon " "
                    cecho "3." ; cecho " Run timed ($fio_runtime sec.) FIO Benchmark of BeeGFS filesystem on" green ; cecho " RANDOM DIRECT WRITE " red ; cechon "operations" green
                    cechon "   with block size of $fio_blocksize, file space of $fio_size, $fio_numjobs process(es) at $fio_netdev" green ; cechon " "
                    cecho "4." ; cecho " Perform IOPING tests of" green ; cecho " NETWORK LATENCY / FILE ACCESS TIME " red ; cechon "with block size of $fio_blocksize, file space of $fio_size," green
                    cechon "   requesting $ioping_maxiops IOPS for a maximum time of $fio_runtime seconds, collecting raw statistics every $ioping_time_period seconds," green
                    cechon "   with $ioping_interval seconds interval between requests, and using DIRECT IO at $fio_netdev" green ; cechon " "
                    cechon "   Notice: Benchmark results of both FIO and IOPING will be saved in" yellow
                    cechon "    $PWD_BR/" yellow ; cechon " "
                    cechon "$return_to_main"
                    cechon "_______________________________________________________________________________"
                    cechon " " ; read -r -p "Enter your choice [1-3], or [q] to return to Main Menu: " cc
                    case $cc in
                        1)  clear
                            [[ -d $PWD_BR ]] || mkdir ./$bench_res_dir
                            cechon " " ; cechon "Running timed ($fio_runtime sec.) FIO Benchmark of BeeGFS filesystem on RANDOM DIRECT READ / WRITE operations with read/write ratio of $fio_rwmixread/$fio_rwmixwrite, block size of $fio_blocksize, file space of $fio_size, $fio_numjobs process(es) at $fio_netdev" boldgreen ; cechon " " ; cechon " "
                            fio --name=RandomDirectReadWrite \
                                --rw=randrw \
                                --rwmixread=$fio_rwmixread \
                                --runtime=$fio_runtime \
                                --time_based \
                                --randrepeat=1 \
                                --numjobs=$fio_numjobs \
                                --size=$fio_size \
                                --filesize=$fio_size \
                                --filename=$fio_block_dev \
                                --bs=$fio_blocksize \
                                --direct=1 \
                                --sync=0 \
                                --iodepth=$fio_iodepth \
                                --ioengine=$fio_ioengine \
                                --status-interval=60 \
                                -gtod_reduce=1 \
                                --group_reporting 2>&1 | tee ./$bench_res_dir/fio_beegfs_rand-direct-read-write_$dt.txt
                                rm $fio_block_dev
                            cechon " " ; cechon "Benchmarking results are saved in $PWD_BR/fio_beegfs_rand-direct-read-write_$dt.txt" yellow ; cechon " " ; pause;;
                        2)  clear
                            [[ -d $PWD_BR ]] || mkdir ./$bench_res_dir
                            cechon " " ; cechon "Running timed ($fio_runtime sec.) FIO Benchmark of BeeGFS filesystem on RANDOM DIRECT READ operations with block size of $fio_blocksize, file space of $fio_size, $fio_numjobs process(es) at $fio_netdev" boldgreen ; cechon " " ; cechon " "
                            fio --name=RandomDirectRead \
                                --rw=randread \
                                --runtime=$fio_runtime \
                                --time_based \
                                --randrepeat=1 \
                                --numjobs=$fio_numjobs \
                                --size=$fio_size \
                                --filesize=$fio_size \
                                --filename=$fio_block_dev \
                                --bs=$fio_blocksize \
                                --direct=1 \
                                --sync=0 \
                                --iodepth=$fio_iodepth \
                                --ioengine=$fio_ioengine \
                                --status-interval=60 \
                                -gtod_reduce=1 \
                                --group_reporting 2>&1 | tee ./$bench_res_dir/fio_beegfs_rand-direct-read_$dt.txt
                                rm $fio_block_dev
                            cechon " " ; cechon "Benchmarking results are saved in $PWD_BR/fio_beegfs_rand-direct-read_$dt.txt" yellow ; cechon " " ; pause;;
                        3)  clear
                            [[ -d $PWD_BR ]] || mkdir ./$bench_res_dir
                            cechon " " ; cechon "Running timed ($fio_runtime sec.) FIO Benchmark of BeeGFS filesystem on RANDOM DIRECT WRITE operations with block size of $fio_blocksize, file space of $fio_size, $fio_numjobs process(es) at $fio_netdev" boldgreen ; cechon " " ; cechon " "
                            fio --name=RandomDirectWrite \
                                --rw=randwrite \
                                --runtime=$fio_runtime \
                                --time_based \
                                --randrepeat=1 \
                                --numjobs=$fio_numjobs \
                                --size=$fio_size \
                                --filesize=$fio_size \
                                --filename=$fio_block_dev \
                                --bs=$fio_blocksize \
                                --direct=1 \
                                --sync=0 \
                                --iodepth=$fio_iodepth \
                                --ioengine=$fio_ioengine \
                                --status-interval=60 \
                                -gtod_reduce=1 \
                                --group_reporting 2>&1 | tee ./$bench_res_dir/fio_beegfs_rand-direct-write_$dt.txt
                                rm $fio_block_dev
                            cechon " " ; cechon "Benchmarking results are saved in $PWD_BR/fio_beegfs_rand-direct-write_$dt.txt" yellow ; cechon " " ; pause;;
                        4)  clear
                            [[ -d $PWD_BR ]] || mkdir ./$bench_res_dir
                            cechon " " ; cechon "Measuring NETWORK LATENCY / FILE ACCESS TIME with block size of $fio_blocksize, file space of $fio_size, requesting $ioping_maxiops IOPS for a maximum time of $fio_runtime seconds, collecting raw statistics every $ioping_time_period seconds, with $ioping_interval seconds interval between requests, and using DIRECT IO at $fio_netdev" boldgreen ; cechon " " ; cechon " "
                            cechon "How to read RAW STATISTICS:" boldyellow ; cechon " "
                            cechon "17805 4513437 3945 16158258 50 253 2601 113" yellow
                            cechon "17881 4577080 3907 16001594 47 256 2606 99" yellow
                            cechon "(1)   (2)     (3)  (4)      (5) (6) (7) (8)" yellow ; cechon " "
                            cechon "(1) number of requests in $ioping_time_period seconds period" yellow
                            cechon "(2) serving time         (usec)" yellow
                            cechon "(3) requests per second  (iops)" yellow
                            cechon "(4) transfer speed       (bytes/sec)" yellow
                            cechon "(5) minimal request time (usec)" yellow
                            cechon "(6) average request time (usec)" yellow
                            cechon "(7) maximum request time (usec)" yellow
                            cechon "(8) request time standard deviation (usec)" yellow ; cechon " " ; cechon " "
                            cechon "RAW STATISTICS:" boldgreen ; cechon " "
                            ioping -c $ioping_maxiops -w $fio_runtime -P $ioping_time_period -S $fio_size -s $fio_blocksize -i $ioping_interval -q -D $fio_netdev/ 2>&1 | tee ./$bench_res_dir/ioping_beegfs_results_$dt.txt
                            cechon " " ; cechon "Benchmarking results are saved in $PWD_BR/ioping_beegfs_results_$dt.txt" yellow ; cechon " " ; pause;;
                        q)  clear ; break;;
                        *)  pause "$proper_action"
                esac
            done;;


        9)  while :
                do
                    clear
                    banner ; cechon " " ; cechon " "
                    cechon "$select_option" boldgreen
                    cechon "Warning: Benchmarking operations are CPU, Disk and Network intensive," yellow
                    cechon "         thus your users and / or applications will experience delayed FS access." yellow ; cechon " "
                    cecho "1." ; cecho " Run timed ($fio_runtime sec.) FIO Benchmark of underlying FS for BeeGFS' Local $storage_name Target on" green ; cecho " RANDOM DIRECT READ / WRITE " red ; cechon "operations" green
                    cechon "   with read/write ratio of $fio_rwmixread/$fio_rwmixwrite, block size of $fio_blocksize, file space of $fio_size, $fio_numjobs process(es) at $beegfs_storage_base" green ; cechon " "
                    cecho "2." ; cecho " Run timed ($fio_runtime sec.) FIO Benchmark of underlying FS for BeeGFS' Local $storage_name Target on" green ; cecho " RANDOM DIRECT READ " red ; cechon "operations" green
                    cechon "   with block size of $fio_blocksize, file space of $fio_size, $fio_numjobs process(es) at $beegfs_storage_base" green ; cechon " "
                    cecho "3." ; cecho " Run timed ($fio_runtime sec.) FIO Benchmark of underlying FS for BeeGFS' Local $storage_name Target on" green ; cecho " RANDOM DIRECT WRITE " red ; cechon "operations" green
                    cechon "   with block size of $fio_blocksize, file space of $fio_size, $fio_numjobs process(es) at $beegfs_storage_base" green ; cechon " "
                    cecho "4." ; cecho " Perform IOPING tests of" green ; cecho " NETWORK LATENCY / FILE ACCESS TIME " red ; cechon "with block size of $fio_blocksize, file space of $fio_size," green
                    cechon "   requesting $ioping_maxiops IOPS for a maximum time of $fio_runtime seconds, collecting raw statistics every $ioping_time_period seconds," green
                    cechon "   with $ioping_interval seconds interval between requests, and using DIRECT IO at $beegfs_storage_base" green ; cechon " "
                    cechon "   Notice: Benchmark results of both FIO and IOPING will be saved in" yellow
                    cechon "    $PWD_BR/" yellow ; cechon " "
                    cechon "$return_to_main"
                    cechon "_______________________________________________________________________________"
                    cechon " " ; read -r -p "Enter your choice [1-3], or [q] to return to Main Menu: " cc
                    case $cc in
                        1)  clear
                            [[ -d $PWD_BR ]] || mkdir ./$bench_res_dir
                            cechon " " ; cechon "Running timed ($fio_runtime sec.) FIO Benchmark of underlying FS for BeeGFS' Local $storage_name Target on RANDOM DIRECT READ / WRITE operations with read/write ratio of $fio_rwmixread/$fio_rwmixwrite, block size of $fio_blocksize, file space of $fio_size, $fio_numjobs process(es) at $beegfs_storage_base" boldgreen ; cechon " " ; cechon " "
                            fio --name=RandomDirectReadWrite \
                                --rw=randrw \
                                --rwmixread=$fio_rwmixread \
                                --runtime=$fio_runtime \
                                --time_based \
                                --randrepeat=1 \
                                --numjobs=$fio_numjobs \
                                --size=$fio_size \
                                --filesize=$fio_size \
                                --filename=$fio_block_dev \
                                --bs=$fio_blocksize \
                                --direct=1 \
                                --sync=0 \
                                --iodepth=$fio_iodepth \
                                --ioengine=$fio_ioengine \
                                --status-interval=60 \
                                -gtod_reduce=1 \
                                --group_reporting 2>&1 | tee ./$bench_res_dir/fio_local_fs_rand-direct-read-write_$dt.txt
                                rm $fio_block_dev
                            cechon " " ; cechon "Benchmarking results are saved in $PWD_BR/fio_local_fs_rand-direct-read-write_$dt.txt" yellow ; cechon " " ; pause;;
                        2)  clear
                            [[ -d $PWD_BR ]] || mkdir ./$bench_res_dir
                            cechon " " ; cechon "Running timed ($fio_runtime sec.) FIO Benchmark of underlying FS for BeeGFS' Local $storage_name Target on RANDOM DIRECT READ operations with block size of $fio_blocksize, file space of $fio_size, $fio_numjobs process(es) at $beegfs_storage_base" boldgreen ; cechon " " ; cechon " "
                            fio --name=RandomDirectRead \
                                --rw=randread \
                                --runtime=$fio_runtime \
                                --time_based \
                                --randrepeat=1 \
                                --numjobs=$fio_numjobs \
                                --size=$fio_size \
                                --filesize=$fio_size \
                                --filename=$fio_block_dev \
                                --bs=$fio_blocksize \
                                --direct=1 \
                                --sync=0 \
                                --iodepth=$fio_iodepth \
                                --ioengine=$fio_ioengine \
                                --status-interval=60 \
                                -gtod_reduce=1 \
                                --group_reporting 2>&1 | tee ./$bench_res_dir/fio_local_fs_rand-direct-read_$dt.txt
                                rm $fio_block_dev
                            cechon " " ; cechon "Benchmarking results are saved in $PWD_BR/fio_local_fs_rand-direct-read_$dt.txt" yellow ; cechon " " ; pause;;
                        3)  clear
                            [[ -d $PWD_BR ]] || mkdir ./$bench_res_dir
                            cechon " " ; cechon "Running timed ($fio_runtime sec.) FIO Benchmark of underlying FS for BeeGFS' Local $storage_name Target on RANDOM DIRECT WRITE operations with block size of $fio_blocksize, file space of $fio_size, $fio_numjobs process(es) at $beegfs_storage_base" boldgreen ; cechon " " ; cechon " "
                            fio --name=RandomDirectWrite \
                                --rw=randwrite \
                                --runtime=$fio_runtime \
                                --time_based \
                                --randrepeat=1 \
                                --numjobs=$fio_numjobs \
                                --size=$fio_size \
                                --filesize=$fio_size \
                                --filename=$fio_block_dev \
                                --bs=$fio_blocksize \
                                --direct=1 \
                                --sync=0 \
                                --iodepth=$fio_iodepth \
                                --ioengine=$fio_ioengine \
                                --status-interval=60 \
                                -gtod_reduce=1 \
                                --group_reporting 2>&1 | tee ./$bench_res_dir/fio_local_fs_rand-direct-write_$dt.txt
                                rm $fio_block_dev
                            cechon " " ; cechon "Benchmarking results are saved in $PWD_BR/fio_local_fs_rand-direct-write_$dt.txt" yellow ; cechon " " ; pause;;
                        4)  clear
                            [[ -d $PWD_BR ]] || mkdir ./$bench_res_dir
                            cechon " " ; cechon "Measuring NETWORK LATENCY / FILE ACCESS TIME with block size of $fio_blocksize, file space of $fio_size, requesting $ioping_maxiops IOPS for a maximum time of $fio_runtime seconds, collecting raw statistics every $ioping_time_period seconds, with $ioping_interval seconds interval between requests, and using DIRECT IO at $beegfs_storage_base" boldgreen ; cechon " " ; cechon " "
                            cechon "How to read RAW STATISTICS:" boldyellow ; cechon " "
                            cechon "17805 4513437 3945 16158258 50 253 2601 113" yellow
                            cechon "17881 4577080 3907 16001594 47 256 2606 99" yellow
                            cechon "(1)   (2)     (3)  (4)      (5) (6) (7) (8)" yellow ; cechon " "
                            cechon "(1) number of requests in $ioping_time_period seconds period" yellow
                            cechon "(2) serving time         (usec)" yellow
                            cechon "(3) requests per second  (iops)" yellow
                            cechon "(4) transfer speed       (bytes/sec)" yellow
                            cechon "(5) minimal request time (usec)" yellow
                            cechon "(6) average request time (usec)" yellow
                            cechon "(7) maximum request time (usec)" yellow
                            cechon "(8) request time standard deviation (usec)" yellow ; cechon " " ; cechon " "
                            cechon "RAW STATISTICS:" boldgreen ; cechon " "
                            ioping -c $ioping_maxiops -w $fio_runtime -P $ioping_time_period -S $fio_size -s $fio_blocksize -i $ioping_interval -q -D $beegfs_storage_base/ 2>&1 | tee ./$bench_res_dir/ioping_local_fs_results_$dt.txt
                            cechon " " ; cechon "Benchmarking results are saved in $PWD_BR/ioping_local_fs_results_$dt.txt" yellow ; cechon " " ; pause;;
                        q)  clear ; break;;
                        *)  pause "$proper_action"
                esac
            done;;


	q)  clear ; break;;
	*) pause "$proper_action"
    esac
done
