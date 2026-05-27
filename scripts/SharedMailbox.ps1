param(
    [string]$UPN
)

Import-Module ExchangeOnlineManagement

Connect-ExchangeOnline

# Mailbox ophalen
$UserMailbox = Get-Mailbox -Identity $UPN

# Convert naar shared mailbox
Set-Mailbox `
    -Identity $UserMailbox.PrimarySmtpAddress `
    -Type Shared

Write-Host "Mailbox converted to shared"

# ============================================
# FULL ACCESS verwijderen
# ============================================

Get-Mailbox -ResultSize Unlimited | ForEach-Object {

    $Mailbox = $_

    $Permissions = Get-MailboxPermission `
        -Identity $Mailbox.PrimarySmtpAddress |
        Where-Object {
            $_.User -like $UPN -and
            $_.AccessRights -contains "FullAccess"
        }

    if ($Permissions) {

        try {

            Remove-MailboxPermission `
                -Identity $Mailbox.PrimarySmtpAddress `
                -User $UPN `
                -AccessRights FullAccess `
                -InheritanceType All `
                -Confirm:$false

            Write-Host "Removed FullAccess from $($Mailbox.PrimarySmtpAddress)"
        }
        catch {

            Write-Warning "Failed FullAccess removal on $($Mailbox.PrimarySmtpAddress)"
        }
    }
}

# ============================================
# SEND ON BEHALF verwijderen
# ============================================

Get-Mailbox -ResultSize Unlimited | ForEach-Object {

    $Mailbox = $_

    if ($Mailbox.GrantSendOnBehalfTo -contains $UserMailbox.DistinguishedName) {

        try {

            Set-Mailbox `
                -Identity $Mailbox.PrimarySmtpAddress `
                -GrantSendOnBehalfTo @{
                    Remove = $UserMailbox.DistinguishedName
                }

            Write-Host "Removed SendOnBehalf from $($Mailbox.PrimarySmtpAddress)"
        }
        catch {

            Write-Warning "Failed SendOnBehalf removal on $($Mailbox.PrimarySmtpAddress)"
        }
    }
}

# ============================================
# DISTRIBUTIEGROEPEN verwijderen
# ============================================

Get-DistributionGroup -ResultSize Unlimited | ForEach-Object {

    try {

        Remove-DistributionGroupMember `
            -Identity $_.PrimarySmtpAddress `
            -Member $UPN `
            -Confirm:$false `
            -BypassSecurityGroupManagerCheck `
            -ErrorAction Stop

        Write-Host "Removed from distribution group $($_.PrimarySmtpAddress)"
    }
    catch {}
}

Disconnect-ExchangeOnline -Confirm:$false