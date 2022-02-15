#!/usr/bin/pwsh

#
# To enable running PowerShell scripts, run the command below on a PowerShell shell:
#
#   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#

#
# Semantic Version Helper Script for Git
#

param
(
    [string]$command = "help",
    [Switch]$debug = $false
)

function Debug
{
    param
    (
        [string] $msg = $null
    )

    if ($debug)
    {
        $caller = (Get-Variable MyInvocation -Scope 1).Value.MyCommand.Name
        if ($caller -eq $null)
        {
            $caller = "---"
        }

        Write-Host("::debug::{0}::{1}" -f $caller, $msg)
    }
}

#
# The Semantic Version part
#
Enum SemVerPart
{
    Major
    Minor
    Patch
    ReleaseKind
    ReleaseId
}

#
# Semantic Version ReleaseKind Kind
#
Enum ReleaseKind
{
    Unknown = 0

    WIP = 1
    Dev = 2
    Alpha = 3
    Beta = 4
    RC = 5

    Release = 99999
}

#
# Semantic Version Object
#
Class SemVer : System.IComparable
{
    [int] $Major
    [int] $Minor
    [int] $Patch
    [ReleaseKind] $ReleaseKind
    [int] $ReleaseId

    SemVer([int] $major, [int] $minor, [int] $patch)
    {
        $this.Major = $major
        $this.Minor = $minor
        $this.Patch = $patch
        $this.ReleaseKind = [ReleaseKind]::Release
        $this.ReleaseId = 0

        Debug($this)
    }

    SemVer([int] $major, [int] $minor, [int] $patch, [ReleaseKind] $kind, [int] $id)
    {
        $this.Major = $major
        $this.Minor = $minor
        $this.Patch = $patch
        $this.ReleaseKind = $kind
        $this.ReleaseId = $id

        Debug($this)
    }

    Increment([SemVerPart] $part)
    {
        switch ($part)
        {
            Major
            {
                $this.Major++
                $this.Minor = 0
                $this.Patch = 0
                $this.ReleaseKind = [ReleaseKind]::Release
                $this.ReleaseId = 0
            }
            Minor
            {
                $this.Minor++
                $this.Patch = 0
                $this.ReleaseKind = [ReleaseKind]::Release
                $this.ReleaseId = 0
            }
            Patch
            {
                $this.Patch++
                $this.ReleaseKind = [ReleaseKind]::Release
                $this.ReleaseId = 0
            }
            ReleaseId
            {
                $this.ReleaseId++
            }
        }
    }

    [bool] Equals($that)
    {
        return $this.CompareTo($that) -eq 0
    }

    [int] CompareTo($that)
    {
        If (-Not($that -is [SemVer])) {
            Throw "Not comparable!!"
        }

        $result = 0

        $result =  $this.Major.CompareTo($that.Major)

        if ($result -ne 0)
        {
            return $result
        }

        $result = $this.Minor.CompareTo($that.Minor)

        if ($result -ne 0)
        {
            return $result
        }

        $result = $this.Patch.CompareTo($that.Patch)

        if ($result -ne 0)
        {
            return $result
        }

        $result = $this.ReleaseId.CompareTo($that.ReleaseId)

        return $result
    }

    [String] ToString()
    {
        $version = "{0}.{1}.{2}" -f $this.Major, $this.Minor, $this.Patch

        if ($this.ReleaseKind -eq [ReleaseKind]::Release)
        {
            return $version
        }

        if ($this.ReleaseKind -ne [ReleaseKind]::Unknown)
        {
            $version += ("-{0}.{1}" -f $this.ReleaseKind, $this.ReleaseId).ToLower()
        }
        else
        {
            $version += ("-{0}" -f $this.ReleaseId)
        }

        return $version
    }

    [SemVer] static Copy([SemVer] $version)
    {
        $copy = [SemVer]::new($version.Major, $version.Minor, $version.Patch)

        if ($version.ReleaseKind -ne [ReleaseKind]::Release)
        {
            $copy.ReleaseKind = $version.ReleaseKind
            $copy.ReleaseId = $version.ReleaseId
        }

        return $copy
    }

    [SemVer] static Parse([String] $version)
    {
        $version = ($version.Split("/") | Select-Object -Last 1)

        Debug("[SemVer]::Parse {0}" -f $version)

        $version -match "^v?(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?(\-(?<pre>[0-9A-Za-z\-\.]+))?$" | Out-Null

        if ($matches -eq $null)
        {
            return $null
        }

        $RetVersion = [SemVer]::new([int]$matches['major'], [int]$matches['minor'], [int]$matches['patch'])

        if ($matches['pre'] -eq $null)
        {
            return $RetVersion
        }

        $pre = $matches['pre'].Split(".")
        $preReleaseVersionStr = ""

        Debug($pre)

        if ($pre.Length -eq 2)
        {
            try
            {
                $RetVersion.ReleaseKind = $pre[0]
            }
            catch
            {
                $RetVersion.ReleaseKind = [ReleaseKind]::Unknown
            }

            $preReleaseVersionStr = $pre[1]
        }
        else
        {
            $preReleaseVersionStr = $pre[0]
        }

        try
        {
            $RetVersion.ReleaseId = [int] $preReleaseVersionStr
        }
        catch {}

        return $RetVersion
    }
}

function ToSemVer
{
    param
    (
        [Switch]$includePreRelease
    )

    process
    {
        Debug("'{0}' {1}" -f $_, $includePreRelease)

        $version = [SemVer]::Parse($_)

        if ($includePreRelease -or $version.ReleaseKind -eq [ReleaseKind]::Release)
        {
            Write-Output $version
        }
    }
}

function NotNullOrEmpty
{
    process
    {
        if ($_ -ne $null -and $_ -ne "")
        {
            $_ | Write-Output
        }
    }
}

#
# Git Helpers
#
function Git-CommitHistory
{
    process
    {
        Debug("")

        -Split ((git log --pretty=format:"%H") | Out-String) | NotNullOrEmpty | Write-Output
    }
}

function Git-Fetch
{
    Debug("")

    (git fetch)
}

function Git-CommitRef
{
    process
    {
        Debug("'{0}'" -f $_)

        -Split ((git tag --points-at $_) | Out-String).Trim() | NotNullOrEmpty | Write-Output
        -Split ((git branch --format='%(refname:short)' --points-at $_) | Out-String).Trim() | NotNullOrEmpty | Write-Output
    }
}

function Git-Tag
{
    param
    (
        [String]$tag
    )

    if (NotNullOrEmpty($tag))
    {
        return
    }

    (git tag $tag)
}

function Git-Tags
{
    process
    {
        Debug("")

        -Split ((git tag -l) | Out-String) | NotNullOrEmpty | Write-Output
    }
}

function Git-TagDelete
{
    process
    {
        Debug("'{0}'" -f $_)

        (git tag -d $_)
    }
}

function Git-Branches
{
    process
    {
        Debug("")

        -Split ((git branch -l --format='%(refname:short)') | Out-String) | NotNullOrEmpty | Write-Output
    }
}

function Version-Last
{
    param
    (
        [Switch]$includePreRelease
    )

    $version = (Git-Tags | ToSemVer -IncludePreRelease:$includePreRelease | Sort-Object | Select-Object -Last 1)

    if ($version -eq $null)
    {
        $version = [SemVer]::Parse("0.0.0")
    }

    Write-Output $version
}

function Version-Next
{
    param
    (
        [ReleaseKind]$kind = [ReleaseKind]::Release,
        [Switch]$tag = $false,
        [String]$tagPrefix = "v"
    )

    $includePreRelease = $kind -ne [ReleaseKind]::Release

    $allVersions = Git-Tags | ToSemVer -IncludePreRelease:$includePreRelease | Sort-Object
    $baseVersion = Git-CommitHistory | Git-CommitRef | ToSemVer -IncludePreRelease:$includePreRelease | Sort-Object | Select-Object -Last 1

    if ($baseVersion -eq $null)
    {
        $baseVersion = Version-Last
    }

    $version = [SemVer]::Copy($baseVersion)

    Debug("baseVersion: {0}" -f $baseVersion)

    if ($version.ReleaseKind -eq [ReleaseKind]::Release -and $kind -ne [ReleaseKind]::Release)
    {
        Debug("Increase Patch")
        $version.Increment([SemVerPart]::Patch)
    }
    elseif ($kind -ne [ReleaseKind]::Release)
    {
        Debug("Increase ReleaseId")
        $version.Increment([SemVerPart]::ReleaseId)
    }

    $version.ReleaseKind = $kind

    while ($version -in $allVersions)
    {
        if ($version.ReleaseKind -eq [ReleaseKind]::Release)
        {
            $version.Increment([SemVerPart]::Patch)
        }
        else
        {
            $version.Increment([SemVerPart]::ReleaseId)
        }
    }

    if ($tag)
    {
        Git-Tag ("{0}{1}" -f $tagPrefix, $version)
    }

    return $version
}

switch($command)
{
    "help"
    {
        Write-Host ""
        Write-Host "StruxHub Version Tools"
        Write-Host ""
        Write-Host "Use:"
        Write-Host " ./version-tool.ps1 <command>"
        Write-Host ""
        Write-Host "Where <command> can be:"
        Write-Host ""
        Write-Host "    latest-version      Print the latest tagged release version (from Git)"
        Write-Host "    latest-pre-version  Print the latest tagged pre-release version (from Git)"
        Write-Host "    next-version        Print the next release version (from Git)"
        Write-Host "    next-dev-version    Print the next dev pre-release version (from Git)"
        Write-Host "    next-beta-version   Print the next beta pre-release version (from Git)"
        Write-Host "    next-rc-version     Print the next rc pre-release version (from Git)"
        Write-Host "    list-versions       Print all version tagged in Git"
        Write-Host ""
    }
    "latest-version"
    {
        Version-Last | Write-Host
    }
    "latest-pre-version"
    {
        Version-Last -IncludePreRelease | Write-Host
    }
    "next-version"
    {
        Version-Next | Write-Host
    }
    "next-dev-version"
    {
        Version-Next -Kind Dev | Write-Host
    }
    "next-beta-version"
    {
        Version-Next -Kind Beta | Write-Host
    }
    "next-rc-version"
    {
        Version-Next -Kind RC | Write-Host
    }
    "list-versions"
    {
        Git-Tags | ToSemVer -IncludePreRelease | Sort-Object | Write-Host
    }
}