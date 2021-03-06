#This is a script that automatically downloads and installed the Ventoy drive creation script's latest version, and then uses it to create ventoy drives out of all connected USB block devices on my machine.

# CURRENTLY THIS DOESNT FUNCTION BECAUSE VENTOY HAS NO WINDOWS COMMAND LINE OPTIONS. :sob:

# Due to writing partition information, this script needs to be run as the super user.

#Lets set the Variable for my user directory, and where I want Ventoy to install itself:
$Ventdirectory = "$HOME\Documents\Scripts\Programs_for_scripts\Ventoy"

#First we'll clear out the install directory and re-create it.
Remove-Item $Ventdirectory -Recurse -Force
New-Item -Path $Ventdirectory -ItemType Directory -Force

#Now lets download it set a variable named off the .tar.gz.
$Ventdownloadraw = (Invoke-WebRequest -Uri https://api.github.com/repos/ventoy/Ventoy/releases/latest -UseBasicParsing).Content -split "," | Select-String windows.zip -AllMatches | Select-String download
$Ventdownloadfix = $Ventdownloadraw -replace ".*https" -replace "`"}.*"
$Ventdownload = ("https") + $Ventdownloadfix

#Github doesn't support standard: Start-bitstransfer, you need to use this sort of command to allow a download from Github.com, we then unzip and clean up, We then re-set the Vendirectory variable to accomodate the current versioning of Ventoy.
bitsadmin /transfer mydownload /dynamic /download /priority FOREGROUND $Ventdownload $Ventdirectory\Ventoy.zip
Expand-Archive -Path $Ventdirectory\Ventoy.zip -DestinationPath $Ventdirectory -Force
Remove-Item $Ventdirectory\Ventoy.zip -Force
$Ventversion = (Get-ChildItem $HOME\Documents\Scripts\Programs_for_scripts\Ventoy\).Name
$Ventdirectory = $Ventdirectory + "\$Ventversion"

#Now lets create a list of all drives in the Machine that are USB and run the command for each of them.
[array] $DRIVELIST = Get-Volume | Where-Object {$_.DriveType -eq 'removable'} | Select-Object -ExpandProperty DriveLetter | % { $_ + ":\" }

foreach ($DRIVE in $DRIVELIST) {
Start-Process $Ventdirectory\Ventoy2Disk.exe -i $DRIVE -s -g -L SCCMDrive
}

Write-Host "We're done! press a key to close this window. :)"
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") > $null


curl -s https://api.github.com/repos/ventoy/Ventoy/releases/latest | grep "browser_download_url.*linux.tar.gz*" | cut -d : -f 2,3 | tr -d \" | wget -i - -P $Ventdirectory
Ventscript=$(ls $Ventdirectory)

#Now we'll change directory to there, untar it, and remove the .tar.gz, then re-set the variable to stand for the new directory it creates and change directory to that.
cd $Ventdirectory && tar -xzf $Ventscript && rm $Ventscript
Ventscript=$(ls $Ventdirectory)
cd $Ventscript

#Now we'll get a list of all USB devices and place that into a temp file.
udevadm | pee "udevadm info --query=all --name=sd"{a..z} "udevadm info --query=all --name=sd"{a..z}{a..z} | grep -E \(S=usb\|\ sd\) | tr -d 'N: ' | tr -d 'E: ID_BUS=' | grep -B1 usb | grep sd > drivelist.temp

#Now we pass the yes command straight through xargs, with a seperate argument list (The list of USB drives) which it'll feed to the Ventoy Script to create SCCM drives with the storage partition of each named: SCCMDrive, then remove the list.
yes | xargs -a drivelist.temp -I{} -d'\n' zsh ./Ventoy2Disk.sh -I /dev/{} -s -g -L SCCMDrive
rm drivelist.temp

#Last we make a temp file of all mounted drives under /Media/$USR and order rsync to over-write all files on those partitions with everything in Ventoy.Export on my machine. Then we remove the temp list.
ls /media/$USR | grep SCCM | time parallel -j+0 --progress "rsync --info=progress2 -r /home/$USR/Downloads/Ventoy.Export/* /media/$USR/{}/"
