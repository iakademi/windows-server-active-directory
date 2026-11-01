<#
.SYNOPSIS
    Parolası yakında dolacak etkin kullanıcıları raporlar.
.DESCRIPTION
    Etkin, parola süresi dolmayan seçeneği kapalı kullanıcıların parola bitiş
    tarihini msDS-UserPasswordExpiryTimeComputed özniteliğinden okur ve belirtilen
    gün sayısı içinde dolacak olanları listeler. Etki alanı ve ince ayarlı
    parola politikaları (Fine-Grained) otomatik olarak hesaba katılır.
    Betik e-posta göndermez; yalnızca rapor üretir.
.PARAMETER GunSayisi
    Bugünden itibaren kaç gün içinde dolacaklar listelensin. Varsayılan 14.
.PARAMETER ArananOU
    Aramanın sınırlanacağı OU (DN).
.PARAMETER CsvYolu
    Rapor CSV yolu.
.EXAMPLE
    .\parola-suresi-dolacaklar.ps1 -GunSayisi 7 -CsvYolu .\parola-dolacak.csv
#>
#Requires -Modules ActiveDirectory
[CmdletBinding()]
param(
    [ValidateRange(1, 365)][int]$GunSayisi = 14,
    [string]$ArananOU,
    [string]$CsvYolu
)

$bugun = Get-Date
$sinir = $bugun.AddDays($GunSayisi)

$arama = @{
    Filter     = 'Enabled -eq $true -and PasswordNeverExpires -eq $false'
    Properties = 'DisplayName', 'EmailAddress', 'PasswordLastSet', 'msDS-UserPasswordExpiryTimeComputed', 'Department'
}
if ($ArananOU) { $arama.SearchBase = $ArananOU }

$sonuc = Get-ADUser @arama | ForEach-Object {
    $deger = $_.'msDS-UserPasswordExpiryTimeComputed'
    # 0x7FFFFFFFFFFFFFFF: parola hiç dolmaz
    if ($null -eq $deger -or $deger -eq 9223372036854775807 -or $deger -eq 0) { return }
    $bitis = [datetime]::FromFileTime($deger)
    if ($bitis -le $sinir) {
        [pscustomobject]@{
            KullaniciAdi = $_.SamAccountName
            AdSoyad      = $_.DisplayName
            Departman    = $_.Department
            Eposta       = $_.EmailAddress
            ParolaSonDegisim = $_.PasswordLastSet
            ParolaBitis  = $bitis
            KalanGun     = [math]::Floor(($bitis - $bugun).TotalDays)
            Durum        = if ($bitis -lt $bugun) { 'SURESI DOLMUS' } else { 'Yakinda dolacak' }
        }
    }
} | Sort-Object ParolaBitis

Write-Host ("{0} kullanıcının parolası {1} gün içinde doluyor veya dolmuş." -f @($sonuc).Count, $GunSayisi)

if ($CsvYolu) {
    $sonuc | Export-Csv -Path $CsvYolu -NoTypeInformation -Encoding UTF8
    Write-Host "Rapor yazıldı: $CsvYolu"
}
else {
    $sonuc | Format-Table KullaniciAdi, AdSoyad, ParolaBitis, KalanGun, Durum -AutoSize
}
