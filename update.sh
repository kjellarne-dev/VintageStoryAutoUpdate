#!/bin/bash

# Output all text to logfile
logdir="/var/log/vintagestory"
mkdir -p $logdir
guid=uuidgen
logfile="${logdir}/UpdateScript.sh.$(date +%Y-%m-%dT%H:%M).$guid.log"
exec 1>> >(ts '[%Y-%m-%d %.T]' > "$logfile") 2>&1

echo "Script started execution at $(date +%Y-%m-%dT%H:%M)"
echo "GUID for this run: $guid"

############ VARIABLES

vintageStoryNewsXML="https://www.vintagestory.at/forums/forum/7-news.xml"

# Define Vintage Story server parameters
backupPath="/var/vintagestory/data/Backups/ServerFiles"
serverPath="/home/vintagestory/server"
serviceName=VintageStory
userName=vintagestory

# How many minutes should the script attempt to update before cancelling
minutesToAttemptUpdate=60

############ END VARIABLES
############ FUNCTIONS

function get_newest_version () {
  # Extract all title tags from XML file
  # Select all strings matching a valid version number in the format 1.1.1 (any number of digits, only two periods)
  # Ignore all releases matching rc/alpha/beta/pre/dev
  # Remove everything except for the version number from the string
  # Select the highest version
  
  set -euo pipefail
  TMP=$(mktemp)
  curl -sL "$1" > "$TMP"

  # 1. extract titles
  grep -E '<title>.*</title>' "$TMP" \
    | sed -E 's|^.*<title>(.*)</title>.*$|\1|' > "${TMP}.titles"

  # 2. isolate stable version strings (skip rc/alpha/beta/pre/dev)
  grep -oiE '[0-9]+\.[0-9]+\.[0-9]+' "${TMP}.titles" \
    | grep -vEi '(rc|alpha|beta|pre|dev)' > "${TMP}.versions"

  # 3. highest version
  newVer=$(sort -V "${TMP}.versions" | tail -n 1)
  echo "Newest version available according to XML: $newVer"

  rm -f "$TMP" "${TMP}.titles" "${TMP}.versions"
}

############ END FUNCTIONS
############ SCRIPT

### Check if the newest available update is newer than the installed version
    # Get the installed version number. Filepath example: "$serverPath/assets/version-1.21.5.txt"
    oldVer=$(ls "$serverPath/assets" | grep "version-")
    oldVer=${oldVer#"version-"}
    oldVer=${oldVer%".txt"}
    if [[ -z "$oldVer" ]]
    then
        echo "oldVer is empty. Cancelling update process"
        exit
    else
        echo "Discovered old version $oldVer"
    fi

    # Get the newest released version number
    newVer=""
    get_newest_version $vintageStoryNewsXML
    if [[ -z "$newVer" ]]
    then
        echo "newVer is empty. Cancelling update process"
        exit
    else
        echo "Discovered new version $newVer"
    fi

    # Compare old and new version number. Update if "newVer" is more recent than "oldVer"
    if [ "$(printf '%s\n' "$newVer" "$oldVer" | sort -V | head -n1)" = "$newVer" ]
    then 
        echo "Greater than or equal to $newVer. Do not update"
        exit
    else
        echo "Less than $newVer. Downloading update package"
    fi

### Download and verify new update. Perform update pre-checks
    # Remove old server downloads if they exist
    rm -f /tmp/vs_server_linux-x64_*.*.*.tar.gz

    # Download to /tmp and verify that the tarball is extractable before performing system changes
    wget https://cdn.vintagestory.at/gamefiles/stable/vs_server_linux-x64_$newVer.tar.gz -P /tmp
    if [ $(tar xzOf /tmp/vs_server_linux-x64_*.*.*.tar.gz &> /dev/null; echo $?) ]
    then
        echo "Tarball extracted successfully. Initiating update process"
    else
        echo "Tarball failed to extract. Cancelling update process"
        exit
    fi

    # Verify that there are no players online
    # Line count with 0 players online = 4. Anything above that indicates that someone is connected
    while [ "$(service $serviceName command "/list clients" | wc -l)" -gt 4 ]
    do
        echo "Players are connected. Waiting for them to disconnect"
        sleep 1m
        i=$((i+1))
        if [ $i -gt $minutesToAttemptUpdate ]
        then
            echo "Waited for $minutesToAttemptUpdate minutes. Users are still connected. Cancelling update process"
            exit
        fi
    done

### Install the update
    # Save game and stop VintageStory server service
    service $serviceName command "/autosavenow"
    service $serviceName stop

    # Make a backup of the save files
    #### TODO

    # Move old server files to backup folder
    mkdir -p $backupPath
    mv $serverPath "$backupPath/$oldVer-$(date +%Y-%m-%d)-$guid"

    # Remove older server file backups if they exceed x
    #### TODO

    # Download and extract new server files
    mkdir -p $serverPath
    tar xzf /tmp/vs_server_linux-x64_*.*.*.tar.gz -C $serverPath
    rm /tmp/vs_server_linux-x64_*.*.*.tar.gz

    # Make server.sh executable, set correct permissions
    chmod +x "$serverPath/server.sh"
    chown $userName:$userName $serverPath -R

    # Start server again
    service $serviceName start

############ END SCRIPT




## TODO

# Backup the world save
# Remove server file backups if more than x exist
# Server alerts for updates?
# External alerts (Discord/Telegram/others)?