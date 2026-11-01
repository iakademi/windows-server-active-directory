<#
.SYNOPSIS
    Standart bir Active Directory OU hiyerarşisi oluşturur.
.DESCRIPTION
    Aşağıdaki yapıyı alan adı kökü altında kurar. Mevcut OU'lar atlanır.
    Yeni OU'lar varsayılan olarak yanlışlıkla silinmeye karşı korunur.

      Sirket
      ├── Kullanicilar
      ├── Bilgisayarlar (Iş İstasyonları, Sunucular)
      ├── Gruplar
      ├── Servis Hesaplari
      └── Departmanlar
          └── <Departman>
              ├── Kullanicilar
              ├── Bilgisayarlar
              └── Gruplar

.PARAMETER AlanAdiDN
    Etki alanı distinguished name. Örnek: DC=example,DC=local (varsayılan: geçerli etki alanı)
.PARAMETER KokOU
    Üst düzey OU adı (varsayılan: Sirket).
.PARAMETER Departmanlar
    Oluşturulacak departman OU'ları.
.EXAMPLE
    .\ou-yapisi-olustur.ps1 -WhatIf
.EXAMPLE
    .\ou-yapisi-olustur.ps1 -AlanAdiDN 'DC=example,DC=local' -Departmanlar Muhasebe,Satis,BilgiIslem
#>
#Requires -Modules ActiveDirectory
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$AlanAdiDN = (Get-ADDomain).DistinguishedName,
    [string]$KokOU = 'Sirket',
    [string[]]$Departmanlar = @('Muhasebe', 'Satis', 'BilgiIslem', 'InsanKaynaklari'),
    [switch]$KorumasizOlustur
)

function Yeni-OU {
    param([string]$Ad, [string]$Yol, [string]$Aciklama)
    $dn = "OU=$Ad,$Yol"
    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue) {
        Write-Host "Mevcut: $dn"
        return $dn
    }
    if ($PSCmdlet.ShouldProcess($dn, 'OU oluştur')) {
        New-ADOrganizationalUnit -Name $Ad -Path $Yol -Description $Aciklama `
            -ProtectedFromAccidentalDeletion (-not $KorumasizOlustur)
        Write-Host "Oluşturuldu: $dn"
    }
    return $dn
}

$kok = Yeni-OU -Ad $KokOU -Yol $AlanAdiDN -Aciklama 'Kurum kök OU'

$kullanicilar = Yeni-OU -Ad 'Kullanicilar' -Yol $kok -Aciklama 'Genel kullanıcı hesapları'
$bilgisayarlar = Yeni-OU -Ad 'Bilgisayarlar' -Yol $kok -Aciklama 'Bilgisayar hesapları'
$null = Yeni-OU -Ad 'Is Istasyonlari' -Yol $bilgisayarlar -Aciklama 'İstemci bilgisayarlar'
$null = Yeni-OU -Ad 'Sunucular' -Yol $bilgisayarlar -Aciklama 'Üye sunucular'
$null = Yeni-OU -Ad 'Gruplar' -Yol $kok -Aciklama 'Güvenlik ve dağıtım grupları'
$null = Yeni-OU -Ad 'Servis Hesaplari' -Yol $kok -Aciklama 'Servis hesapları ve gMSA'
$dept = Yeni-OU -Ad 'Departmanlar' -Yol $kok -Aciklama 'Departman bazlı nesneler'

foreach ($d in $Departmanlar) {
    $dDn = Yeni-OU -Ad $d -Yol $dept -Aciklama "$d departmanı"
    foreach ($alt in 'Kullanicilar', 'Bilgisayarlar', 'Gruplar') {
        $null = Yeni-OU -Ad $alt -Yol $dDn -Aciklama "$d $alt"
    }
}

Write-Host 'OU yapısı tamamlandı. Varsayılan konumları yönlendirmek için redirusr/redircmp kullanabilirsiniz.'
