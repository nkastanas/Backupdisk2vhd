# Null all the values
$SourceDisk = $null
$TargetDisk = $null
$SourceCapacity =  $null
$SourceDiskFree =  $null
$SourceDiskUSed =  $null
$filename =  $null
$MapDrive = $null
$SourceDrive = "C:" #Drive letter of disk to convert to vhdx
$TargetDrive = "X:" #Drive letter of target to calculate free space
$Hidden = "False"    #Choose vhd creation type (visivble process or not), True needs administrator privileges.
$TargetPath = "\\backupsrv\zfs_storage\Backups\" #Destination path


#This function is called to determine the used space on the C: drive
function UsedDiskSpace() {
$SourceDisk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$SourceDrive'" | Select-Object Size,FreeSpace
$SourceCapacity = $SourceDisk.size/1073741824
$SourceDiskFree = $SourceDisk.freespace/1073741824
$sourceDiskUSed = $SourceCapacity-$SourceDiskFree
return $SourceDiskUsed
}


#This function is called repeatedly until the space on the X: (TARGET) drive is greater than the used space on the C: drive
function FreeDiskSpace() {
$TargetDisk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$TargetDrive'" | Select-Object Size,FreeSpace
$TargetDisk = $TargetDisk.freespace/1073741824
return $TargetDisk
}


# #This function will simply delete the oldest file in the root of the F: drive
Function DelVHD {
Get-ChildItem -path $TargetPath -Filter Backup-$Env:COMPUTERNAME*.vhd?  | Sort CreationTime | Select -First 1 | Remove-Item -Force -Recurse -Confirm:$True
}


#Create the VHD - pass $true to run the Disk2VHD program hidden; $False for visible. First run should be false to allow agreement of EULA.!
Function CreateVHD($Hidden) {
$filename =  "Backup-" + $Env:COMPUTERNAME + "_" + (get-date -uformat %d%m%y) + ".vhd"
$Target = $TargetPath+$Filename
    If ($Hidden -eq $True){
        #write-host "start-process -Wait -WindowStyle Hidden \Toolbox\disk2vhd.exe -argumentlist '$SourceDrive', $Target"
        start-process -Wait -WindowStyle Hidden \Toolbox\disk2vhd.exe -argumentlist '$SourceDrive', $Target
    }
        
        #ElseIf ($Hidden -eq $False){write-host ".\disk2vhd.exe $SourceDrive $Target"
        ElseIf ($Hidden -eq $False){.\disk2vhd.exe $SourceDrive $Target
    }
}


##START
#Enable-PSRemoting -Force
#check for the correct mapdrive and create if missing
$MapDrive = $TargetDrive.Substring(0,1)
If (-not(Get-PSDrive $MapDrive)){New-PSDrive -Name $MapDrive -PSProvider "FileSystem" -Root "\\backupsrv\zfs_storage\Backups\"}

#This loop kicks everything off - it gets the free disk space, deletes files one at a time as required and then creates the VHD when there is sufficient disk space freed up.
Do {
$UsedDiskSpace = UsedDiskSpace
$FreeDiskSpace = FreeDiskSpace


if ($FreeDiskSpace -lt $UsedDiskSpace) {

Write-Host "Space used on " $sourceDrive " = "$UsedDiskSpace
Write-Host "Free space on " $TargetDrive " = "$FreeDiskSpace
Write-Host "Not enough free space on" $TargetDrive " Drive. Deleting oldest backup"
DelVHD
}
}
until ($FreeDiskSpace -gt $UsedDiskSpace)


Write-Host "A new backup will be created for this OS in " $TargetPath
#NOTE - Run with $False so the Disk2VHD window is visible at least the first time in order to accept the EULA
#CreateVHD $True
CreateVHD $Hidden
if ( $? -eq $false ) {
    Out-Host "BACKUP FAILED" + $LastExitCode
}