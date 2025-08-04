#!/bin/bash
# lightsOn.sh

# Copyright (c) 2013 iye.cba at gmail com
# url: https://github.com/iye/lightsOn
# This script is licensed under GNU GPL version 2.0 or above

# Description: Bash script that prevents the screensaver and display power
# management (DPMS) to be activated when you are watching Flash Videos
# fullscreen on Firefox and Chromium.
# Can detect mplayer, minitube, and VLC when they are fullscreen too.
# Also, screensaver can be prevented when certain specified programs are running.
# lightsOn.sh needs xscreensaver or kscreensaver to work.


# HOW TO USE: Start the script with the number of seconds you want the checks
# for fullscreen to be done. Example:
# "./lightsOn.sh 120 &" will Check every 120 seconds if Mplayer, Minitube
# VLC, Firefox or Chromium are fullscreen and delay screensaver and Power Management if so.
# You want the number of seconds to be ~10 seconds less than the time it takes
# your screensaver or Power Management to activate.
# If you don't pass an argument, the checks are done every 50 seconds.
#
# An optional array variable exists here to add the names of programs that will delay the screensaver if they're running.
# This can be useful if you want to maintain a view of the program from a distance, like a music playlist for DJing,
# or if the screensaver eats up CPU that chops into any background processes you have running,
# such as realtime music programs like Ardour in MIDI keyboard mode.
# If you use this feature, make sure you use the name of the binary of the program (which may exist, for instance, in /usr/bin).


# Modify these variables if you want this script to detect if Mplayer,
# VLC, Minitube, or Firefox or Chromium Flash Video are Fullscreen and disable
# xscreensaver/kscreensaver and PowerManagement.
mplayer_detection=1
vlc_detection=1
firefox_flash_detection=1
chromium_flash_detection=1
minitube_detection=1
kodi_detection=1

# Names of programs which, when running, you wish to delay the screensaver.
delay_progs=() # For example ('ardour2' 'gmpc')


# YOU SHOULD NOT NEED TO MODIFY ANYTHING BELOW THIS LINE


# It requires: $1 the process name.
# It provides: nothing.
# Prints: nothing.
# Returns: 0 if the process of process name is found else 1.
findProcess()
{
    # pgrep is limited to match at most 15 characters due to /proc/PID/stat unless
    # f (full) option is used but then anything in command line could match.
    local search_process_pgrep="${1:0:15}"
    if (( $(pgrep -lc "${search_process_pgrep}") >= 1 )); then return 0; else return 1; fi
}


# It requires: $1 the variable of returned process name, $2, $3, ... the process names.
# It provides: nothing.
# Prints: nothing.
# Returns: 0 if the process of a process name in process name args is found else 1.
# Example: findAnyProcessOfProcessNames returnedName "name1" "name2" "name3"
findAnyProcessOfProcessNames()
{
    local -n processNameRef=${1}
    for process_name in "${@:2}"; do
        findProcess "${process_name}"; local findProcess_retcode=${?}
        if (( "${findProcess_retcode}" == 0 )); then
            processNameRef="${process_name}"
            return ${findProcess_retcode}
        fi
    done
    processNameRef=""
    return ${findProcess_retcode}
}


# It requires: $1 the variable of returned screensaver name.
# It provides: nothing.
# Prints: nothing.
# Returns: 0 if the process of a screensaver name is found else 1.
findAnyScreensaverProcess()
{
    # Detect screensaver being used (see the list) else None.
    local screensaver_names=("xscreensaver" "kscreensaver" "xfce4-screensaver")
    local -n screensaverRef=${1}
    findAnyProcessOfProcessNames screensaverRef "${screensaver_names[@]}"
}


# enumerate all the attached screens
displays=""
while read id
do
    displays="${displays} ${id}"
done < <(xvinfo | sed -n 's/^screen #\([0-9]\+\)$/\1/p')

findAnyScreensaverProcess screensaver; findAnyScreensaverProcess_retcode=${?}
if (( "${findAnyScreensaverProcess_retcode}" != 0 )); then
    echo "No screensaver detected"
else
    echo "\"${screensaver}\" screensaver detected"
fi

# It requires: $screensaver the name of running screensaver, $delay_progs the names of delayer programs.
# It provides: nothing.
# Prints: possible log message.
# Returns: 0 if a delayer program is found and the delaying succeeded else 1.
checkDelayProgs()
{
    for prog in "${delay_progs[@]}"; do
        if findProcess ${prog}; then
            echo "Delaying the screensaver because a program on the delay list, \"${prog}\", is running..."
            delayScreensaver
            return
        fi
    done
}

# It requires: $screensaver the name of running screensaver, $displays the found displays, $*_detection the configured variables.
# It provides: nothing.
# Prints: possible log message.
# Returns: 0 if the active windows is full screen and the delaying succeeded else 1.
checkFullscreen()
{
    # loop through every display looking for a fullscreen window
    for display in ${displays}
    do
        #get id of active window and clean output
        local activ_win_id=`DISPLAY=:0.${display} xprop -root _NET_ACTIVE_WINDOW`
        #activ_win_id=${activ_win_id#*# } #gives error if xprop returns extra ", 0x0" (happens on some distros)
        activ_win_id=${activ_win_id:40:9}

        # Skip invalid window ids (commented as I could not reproduce a case
        # where invalid id was returned, plus if id invalid
        # isActivWinFullscreen will fail anyway.)
        #if [ "$activ_win_id" = "0x0" ]; then
        #     continue
        #fi

        # Check if Active Window (the foremost window) is in fullscreen state
        isActivWinFullscreen=`DISPLAY=:0.${display} xprop -id $activ_win_id | grep _NET_WM_STATE_FULLSCREEN`
            if [[ "$isActivWinFullscreen" = *NET_WM_STATE_FULLSCREEN* ]];then
                isAppRunning ${activ_win_id}
                var=$?
                if [[ $var -eq 1 ]];then
                    delayScreensaver
                fi
            fi
    done
}





# check if active windows is mplayer, vlc or firefox
#TODO only window name in the variable activ_win_id, not whole line.
#Then change IFs to detect more specifically the apps "<vlc>" and if process name exist

isAppRunning()
{
    local activ_win_id=$1
    #Get title of active window
    activ_win_title=`xprop -id $activ_win_id | grep "WM_CLASS(STRING)"`   # I used WM_NAME(STRING) before, WM_CLASS more accurate.



    # Check if user want to detect Video fullscreen on Firefox, modify variable firefox_flash_detection if you dont want Firefox detection
    if [ $firefox_flash_detection == 1 ];then
        if [[ "$activ_win_title" = *unknown* || "$activ_win_title" = *plugin-container* ]];then
        # Check if plugin-container process is running
            flash_process=`pgrep -l plugin-containe | grep -wc plugin-containe`
            #(why was I using this line avobe? delete if pgrep -lc works ok)
            #flash_process=`pgrep -lc plugin-containe`
            if [[ $flash_process -ge 1 ]];then
                return 1
            fi
        fi
    fi


    # Check if user want to detect Video fullscreen on Chromium, modify variable chromium_flash_detection if you dont want Chromium detection
    if [ $chromium_flash_detection == 1 ];then
        if [[ "$activ_win_title" = *exe* ]];then
        # Check if Chromium/Chrome Flash process is running
            flash_process=`pgrep -lfc ".*((c|C)hrome|chromium).*flashp.*"`
            if [[ $flash_process -ge 1 ]];then
                return 1
            fi
        fi
    fi


    #check if user want to detect mplayer fullscreen, modify variable mplayer_detection
    if [ $mplayer_detection == 1 ];then
        if [[ "$activ_win_title" = *mplayer* || "$activ_win_title" = *MPlayer* ]];then
            #check if mplayer is running.
            #mplayer_process=`pgrep -l mplayer | grep -wc mplayer`
            mplayer_process=`pgrep -lc mplayer`
            if [ $mplayer_process -ge 1 ]; then
                return 1
            fi
        fi
    fi


    # Check if user want to detect vlc fullscreen, modify variable vlc_detection
    if [ $vlc_detection == 1 ];then
        if [[ "$activ_win_title" = *vlc* ]];then
            #check if vlc is running.
            #vlc_process=`pgrep -l vlc | grep -wc vlc`
            vlc_process=`pgrep -lc vlc`
            if [ $vlc_process -ge 1 ]; then
                return 1
            fi
        fi
    fi

    # Check if user want to detect minitube fullscreen, modify variable minitube_detection
    if [ $minitube_detection == 1 ];then
        if [[ "$activ_win_title" = *minitube* ]];then
            #check if minitube is running.
            #minitube_process=`pgrep -l minitube | grep -wc minitube`
            minitube_process=`pgrep -lc minitube`
            if [ $minitube_process -ge 1 ]; then
                return 1
            fi
        fi
    fi

    if [ $kodi_detection == 1 ];then
        if [[ "$activ_win_title" = *kodi* ]];then
            #check if kodi is running.
            #kodi_process=`pgrep -l kodi | grep -wc kodi`
            kodi_process=`pgrep -lc kodi`
            if [ $kodi_process -ge 1 ]; then
                return 1
            fi
        fi
    fi



return 0
}


delayScreensaver()
{
    # reset inactivity time counter so screensaver is not started
    case "${screensaver}" in
        "xscreensaver" | "xfce4-screensaver")
            ${screensaver}-command -deactivate > /dev/null
        ;;
        "kscreensaver")
            qdbus org.freedesktop.ScreenSaver /ScreenSaver SimulateUserActivity > /dev/null
        ;;
        "")
        ;;
        *)
            echo "Unsupported screensaver: ${screensaver}"
        ;;
    esac


    #Check if DPMS is on. If it is, deactivate and reactivate again. If it is not, do nothing.
    dpmsStatus=`xset -q | grep -ce 'DPMS is Enabled'`
    if (( $dpmsStatus == 1 )); then
        xset -dpms
        xset dpms
    fi
}



delay=$1


# If argument empty, use 50 seconds as default.
if [ -z "$1" ];then
    delay=50
fi


# If argument is not integer quit.
if [[ $1 = *[^0-9]* ]]; then
    echo "The Argument \"$1\" is not valid, not an integer"
    echo "Please use the time in seconds you want the checks to repeat."
    echo "You want it to be ~10 seconds less than the time it takes your screensaver or DPMS to activate"
    exit 1
fi


while true
do
    checkDelayProgs
    checkFullscreen
    sleep $delay
done


exit 0
