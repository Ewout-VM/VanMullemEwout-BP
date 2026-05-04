param(
    [string]$FirstName,
    [string]$LastName,
    [string]$Department,
    [string]$Site,
    [string]$Role,
    [string]$Telephone,
    [string]$Title
)

# ===== STREAM CONTROL VOOR POWER AUTOMATE =====
$WarningPreference     = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
$VerbosePreference     = 'SilentlyContinue'
$DebugPreference       = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'

Import-Module ActiveDirectory

# ===== CONFIG =====
$UPNSuffix = "intranet.berlare.be"
$LogFile   = "C:\Automation\Provisioning.log"

# Root OU
$BaseOU = "OU=Berlare Gemeente,DC=intranet,DC=berlare,DC=be"
$UsersOUName = "OU=Users"

# Role -> AD Group mapping
$RoleGroups = @{
    "IT-USER"  = @("GG_GE_Informatica")
    "HR-USER"  = @("GG_GE_Per")
    "OP-USER"  = @("GG_GE_MEDEWERKERS_R&O")
    "CU-USER"  = @("GG_GE_CUL")
    "FI-USER"  = @("GG_GE_FINANCIEN")
    "BZ-USER"  = @("GG_GE_BEV")
    "BS-USER"  = @("GG_GE_BS")
    "BIB-USER" = @("GG_GE_BIB")
    "IBO-USER" = @("GG_GE_IBO")
    "OW-USER"  = @("GG_GE_OW")
    "IZ-USER"  = @("GG_GE_SEC")
    "VE-USER"  = @("GG_GE_VERGUNNINGEN")
}

# Start-Transcript -Path $LogFile -Append

try {

    # ===== Clean input =====
    $First = $FirstName.Trim()
    $Last  = $LastName.Trim()

    $Site       = $Site.Trim()
    $Department = $Department.Trim()
    $Role       = $Role.Trim().ToUpper()

    # ===== Speciale tekens verwijderen (é, ë, …) =====
    $FirstClean = $First.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''
    $LastClean  = $Last.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''

    # ===== Niet-letters verwijderen =====
    $FirstClean = $FirstClean -replace '[^a-zA-Z]', ''
    $LastClean  = $LastClean -replace '[^a-zA-Z]', ''

    # ===== Velden opbouwen =====
    $Sam = ($LastClean + $FirstClean.Substring(0,1)).ToLower()
    $Email = ($FirstClean + "." + $LastClean + "@berlare.be").ToLower()

    $DisplayName = "$First $Last"
    $Description = $Title
    $Company     = "Berlare"

    Write-Host "Processing $DisplayName" -ForegroundColor Cyan
    Write-Host "SAM: $Sam" -ForegroundColor DarkGray
    Write-Host "UPN: $Email" -ForegroundColor DarkGray
    Write-Host "Site='$Site' Department='$Department'" -ForegroundColor DarkGray

    # ===== Duplicate check =====
    $Existing = Get-ADUser -Filter "SamAccountName -eq '$Sam'" -ErrorAction SilentlyContinue
    if ($Existing) {
        Write-Warning "User $Sam already exists - stopping script"
        return
    }

    # ===== Build OU paths =====
    $DeptOU = "$UsersOUName,OU=$Department,OU=Site $Site,$BaseOU"
    $SiteOU = "$UsersOUName,OU=Site $Site,$BaseOU"

    $TargetOU = $null

    # ===== Smart OU detection =====
    if ($Department -eq $Site) {

        Write-Host "Department equals site - using site OU directly" -ForegroundColor Yellow

        $SiteCheck = Get-ADOrganizationalUnit -Identity $SiteOU -ErrorAction SilentlyContinue
        if ($SiteCheck) {
            $TargetOU = $SiteOU
        }
        else {
            Write-Error "Site OU not found for Site='$Site'"
            return
        }
    }
    else {

        $DeptCheck = Get-ADOrganizationalUnit -Identity $DeptOU -ErrorAction SilentlyContinue
        if ($DeptCheck) {
            $TargetOU = $DeptOU
            Write-Host "Using department OU" -ForegroundColor Green
        }
        else {
            $SiteCheck = Get-ADOrganizationalUnit -Identity $SiteOU -ErrorAction SilentlyContinue
            if ($SiteCheck) {
                $TargetOU = $SiteOU
                Write-Host "Department OU not found, using site OU" -ForegroundColor Yellow
            }
            else {
                Write-Error "OU not found for Site='$Site' Department='$Department'"
                return
            }
        }
    }

    # ===== Password =====
    $Password = ConvertTo-SecureString "TempP@ss123!" -AsPlainText -Force

    # ===== Create user =====
    try {
        New-ADUser `
            -Name $DisplayName `
            -GivenName $First `
            -Surname $Last `
            -DisplayName $DisplayName `
            -SamAccountName $Sam `
            -UserPrincipalName $Email `
            -EmailAddress $Email `
            -OfficePhone $Telephone `
            -Department $Department `
            -Title $Title `
            -Description $Description `
            -Company $Company `
            -AccountPassword $Password `
            -Enabled $true `
            -Path $TargetOU `
            -ChangePasswordAtLogon $true

        Write-Host "User created in $TargetOU" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create user $Sam : $_"
        return
    }

    # ===== Group assignment =====

    $DefaultGroups = @(
        "SEC_DR_Data2",
        "GG_GE_UNIFLOW",
        "SEC_DR_Fotoarchief"
    )

    $AllGroups = @()
    $AllGroups += $DefaultGroups

    if ($RoleGroups.ContainsKey($Role)) {
        $AllGroups += $RoleGroups[$Role]
    }
    else {
        Write-Warning "Unknown role: $Role"
    }

    foreach ($Group in $AllGroups) {
        try {
            Add-ADGroupMember -Identity $Group -Members $Sam
            Write-Host " -> Added to group $Group" -ForegroundColor DarkCyan
        }
        catch {
            Write-Warning "Failed to add $Sam to $Group"
        }
    }

}
catch {
    Write-Error $_
}
finally {
    # Stop-Transcript
}

# ===== OUTPUT VOOR POWER AUTOMATE =====

$Result = [PSCustomObject]@{
    UPN = $Email
}

$JsonPath = "C:\Automation\PA_Output.json"
$Result | ConvertTo-Json -Compress | Set-Content -Path $JsonPath -Encoding UTF8