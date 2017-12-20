#!/bin/bash
#
# The MIT License (MIT)
#
# Copyright (c) 2013-2014 Nathan Typanski
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Script for setting up DisplayLink monitor.
#
# Fill in MAINOUTPUT, MAINPROVIDER, WIDTH, HEIGHT, and REFRESH with your own
# values before use.

MAINOUTPUT="LVDS1" # Obtained from xrandr --current
MAINPROVIDER="0"   # Obtained from xrandr --listproviders
WIDTH="1366"       # Width of DisplayLink monitor in pixels
HEIGHT="768"       # Height of DisplayLink monitor in pixels
REFRESH="59.9"     # Refresh rate of DisplayLink monitor

# Behave like `echo`, but print the first arg in blue, and subsequent args in
# regular font. Purely for eyecandy.
function blueprint() {
    tput setaf 6
    tput bold
    for arg in "$@"; do
        printf "$arg "
        tput sgr0
    done
    echo
}

# Print in bold red text to stderr and exit the program with status 1.
function fail() {
    tput setaf 1
    tput bold
    for arg in "$@"; do
        echo "$arg" > /dev/stderr
        tput sgr0
    done
    tput sgr0
    exit 1
}

# Generate modeline info for the displaylink monitor in xrandr using 'gtf'.
# We need to do some work on gtf's output to make it usable.
modeline=$(gtf "$WIDTH" "$HEIGHT" "$REFRESH" |\
           grep 'Modeline' |\
           sed 's/\( *Modeline *\)//g' |\
           sed 's/"//g')

dlmodename=$(echo "$modeline" | cut -d ' ' -f 1)

# Try to guess at the DisplayLink provider number. If there are other
# modesetting providers active, this might fail to grab the correct
# one.
dlprovider=$(xrandr --listproviders | \
             grep 'name:modesetting' | \
             cut -d ' ' -f 2 | \
             sed -e 's/://g')

if [ -z "$dlprovider" ]; then
    fail "<< No displaylink providers found, bailing! >>"
fi

# Obtain the dimensions of the main provider.
mainstatus=$(xrandr --current | grep "$MAINOUTPUT" | cut -d ' ' -f 4)

if [ -z "$mainstatus" ]; then
    fail "<< Couldn't get status of main output $MAINOUTPUT >>"
fi

# Get the width, height, and position of the main provider from $mainstatus
# so we can place the DisplayLink output next to it.
attributes=($(sed \
            's/\([0-9]\+\)x\([0-9]\+\)+\([0-9]\+\)+\([0-9]\+\)/\1 \2 \3 \4/g' \
            <<< "$mainstatus"))

# Break attributes into component parts so we can use nice descriptive names.
mainwidth="${attributes[0]}"
mainheight="${attributes[1]}"
mainx="${attributes[2]}"
mainy="${attributes[3]}"

blueprint ">> Generated modeline:" "$modeline"
blueprint ">> Detected DisplayLink provider:" "$dlprovider"
blueprint ">> Main output config:"\
          "$mainwidth"x"$mainheight" 'resolution'\
          'at position ('"$mainx"','"$mainy"')'

# DisplayLink monitors usually show up as DVI outputs, but we could probably
# find a more definitive way to check this.
if ! xrandr | grep DVI; then
    blueprint "Associating DL provider with $MAINPROVIDER"

    xrandr --setprovideroutputsource "$dlprovider" "$MAINPROVIDER" > /dev/null

    if [[ "$?" -ne 0 ]]; then
      fail "Could not set Displayink provider."
    fi
fi

if ! xrandr | grep "$dlmodename" > /dev/null; then
    blueprint ">> Desired DisplayLink mode "
    printf "$dlmodename"
    blueprint " does not exist! Creating new mode ...\n"
    xrandr --newmode $modeline || fail "could not create mode for $dlmodename"
fi


dloutput=$(xrandr | grep DVI | cut -d ' ' -f 1)
[ "$dloutput" ] || fail " << Failed to find the DisplayLink output >>";

blueprint ">> DisplayLink output: " "$dloutput"

# Add the modeline to the DisplayLink output. Perhaps we shouldn't actually do
# this every time, and in fact we should look and see if DVI-whatever already
# has that mode associated with it.
xrandr --addmode "$dloutput" "$dlmodename"

# The payoff. If this passes, we're in business.
xrandr --output "$MAINOUTPUT" \
       --mode "$mainwidth"x"$mainheight" \
       --pos "$mainx"x"$mainy" --rotate normal \
       --output "$dloutput" --mode "$dlmodename" \
       --pos "$mainwidth"x"$mainy" --rotate normal \
       --output VGA1 --off \
 || fail "<< Couldn't configure xrandr outputs - try doing it manually >>"
