[CmdletBinding()]
param (
    [Switch]$NoRun,
    [Switch]$DownloadOnly
)

function CheckIfElevated () {
    $CurrentLogin = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $secprincipal = New-Object System.Security.Principal.WindowsPrincipal($CurrentLogin)
    $AdminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
    $IsAdmin = $secprincipal.IsInRole($AdminRole)
    if (-not $IsAdmin) {
        Write-Warning "This script must be run from an elevated shell."
        Write-Warning "Please restart Powershell using 'Run as Administrator'."
    }
    return $IsAdmin
}

function CheckIf64bit () {
    $is64bit = ($env:PROCESSOR_ARCHITECTURE -eq "AMD64")
    if (-not $is64bit) {
        Write-Warning "This script is only applicable on a 64-bit OS."
    }
    return $is64bit
}

function DownloadFile ($target, $url) {
    $webclient = New-Object System.Net.WebClient
    $filename = ($url -split '/')[-1]

    # Make sure $target exists and is an absolute path
    # (as $webclient.DownloadFile doesn't use the CWD)
    mkdir $target -ea 0 >$null
    $target = (Resolve-Path $target).Path

    $filepath = (Join-Path $target $filename)
    if (Test-Path $filepath) {
        Write-Host $filepath "already downloaded"
        return $filepath
    }

    # Download and retry up to $retry_attempts times in case of network transient errors.
    Write-Host -fore Yellow "Downloading" $filename
    Write-Host "Source:" $url
    $retry_attempts = 3
    for ($i=0; $i -lt $retry_attempts; $i++) {
        try {
            $webclient.DownloadFile($url, $filepath)
            break
        }
        Catch [Exception]{
            Start-Sleep 1
        }
   }
   Write-Host "File saved at" $filepath
   return $filepath
}

function RunInstaller ([String]$prog, [String]$installer, [String[]]$argv) {
    if ($installer -like '*.msi') {
        $argv = ('/I', $installer, $argv)
        $installer = 'msiexec.exe'
    }
    Write-Host -fore Yellow "Installing $prog ($installer $argv)"
    Start-Process -FilePath $installer -ArgumentList $argv -Wait
    Write-Host "Completed"
}

Function AddPathEntry ($dir) {
    if (!(Test-Path $dir)) {
        Write-Host -fore Red "$dir does not exist, cannot be added to PATH"
        return
    }

    $path = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($path | Select-String -SimpleMatch $dir) {
        return
    }

    $path = $path + ';' + $dir
    [Environment]::SetEnvironmentVariable("PATH", $path, "Machine")
}

function RunPythonInstaller ($ver) {
    $v2 = (($ver -split '\.')[0,1] -join '')
    # Must do 64-bit before 32-bit because of a bug installing 32-bit first
    RunInstaller "Python $ver (64-bit)" Installers\python-$ver.amd64.msi '/qn',"TARGETDIR=C:\Python$v2-64"
    RunInstaller "Python $ver (32-bit)" Installers\python-$ver.msi '/qn',"TARGETDIR=C:\Python$v2-32"
}

$pyversions = ('2.7.8', '3.3.5', '3.4.2')

function Download7Zip () {
    DownloadFile Installers http://downloads.sourceforge.net/sevenzip/7z920-x64.msi
}

function DownloadVCS () {
    DownloadFile Installers http://mercurial.selenic.com/release/windows/mercurial-3.2.1-x64.msi
    DownloadFile Installers https://github.com/msysgit/msysgit/releases/download/Git-1.9.4-preview20140929/PortableGit-1.9.4-preview20140929.7z
}

function DownloadMSFiles () {
    DownloadFile Installers http://download.microsoft.com/download/F/1/0/F10113F5-B750-4969-A255-274341AC6BCE/GRMSDKX_EN_DVD.iso
    DownloadFile Installers http://download.microsoft.com/download/9/5/A/95A9616B-7A37-4AF6-BC36-D6EA96C8DAAE/dotNetFx40_Full_x86_x64.exe
    DownloadFile Installers http://download.microsoft.com/download/7/9/6/796EF2E4-801B-4FC4-AB28-B59FBF6D907B/VCForPython27.msi
    DownloadFile Installers http://download.microsoft.com/download/d/d/9/dd9a82d0-52ef-40db-8dab-795376989c03/vcredist_x86.exe
    DownloadFile Installers http://download.microsoft.com/download/2/d/6/2d61c766-107b-409d-8fba-c39e61ca08e8/vcredist_x64.exe
}

function DownloadPython() {
    foreach ($ver in $pyversions) {
        DownloadFile Installers "https://www.python.org/ftp/python/$ver/python-$ver.msi"
        DownloadFile Installers "https://www.python.org/ftp/python/$ver/python-$ver.amd64.msi"
    }
    DownloadFile Installers https://bootstrap.pypa.io/get-pip.py
}

function DownloadOthers() {
    DownloadFile Installers http://download.tuxfamily.org/notepadplus/6.6.9/npp.6.6.9.Installer.exe
}

function DownloadAll () {
    Download7Zip
    DownloadVCS
    DownloadMSFiles
    DownloadPython
    DownloadOthers
}

function Install7Zip () {
    RunInstaller "7-Zip" Installers\7z920-x64.msi '/qn'
}

function InstallVCS () {
    RunInstaller "Mercurial" Installers\mercurial-3.2.0-x64.msi '/qn'
    $7z = "C:\Program Files\7-zip\7z.exe"
    & $7z x "-oC:\Program Files\Git" Installers\PortableGit-1.9.4-preview20140929.7z >$null
    AddPathEntry "C:\Program Files\Git\cmd"
}

function InstallOthers {
    RunInstaller "Notepad++" Installers\npp.6.6.9.Installer.exe '/S'
}

function UnpackISO () {
    if (Test-Path Installers\SDK) {
        Write-Host "SDK already unpacked"
        return
    }
    if (! (Test-Path "C:\Program Files\7-Zip\7z.exe")) {
        Write-Host -Fore Red "7-Zip is not available - unpack skipped"
        return
    }
    & "C:\Program Files\7-zip\7z.exe" x -oInstallers\SDK Installers\GRMSDKX_EN_DVD.iso
}

function InstallMSFiles () {
    RunInstaller ".NET Framework" Installers\dotNetFx40_Full_x86_x64.exe '/q','/norestart'
    RunInstaller "SDK 7.1" Installers\SDK\setup.exe '-q','-params:ADDLOCAL=ALL'
    RunInstaller "VC for Python" Installers\VCForPython27.msi '/qn'
    RunInstaller "VC 2008 redist (32 bit)" Installers\vcredist_x86.exe '/q'
    RunInstaller "VC 2008 redist (64 bit)" Installers\vcredist_x64.exe '/q'
}

function InstallPython () {
    foreach ($ver in $pyversions) {
        RunPythonInstaller $ver
    }
}

function InstallPythonPackages () {
    foreach ($ver in $pyversions) {
        $v2 = (($ver -split '\.')[0,1] -join '')
        foreach ($bits in ('32', '64')) {
            Write-Host -fore Yellow "Installing pip, setuptools and wheel in Python $ver ($bits bits)"
            if (-not (Test-Path "C:\Python$v2-$bits\Scripts\pip.exe")) {
                & "C:\Python$v2-$bits\python.exe" Installers\get-pip.py
            }
            & "C:\Python$v2-$bits\python.exe" -m pip install -U pip setuptools wheel
            Write-Host "Complete"
        }
    }
}

function WriteSiteCustomize () {

    $sitecustomize = @'
import os
import platform
import subprocess

arch = 'x86' if platform.architecture()[0] == '32bit' else 'x64'

batfile = 'C:\\Program Files\\Microsoft SDKs\\Windows\\v7.1\\Bin\\SetEnv.cmd'
cmd = '"{}" /Release /{} & set'.format(batfile, arch)
output = subprocess.check_output(cmd, stderr=subprocess.STDOUT, universal_newlines=True)

env = dict([l.split('=',1) for l in output.splitlines() if '=' in l])
os.environ.update(env)
os.environ['DISTUTILS_USE_SDK'] = '1'
'@

    # Only for Python 3.3 and 3.4 as those are the only ones using VS 2010
    foreach ($v2 in ('33', '34')) {
        foreach ($bits in ('32', '64')) {
            Write-Host -fore Yellow "Writing sitecustomize in C:\Python$v2-$bits"
            $filename = "C:\Python$v2-$bits\Lib\sitecustomize.py"
            Set-Content $filename $sitecustomize -Encoding ASCII
        }
    }
}

function CreateLibDirectory () {
    Write-Host -fore Yellow "Creating library directory"
    mkdir -ea 0 C:\Libraries\Include >$null
    mkdir -ea 0 C:\Libraries\Lib32 >$null
    mkdir -ea 0 C:\Libraries\Lib64 >$null

    $distutils_cfg = @"
[build_ext]
include_dirs=C:\Libraries\Include
library_dirs=C:\Libraries\Lib{0}
"@

    foreach ($ver in $pyversions) {
        $v2 = (($ver -split '\.')[0,1] -join '')
        foreach ($bits in ('32', '64')) {
            Write-Host "Writing distutils.cfg in C:\Python$v2-$bits"
            $filename = "C:\Python$v2-$bits\Lib\distutils\distutils.cfg"
            Set-Content $filename ($distutils_cfg -f $bits) -Encoding ASCII
        }
    }
}

function TestInstallation () {
    del -rec -ea 0 wheelhouse
    foreach ($ver in $pyversions) {
        $v2 = (($ver -split '\.')[0,1] -join '')
        foreach ($bits in ('32', '64')) {
            Write-Host -fore Yellow "Testing Python $ver ($bits bits)"
            & "C:\Python$v2-$bits\Scripts\pip.exe" wheel blist
        }
    }
    dir wheelhouse
}

function Main () {
    if (-not (CheckIfElevated)) {
        Write-Host -Fore Red "This script must be run as administrator"
        return
    }
    if (-not (CheckIf64bit)) {
        Write-Host -Fore Red "This script must be run on a 64 bit OS"
        return
    }
    DownloadAll
    Install7Zip
    UnpackISO
    InstallMSFiles
    InstallPython
    InstallPythonPackages
    WriteSiteCustomize
    CreateLibDirectory
    InstallVCS
    InstallOthers

    Write-Host -NoNewline "To test, run "
    Write-Host -Fore Yellow "TestInstallation"
}

if ($DownloadOnly) {
    DownloadAll
    UnpackISO
} elseif (! $NoRun) {
    Main
}
