# VMware Workstation for rapid kernel and driver debugging
This guide helps you create a Windows VM that allows you to debug the Windows kernel and drivers as fast as possible. The guide assumes you have a VMware workstation install although a few features may be present on other versions.  

## Prerequisites
* [VMware Workstation](https://www.vmware.com/products/workstation-pro.html)
* [Windows 10 image file](https://www.microsoft.com/de-de/software-download/windows10) - We'll be using Windows 10 Pro but any version should work
* A physical volume of at least 20MB accessible from your host. However, it is recommended to have over 100MB of free space on that volume. This volume will be used to copy the driver to the VM. This can either be in form of an external disk or a seperate volume on an internal disk. In my case I'm using my OS disk (NVMe) shrinked by 100MB and then mounted that free space to the drive letter `K:\`. You can perform these actions using the "Disk Management" tool on Windows.

## Environment
The following part of the guide assumes you have the installation directory of VMware Workstation in your `PATH` variable. We'll name the VM "win-kdbg". Substitute this with your own VM name. Additionally, we'll use the driver letter `K:\` on our host machine to make the drivers accessible to the VM. The guide assumes you have already created a volume with that drive letter.

## Creating the VM
1. **Start VMware Workstation as administrator**
2. Create the VM as you normally would (do not boot into Windows yet!). It is recommended keep all hardware requirements to a minimum
3. Go into the VM settings
4. Click "Add..." and select "Hard Disk"
5. You are free to use another disk type, however, NVMe (default option) is recommended
6. Pick "Use a physical disk (for advanced users)"
7. Select the disk that contains the `K:\` volume. The naming is most likely `PhysicalDriveN` where `N` corresponds to the disk number you see in `Disk Management`. Pick "Use individual partitions"
8. Select the prepared volume
9. Give it a name and finish

You are now ready to prepare Windows. Note that VMware may boot into a black screen once you have mounted a raw disk. This is normal, to fix this just reboot the VM.

## Preparing Windows
1. Install Windows as you normally would. It is recommended to license the VM
2. Install the VMware guest tools
3. Install all pending updates
4. Force Windows to ignore all startup and shutdown failures:
```batch
bcdedit /set {current} bootstatuspolicy ignoreallfailures
```
5. Disable integrity checks and enable test signing
```batch
bcdedit /set testsigning on
bcdedit /set nointegritychecks on
```
6. Disable UAC via registry editor:
```
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System > EnabledLUA = 0
```
7. Enable kernel debugging. Change `$HOSTIP` with your hosts IP address. Make sure the VM can ping the IP. `$HOSTPORT` should be replaced with the port that WinDbg will be listening on:
```batch
bcdedit /debug on
bcdedit /dbgsettings net hostip:$HOSTIP port:$HOSTPORT key:1.1.1.1
```
8. _Optional_: Allow the VM to redirect debug message (for example `DbgPrint`) to WinDbg. Create the key "Debug Print Filter" if it doesn't exist:
```
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Debug Print Filter > DEFAULT = 0xFFFFFFFF
```
9. Reassign the prepared raw disk to a fixed drive letter. Open the "Disk Management" utility and assign the drive letter `K:\` to the raw disk
10. Create a service for our driver and a scheduled task to load the driver on startup. It is recommended to use a generic name for the driver and then rename your driver to the generic name before deploying it to the VM:
```batch
sc create layle binPath= "K:\layle.sys" type= kernel
schtasks /create /sc onstart /tr "C:\onboot.bat" /tn driveronboot /ru SYSTEM /f
```
11. Create the file `C:\onboot.bat` with the following content. Again, make sure to replace `$HOSTIP` and `$HOSTPORT`:
```batch
bcdedit /dbgsettings net hostip:$HOSTIP port:$HOSTPORT key:1.1.1.1
sc start layle
```
12. Remove the user's password to avoid having to enter it every time you boot the VM

Finally, shutdown your VM. It is now ready to be used for kernel and driver debugging.

### Automating usermode applications (optional)
Chances are that you would like to execute commands and executable in usermode in an automated fashion. To do this you will have to install OpenSSH. However, to do this you'll need a "normal" ethernet adapter. You may have noticed that Windows reassigned your NAT adapter to a kernel debugging bridge. In your VMs settings, simply add a new NAT network adapter. Boot the VM and set the ethernet adapter to "Private". Now execute the following commands:
```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Set-Service -Name sshd -StartupType "Automatic"
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
```

If you set an empty password for the user you'll need to set the following registry key:
```
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa > LimitBlankPasswordUse = 0
```

Additionally, you have to set the following line in `C:\ProgramData\ssh\sshd_config`:
```
PermitEmptyPasswords yes
```

Once rebooted, you are able to execute commands to the VM over SSH.

## One last change
VMware can cause issues while kernel debugging. It tends to timeout the debugger's connection after a while of inactivity. To remediate this do the following (this setting persists across all VMs):
Open "Virtual Network Editor" and hit "Change Settings". Select NAT in the list and then "NAT Settings". Set "UDP timeout (in seconds)" to 32767.

## Usage
Now that you are all set you can edit the included `kdbg.bat` file. You want to replace the path with the path to your `.vmx` file. It is needed to boot up and shutdown the VM automatically. Depending on which name you used for your driver you may want to change that too.

## Credits
The idea is based off of [this](https://secret.club/2020/04/10/kernel_debugging_in_seconds.html) article. Some information has been directly copied from the article.