# Vintage Story Server Auto Update
Auto update script for Vintage Story Linux Server

Tested using Ubuntu server 24.04, and a default Vintage Story server setup ref https://wiki.vintagestory.at/Guide:Dedicated_Server#Dedicated_server_on_Linux

Requires moreutils
Requires adding the VintageStory shell script as a service

The script checks the Vintage Story news feed for new releases, and initiates an update if the new version number is higher than the one already installed.
Release Candidates etc are ignored.

It will check that the server is empty before attempting the upgrade.


# Adding VintageStory shell script as a service
Copy the server.sh file to services (and reload the daemon)
```
cp /home/vintagestory/server/server.sh /etc/init.d/VintageStory
systemctl daemon-reload
```

Relevant commands for managing your server
```
service VintageStory status
service VintageStory start
service VintageStory stop
service VintageStory command "/<command> <parameter>"
service VintageStory command "/autosavenow"
service VintageStory command "/list clients"
```

Make VintageStory server start on boot
```
systemctl enable VintageStory
```
