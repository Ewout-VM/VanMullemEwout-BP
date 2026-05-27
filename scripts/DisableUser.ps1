param(
    [string]$UPN,
    [string]$Reason,
    [string]$EndDate
)

Import-Module ActiveDirectory

# ============================================
# User ophalen via UPN
# ============================================

$User = Get-ADUser `
    -Filter "UserPrincipalName -eq '$UPN'" `
    -Properties MemberOf,Description

if (-not $User) {

    Write-Error "User not found: $UPN"
    Read-Host "Druk op ENTER om af te sluiten"
    exit
}

# ============================================
# Hide from GAL
# ============================================

try {

    Set-ADUser `
        -Identity $User `
        -Replace @{msExchHideFromAddressLists=$true}

    Write-Host "Hidden from GAL"
}
catch {

    Write-Warning "Failed to hide from GAL"
}

# ============================================
# Disable account
# ============================================

try {

    Disable-ADAccount -Identity $User

    Write-Host "Account disabled"
}
catch {

    Write-Warning "Failed to disable account"
}

# ============================================
# Description aanpassen
# ============================================

try {

    # Oude description ophalen
    $OldDescription = $User.Description

    # Datum formatteren
    $FormattedDate = (Get-Date $EndDate).ToString("dd/MM/yyyy")

    # Nieuwe description maken
    if ([string]::IsNullOrWhiteSpace($OldDescription)) {

        $NewDescription = "Uit dienst sinds $FormattedDate - $Reason"
    }
    else {

        $NewDescription = "$OldDescription | Uit dienst sinds $FormattedDate - $Reason"
    }

    # Description zetten
    Set-ADUser `
        -Identity $User `
        -Description $NewDescription

    Write-Host "Description updated"
}
catch {

    Write-Warning "Failed to update description"
}

# ============================================
# Groups behouden
# ============================================

$GroupsToKeep = @(
    "Domain Users"
)

# ============================================
# Groups verwijderen
# ============================================

Get-ADPrincipalGroupMembership $User | ForEach-Object {

    if ($GroupsToKeep -notcontains $_.Name) {

        try {

            Remove-ADGroupMember `
                -Identity $_ `
                -Members $User `
                -Confirm:$false `
                -ErrorAction Stop

            Write-Host "Removed from $($_.Name)"
        }
        catch {

            Write-Warning "Failed to remove from $($_.Name)"
        }
    }
}

# ============================================
# Klaar
# ============================================

Write-Host "Offboarding completed for $UPN"

Read-Host "Druk op ENTER om af te sluiten"