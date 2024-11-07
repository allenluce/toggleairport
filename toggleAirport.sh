#!/bin/bash
#git@github.com:paulbhart/toggleairport.git
#originally from https://gist.github.com/albertbori/1798d88a93175b9da00b

unset VERBOSE

while getopts "v" option; do
    case $option in
    v) VERBOSE=true
    esac
done

# rate limiting, run at most every second
lastRun=/var/tmp/prev_toggle_airport_run
if [ -f "${lastRun}" ]; then
    secondsSinceLastRun=$(($(/bin/date +%s) - $(/usr/bin/stat -t %s -f %m -- "$lastRun")))
    if (( $secondsSinceLastRun < 1 )); then
        [ ! -z $VERBOSE ] && echo Last ran $secondsSinceLastRun seconds ago, exiting
        exit 0
    fi
fi

date +%s > /var/tmp/prev_toggle_airport_run

function set_airport {

    new_status=$1

    if [ $new_status = "On" ]; then
        /usr/sbin/networksetup -setairportpower $air_name on
        touch /var/tmp/prev_air_on
    else
        /usr/sbin/networksetup -setairportpower $air_name off
        if [ -f "/var/tmp/prev_air_on" ]; then
            rm /var/tmp/prev_air_on
        fi
    fi

}

function notify {
    osascript -e "display notification \"$1\" with title \"Wi-Fi Toggle\""
}

# Set default values
prev_eth_status="Off"
prev_air_status="Off"
eth_status="Off"

# Grab the names of the adapters. We assume here that any ethernet connection name ends in "Ethernet"
eth_names=`networksetup -listnetworkserviceorder | sed -En 's/^\(Hardware Port: .*(Ethernet|LAN|AX88179A).* Device: (en[0-9]+)\)$/\2/p'`
air_name=`networksetup -listnetworkserviceorder | sed -En 's/^\(Hardware Port: (Wi-Fi|AirPort).* Device: (en[0-9]+)\)$/\2/p'`

# Determine previous ethernet status
# If file prev_eth_on exists, ethernet was active last time we checked
if [ -f "/var/tmp/prev_eth_on" ]; then
    prev_eth_status="On"
fi

# Determine same for Wi-Fi status
# File is prev_air_on
if [ -f "/var/tmp/prev_air_on" ]; then
    prev_air_status="On"
fi

# Check actual current ethernet status
for eth_name in ${eth_names}; do
    if ([ "$eth_name" != "" ] && [ "`ifconfig $eth_name | grep "status: active"`" != "" ]); then
        eth_status="On"
    fi
done

# And actual current Wi-Fi status
air_status=`/usr/sbin/networksetup -getairportpower $air_name | awk '{ print $4 }'`

# Determine whether ethernet status changed
if [ "$prev_eth_status" != "$eth_status" ]; then

    if [ "$eth_status" = "On" ]; then
        set_airport "Off"
        notify "Wired network detected. Turning Wi-Fi off."
    else
        set_airport "On"
        notify "No wired network detected. Turning Wi-Fi on."
    fi

# If ethernet did not change
else

    # Check whether Wi-Fi status changed
    # If so it was done manually by user
    if [ "$prev_air_status" != "$air_status" ]; then
        set_airport $air_status

        if [ "$air_status" = "On" ]; then
            notify "Wi-Fi manually turned on."
        else
            notify "Wi-Fi manually turned off."
        fi

    fi

fi

# Update ethernet status
if [ "$eth_status" == "On" ]; then
    touch /var/tmp/prev_eth_on
else
    if [ -f "/var/tmp/prev_eth_on" ]; then
        rm /var/tmp/prev_eth_on
    fi
fi

exit 0
