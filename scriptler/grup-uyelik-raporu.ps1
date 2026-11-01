<#
.SYNOPSIS
    Bir veya daha fazla AD grubunun üyelerini raporlar (iç içe gruplar dahil).
.DESCRIPTION
    Belirtilen gruplar veya duyarlı (ayrıcalıklı) gruplar için üyeleri listeler.
    -IcIce ile iç içe grup üyeleri de açılır. Salt-okunur çalışır.
.PARAMETER Grup
    Rapor alınacak grup adları. Verilmezse ayrıcalıklı gruplar kullanılır.
.PARAMETER IcIce
    İç içe grup üyeliklerini de listeler (LDAP_MATCHING_RULE_IN_CHAIN).
.PARAMETER CsvYolu
    Rapor CSV yolu.
.EXAMPLE
    .\grup-uyelik-raporu.ps1 -Grup 'Domain Admins','GG-Muhasebe' -IcIce
.EXAMPLE
    .\grup-uyelik-raporu.ps1 -CsvYolu .\ayricalikli-gruplar.csv
#>
#Requires -Modules ActiveDirectory
[CmdletBinding()]
param(
    [string[]]$Grup = @('Domain Admins', 'Enterprise Admins', 'Schema Admins', 'Administrators', 'Account Operators', 'Backup Operators', 'Server Operators'),
    [switch]$IcIce,
    [string]$CsvYolu
)

$rapor = foreach ($g in $Grup) {
    try {
        $grupNesnesi = Get-ADGroup -Identity $g -ErrorAction Stop
    }
    catch {
        Write-Warning "Grup bulunamadı: $g"
        continue
    }

    if ($IcIce) {
        $uyeler = Get-ADUser -LDAPFilter "(memberOf:1.2.840.113556.1.4.1941:=$($grupNesnesi.DistinguishedName))" `
            -Properties Enabled, LastLogonTimestamp, PasswordLastSet
        foreach ($u in $uyeler) {
            [pscustomobject]@{
                Grup = $g; Uye = $u.SamAccountName; Tur = 'user (dahil iç içe)'
                Etkin = $u.Enabled
                SonOturum = if ($u.LastLogonTimestamp) { [datetime]::FromFileTime($u.LastLogonTimestamp) } else { $null }
                ParolaSonDegisim = $u.PasswordLastSet
            }
        }
    }
    else {
        foreach ($u in (Get-ADGroupMember -Identity $grupNesnesi)) {
            $ek = $null
            if ($u.objectClass -eq 'user') {
                $ek = Get-ADUser -Identity $u.DistinguishedName -Properties Enabled, LastLogonTimestamp, PasswordLastSet
            }
            [pscustomobject]@{
                Grup = $g; Uye = $u.SamAccountName; Tur = $u.objectClass
                Etkin = if ($ek) { $ek.Enabled } else { $null }
                SonOturum = if ($ek -and $ek.LastLogonTimestamp) { [datetime]::FromFileTime($ek.LastLogonTimestamp) } else { $null }
                ParolaSonDegisim = if ($ek) { $ek.PasswordLastSet } else { $null }
            }
        }
    }
}

$rapor | Sort-Object Grup, Uye | Format-Table -AutoSize
$ozet = $rapor | Group-Object Grup | Select-Object Name, Count
Write-Host "`nGrup başına üye sayısı:"
$ozet | Format-Table -AutoSize

if ($CsvYolu) {
    $rapor | Export-Csv -Path $CsvYolu -NoTypeInformation -Encoding UTF8
    Write-Host "Rapor yazıldı: $CsvYolu"
}
