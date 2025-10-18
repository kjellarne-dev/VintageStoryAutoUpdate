#!/bin/bash

# Output all text to logfile
logdir="/var/log/vintagestory"
mkdir -p $logdir
logfile="${logdir}/UpdateScript.sh.$(date +%Y-%m-%d_%H:%M).log"
exec 1>> >(ts '[%Y-%m-%d %H:%M:%S]' > "$logfile") 2>&1

############ VARIABLES

vintageStoryNewsXML="https://www.vintagestory.at/forums/forum/7-news.xml"

# Define path of default Vintage Story folders
homePath="/home/vintagestory"
serverPath="${homePath}/server"

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

# Get the installed version number. Filepath example: "$serverPath/assets/version-1.21.5.txt"
oldVer=$(ls "$serverPath/assets" | grep "version-")
oldVer=${oldVer#"version-"}
oldVer=${oldVer%".txt"}
if [[ -z "$oldVer" ]]
then
  echo "oldVer is empty. Cancelling update process"
  return
else
  echo "Discovered old version $oldVer"
fi

# Get the newest released version number
newVer=""
get_newest_version $vintageStoryNewsXML
if [[ -z "$newVer" ]]
then
  echo "newVer is empty. Cancelling update process"
  return
else
  echo "Discovered new version $newVer"
fi

# Compare old and new version number. Update if "newVer" is more recent than "oldVer"
if [ "$(printf '%s\n' "$newVer" "$oldVer" | sort -V | head -n1)" = "$newVer" ]
then 
  echo "Greater than or equal to $newVer. Do not update"
  return
else
  echo "Less than $newVer. Downloading update package"
fi

# Download to /tmp and verify that the tarball is extractable before performing system changes
wget https://cdn.vintagestory.at/gamefiles/stable/vs_server_linux-x64_$newVer.tar.gz -P /tmp
if [ $(tar xzOf /tmp/vs_server_linux-x64_*.*.*.tar.gz &> /dev/null; echo $?) ]
then
  echo "tarball extracted successfully. Initiating update process"
else
  echo "tarball failed to extract. Cancelling update process"
  return
fi

# Verify that there are no players online
############ END SCRIPT