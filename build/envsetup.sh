# tesla functions that extend build/envsetup.sh

function tesla_device_combos()
{
    local T list_file variant device

    T="$(gettop)"
    list_file="${T}/vendor/tesla/tesla.devices"
    variant="userdebug"

    if [[ $1 ]]
    then
        if [[ $2 ]]
        then
            list_file="$1"
            variant="$2"
        else
            if [[ ${VARIANT_CHOICES[@]} =~ (^| )$1($| ) ]]
            then
                variant="$1"
            else
                list_file="$1"
            fi
        fi
    fi

    if [[ ! -f "${list_file}" ]]
    then
        echo "unable to find device list: ${list_file}"
        list_file="${T}/vendor/tesla/tesla.devices"
        echo "defaulting device list file to: ${list_file}"
    fi

    while IFS= read -r device
    do
        add_lunch_combo "tesla_${device}-${variant}"
    done < "${list_file}"
}

function tesla_rename_function()
{
    eval "original_tesla_$(declare -f ${1})"
}

function _tesla_build_hmm() #hidden
{
    printf "%-8s %s" "${1}:" "${2}"
}

function tesla_append_hmm()
{
    HMM_DESCRIPTIVE=("${HMM_DESCRIPTIVE[@]}" "$(_tesla_build_hmm "$1" "$2")")
}

function tesla_add_hmm_entry()
{
    for c in ${!HMM_DESCRIPTIVE[*]}
    do
        if [[ "${1}" == $(echo "${HMM_DESCRIPTIVE[$c]}" | cut -f1 -d":") ]]
        then
            HMM_DESCRIPTIVE[${c}]="$(_tesla_build_hmm "$1" "$2")"
            return
        fi
    done
    tesla_append_hmm "$1" "$2"
}

function teslaremote()
{
    local proj pfx project

    if ! git rev-parse &> /dev/null
    then
        echo "Not in a git directory. Please run this from an Android repository you wish to set up."
        return
    fi
    git remote rm tesla 2> /dev/null

    proj="$(pwd -P | sed "s#$ANDROID_BUILD_TOP/##g")"

    if (echo "$proj" | egrep -q 'external|system|build|bionic|art|libcore|prebuilt|dalvik') ; then
        pfx="android_"
    fi

    project="${proj//\//_}"

    git remote add tesla "git@github.com:tesla/$pfx$project"
    echo "Remote 'tesla' created"
}

function cmremote()
{
    local proj pfx project

    if ! git rev-parse &> /dev/null
    then
        echo "Not in a git directory. Please run this from an Android repository you wish to set up."
        return
    fi
    git remote rm cm 2> /dev/null

    proj="$(pwd -P | sed "s#$ANDROID_BUILD_TOP/##g")"
    pfx="android_"
    project="${proj//\//_}"
    git remote add cm "git@github.com:CyanogenMod/$pfx$project"
    echo "Remote 'cm' created"
}

function aospremote()
{
    local pfx project

    if ! git rev-parse &> /dev/null
    then
        echo "Not in a git directory. Please run this from an Android repository you wish to set up."
        return
    fi
    git remote rm aosp 2> /dev/null

    project="$(pwd -P | sed "s#$ANDROID_BUILD_TOP/##g")"
    if [[ "$project" != device* ]]
    then
        pfx="platform/"
    fi
    git remote add aosp "https://android.googlesource.com/$pfx$project"
    echo "Remote 'aosp' created"
}

function cafremote()
{
    local pfx project

    if ! git rev-parse &> /dev/null
    then
        echo "Not in a git directory. Please run this from an Android repository you wish to set up."
    fi
    git remote rm caf 2> /dev/null

    project="$(pwd -P | sed "s#$ANDROID_BUILD_TOP/##g")"
    if [[ "$project" != device* ]]
    then
        pfx="platform/"
    fi
    git remote add caf "git://codeaurora.org/$pfx$project"
    echo "Remote 'caf' created"
}

function tesla_push()
{
    local branch ssh_name path_opt proj
    branch="lp5.1"
    ssh_name="tesla_review"
    path_opt=

    if [[ "$1" ]]
    then
        proj="$ANDROID_BUILD_TOP/$(echo "$1" | sed "s#$ANDROID_BUILD_TOP/##g")"
        path_opt="--git-dir=$(printf "%q/.git" "${proj}")"
    else
        proj="$(pwd -P)"
    fi
    proj="$(echo "$proj" | sed "s#$ANDROID_BUILD_TOP/##g")"
    proj="$(echo "$proj" | sed 's#/$##')"
    proj="${proj//\//_}"

    if (echo "$proj" | egrep -q 'external|system|build|bionic|art|libcore|prebuilt|dalvik') ; then
        proj="android_$proj"
    fi

    git $path_opt push "ssh://${ssh_name}/tesla/$proj" "HEAD:refs/for/$branch"
}

function eat()
{
    if [ "$OUT" ] ; then
        ZIPPATH=`ls -tr "$OUT"/tesla-*.zip | tail -1`
        if [ ! -f $ZIPPATH ] ; then
            echo "Nothing to eat"
            return 1
        fi
        adb start-server # Prevent unexpected starting server message from adb get-state in the next line
        if [ $(adb get-state) != device -a $(adb shell 'test -e /sbin/recovery 2> /dev/null; echo $?') != 0 ] ; then
            echo "No device is online. Waiting for one..."
            echo "Please connect USB and/or enable USB debugging"
            until [ $(adb get-state) = device -o $(adb shell 'test -e /sbin/recovery 2> /dev/null; echo $?') = 0 ];do
                sleep 1
            done
            echo "Device Found.."
        fi
        if (adb shell getprop ro.tesla.device | grep -q "$TESLA_BUILD"); then
            # if adbd isn't root we can't write to /cache/recovery/
            adb root
            sleep 1
            adb wait-for-device
            cat << EOF > /tmp/command
--sideload_auto_reboot
EOF
            if adb push /tmp/command /cache/recovery/ ; then
                echo "Rebooting into recovery for sideload installation"
                adb reboot recovery
                adb wait-for-sideload
                adb sideload $ZIPPATH
            fi
            rm /tmp/command
        else
            echo "The connected device does not appear to be $TESLA_BUILD, run away!"
        fi
        return $?
    else
        echo "Nothing to eat"
        return 1
    fi
}


tesla_rename_function hmm
function hmm() #hidden
{
    local i T
    T="$(gettop)"
    original_tesla_hmm
    echo

    echo "vendor/tesla extended functions. The complete list is:"
    for i in $(grep -P '^function .*$' "$T/vendor/tesla/build/envsetup.sh" | grep -v "#hidden" | sed 's/function \([a-z_]*\).*/\1/' | sort | uniq); do
        echo "$i"
    done |column
}

tesla_append_hmm "teslaremote" "Add a git remote for matching tesla repository"
tesla_append_hmm "aospremote" "Add git remote for matching AOSP repository"
tesla_append_hmm "cafremote" "Add git remote for matching CodeAurora repository."
