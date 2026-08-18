param(
    [string]$UPN,
    [string]$Mailboxes,
    [string]$DistributionLists
)
Import-Module ExchangeOnlineManagement

$ProgressPreference = 'SilentlyContinue'

Connect-ExchangeOnline -ShowBanner:$false

# =========================
# Shared Mailboxes
# =========================

if (![string]::IsNullOrWhiteSpace($Mailboxes)) {

    $MailboxList = $Mailboxes.Trim("[]") -split ","

    foreach ($sharedMailbox in $MailboxList) {

        $sharedMailbox = $sharedMailbox.Trim(" ","'","[","]")

        if ($sharedMailbox -ne "") {

            Write-Host "Mailbox permissions for $sharedMailbox"
            try {

                Add-MailboxPermission `
                    -Identity $sharedMailbox `
                    -User $UPN `
                    -AccessRights FullAccess `
                    -InheritanceType All `
                    -Confirm:$false `
                    -ErrorAction Stop | Out-Null

                Write-Host "FullAccess added"
            }
            catch {

                Write-Warning "Failed FullAccess for $sharedMailbox"
                Write-Warning $_.Exception.Message
            }

            # =========================
            # Send On Behalf Retry Loop
            # =========================

            $MaxAttempts = 10
            $Attempt = 0
            $Success = $false

            while (-not $Success -and $Attempt -lt $MaxAttempts) {

                try {
                    Write-Host "Trying SendOnBehalf for $sharedMailbox"

                    Set-Mailbox `
                        -Identity $sharedMailbox `
                        -GrantSendOnBehalfTo @{Add=$UPN} `
                        -Confirm:$false `
                        -ErrorAction Stop | Out-Null

                    Write-Host "SendOnBehalf added"

                    $Success = $true
                }
                catch {
                    $Attempt++

                    Write-Warning "Mailbox not ready yet. Attempt $Attempt/$MaxAttempts"
                    Write-Warning $_.Exception.Message

                    Start-Sleep -Seconds 60
                }
            }
            if (-not $Success) {

                Write-Warning "Failed SendOnBehalf after multiple attempts for $sharedMailbox"
            }
            Write-Host "Mailbox done"
        }
    }
}

# =========================
# Distribution Groups
# =========================

$DefaultDLs = @(
    "iedereen@berlare.be",
    "viruswaarschuwing@berlare.be"
)

$ExtraDLs = @()

if (![string]::IsNullOrWhiteSpace($DistributionLists)) {

    $ExtraDLs = $DistributionLists.Trim("[]") -split ","
}

$AllDLs = @()
$AllDLs += $DefaultDLs
$AllDLs += $ExtraDLs

foreach ($dl in $AllDLs) {

    $dl = $dl.Trim(" ","'","[","]")

    if ($dl -ne "") {

        Write-Host "Adding $UPN to distribution group $dl"

        try {
            Add-DistributionGroupMember `
                -Identity $dl `
                -Member $UPN `
                -BypassSecurityGroupManagerCheck `
                -ErrorAction Stop | Out-Null

            Write-Host "Distribution group done"
        }
        catch {

            Write-Warning "Failed to add $UPN to $dl"
            Write-Warning $_.Exception.Message
        }
    }
}

Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue