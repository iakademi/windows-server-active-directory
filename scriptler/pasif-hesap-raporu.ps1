<#
.SYNOPSIS
    Belirli süredir oturum açmamış (pasif) kullanıcı ve bilgisayar hesaplarını raporlar.
.DESCRIPTION
    LastLogonTimestamp değeri üzerinden pasif hesapları bulur. Bu öznitelik
    yaklaşık 9-14 günlük bir gecikmeyle çoğaltıldığı için kısa eşikler (14 günden az)
    güvenilir değildir. Betik yalnızca rapor üretir; hesapları değiştirmez.
.PARAMETER Gun
    Pasiflik eşiği (gün). Varsayılan 90.
.PARAMETER Tur
    Kullanici, Bilgisayar veya Hepsi.
.PARAMETER ArananOU
    Aramanın sınırlanacağı OU (DN).
.PARAMETER CsvYolu
    Rapor CSV yolu. Verilmezse ekrana yazılır.
.EXAMPLE
    .\pasif-hesap-raporu.ps1 -Gun 120 -Tur Kullanici -CsvYolu .\pasif-kullanicilar.csv
#>
#Requires -Modules ActiveDirectory
[CmdletBinding()]
param(
    [ValidateRange(14, 3650)][int]$Gun = 90,
    [ValidateSet('Kullanici', 'Bilgisayar', 'Hepsi')][string]$Tur = 'Hepsi',
    [string]$ArananOU,
    [string]$CsvYolu
)

$esik = (Get-Date).AddDays(-$Gun)
$ortak = @{ Properties = 'LastLogonTimestamp', 'Enabled', 'Description', 'WhenCreated', 'PasswordLastSet', 'DistinguishedName' }
if ($ArananOU) { $ortak.SearchBase = $ArananOU }

$sonuc = @()

if ($Tur -in 'Kullanici', 'Hepsi') {
    $sonuc += Get-ADUser -Filter 'Enabled -eq $true' @ortak | ForEach-Object {
        [pscustomobject]@{
            Tur = 'Kullanici'; Ad = $_.SamAccountName; Etkin = $_.Enabled
            SonOturum = if ($_.LastLogonTimestamp) { [datetime]::FromFileTime($_.LastLogonTimestamp) } else { $null }
            OlusturulmaTarihi = $_.WhenCreated; ParolaSonDegisim = $_.PasswordLastSet
            Aciklama = $_.Description; DN = $_.DistinguishedName
        }
    }
}

if ($Tur -in 'Bilgisayar', 'Hepsi') {
    $sonuc += Get-ADComputer -Filter 'Enabled -eq $true' @ortak | ForEach-Object {
        [pscustomobject]@{
            Tur = 'Bilgisayar'; Ad = $_.Name; Etkin = $_.Enabled
            SonOturum = if ($_.LastLogonTimestamp) { [datetime]::FromFileTime($_.LastLogonTimestamp) } else { $null }
            OlusturulmaTarihi = $_.WhenCreated; ParolaSonDegisim = $_.PasswordLastSet
            Aciklama = $_.Description; DN = $_.DistinguishedName
        }
    }
}

# Hiç oturum açmamış ama yeni oluşturulmuş hesapları pasif sayma
$pasif = $sonuc | Where-Object {
    ($_.SonOturum -and $_.SonOturum -lt $esik) -or
    (-not $_.SonOturum -and $_.OlusturulmaTarihi -lt $esik)
} | Sort-Object SonOturum

Write-Host ("{0} gündür pasif {1} etkin hesap bulundu." -f $Gun, @($pasif).Count)

if ($CsvYolu) {
    $pasif | Export-Csv -Path $CsvYolu -NoTypeInformation -Encoding UTF8
    Write-Host "Rapor yazıldı: $CsvYolu"
}
else {
    $pasif | Format-Table Tur, Ad, SonOturum, OlusturulmaTarihi, Aciklama -AutoSize
}
# Öneri: Pasif hesapları önce devre dışı bırakıp "Pasif" OU'suna taşıyın, 30-60 gün sonra silin.
