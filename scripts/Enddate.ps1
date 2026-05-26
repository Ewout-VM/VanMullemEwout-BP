Import-Module ActiveDirectory

$Sam = "%Username%"
$DateString = "%ExpirationDate%"

if (![string]::IsNullOrWhiteSpace($DateString)) {

    try {
        $DateObj = [datetime]::ParseExact($DateString, "yyyy-MM-dd", $null)
        $DateObj = $DateObj.AddDays(2)
        $DateObj = $DateObj.Date.AddHours(23).AddMinutes(59).AddSeconds(59)

        Set-ADAccountExpiration -Identity $Sam -DateTime $DateObj

        Write-Output "Expiration set to $DateObj"
    }
    catch {
        Write-Output "ERROR:"
        Write-Output $_
    }

} else {
    Write-Output "No expiration date provided"
}