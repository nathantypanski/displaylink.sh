#!/bin/bash
# Script for setting up DisplayLink monitor.
#
# Fill in MAINOUTPUT, MAINPROVIDER, WIDTH, HEIGHT, and REFRESH with your own
# values before use.

MAINOUTPUT="LVDS1" # Obtained from xrandr --current
MAINPROVIDER="0"   # Obtained from xrandr --listproviders
WIDTH="1366"       # Width of DisplayLink monitor in pixels
HEIGHT="768"       # Height of DisplayLink monitor in pixels
REFRESH="59.9"     # Refresh rate of DisplayLink monitor

modeline=$(\
    gtf $WIDTH $HEIGHT $REFRESH | \
    grep -E "Modeline" | \
    cut -d ' ' -f 4- | \
    sed -e 's/"//g' \
)
dlmodename=$(echo $modeline | cut -d ' ' -f 1)
dlprovider=$( \
    xrandr --listproviders | \
    grep modesetting | \
    cut -d ' ' -f 2 | \
    sed -e 's/://g' \
)
mainstatus=$(xrandr --current | grep $MAINOUTPUT | cut -d ' ' -f 3)

# Get attributes from the main provider.
SEARCHLINE='\([0-9]\+\)x\([0-9]\+\)+\([0-9]\+\)+\([0-9]\+\)'
mainwidth=$(echo $mainstatus | sed 's/'$SEARCHLINE'/\1/g')
mainheight=$(echo $mainstatus | sed 's/'$SEARCHLINE'/\2/g')
mainx=$(echo $mainstatus | sed 's/'$SEARCHLINE'/\3/g')
mainy=$(echo $mainstatus | sed 's/'$SEARCHLINE'/\4/g')

# Prints something in blue. Creative, huh?
function blueprint() {
    tput setaf 6; tput bold;
    for var in $@; do
        printf "$var "
    done
    tput sgr0;
}

function fail() {
    tput setaf 1; tput bold;
    echo
    echo $1
    tput sgr0
    exit 1
}

blueprint ">> DisplayLink Mode: "
echo $modeline

blueprint ">> DisplayLink Provider: "
echo $dlprovider

blueprint ">> DisplayLink Mode name: "
echo $dlmodename

if [ "$dlprovider" ]; then
    if ! xrandr | grep DVI; then
        [[ $(xrandr --setprovideroutputsource "$dlprovider" "$MAINPROVIDER") -eq 0 ]] \
            || fail "Could not set Displayink provider."
    fi

    if ! xrandr | grep $dlmodename; then
        blueprint ">> Desired DisplayLink mode "
        printf $dlmodename
        blueprint " does not exist! Creating new mode ...\n"
        xrandr --newmode $modeline
    fi

    blueprint ">> DisplayLink output: "
    dloutput=$(xrandr | grep DVI | cut -d ' ' -f 1)

    [ "$dloutput" ] || fail "No displaylink provider found! Dying";
    echo $dloutput

    xrandr --addmode $dloutput $dlmodename
    xrandr --output $MAINOUTPUT --mode "$mainwidth"x"$mainheight" --pos "$mainx"x"$mainy" --rotate normal \
        --output $dloutput --mode $dlmodename --pos "$mainwidth"x"$mainy" --rotate normal \
        --output VGA1 --off
else
    blueprint "<< No displaylink providers found, bailing! >>"
    echo ""
    exit 1
fi
