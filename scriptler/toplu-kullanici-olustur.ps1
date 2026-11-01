<#
.SYNOPSIS
    CSV dosyasından Active Directory kullanıcılarını toplu olarak oluşturur.
.DESCRIPTION
    CSV'deki her satır için hedef OU'da kullanıcı oluşturur, rastgele güçlü bir
    başlangıç parolası üretir, ilk oturum açışta parola değişimini zorunlu kılar
    ve belirtilen gruplara ekler. Mevcut kullanıcılar atlanır.
    Oluşturulan başlangıç parolaları ekrana yazılmaz; yalnızca -ParolaDosyasi
    verilirse güvenli bir şekilde belirtilen CSV'ye yazılır (dosyayı yalnızca
    yetkili kişiler görebilmeli ve kullanım sonrası silinmelidir).
.PARAMETER CsvYolu
    Giriş CSV dosyası. Sütunlar: Ad, Soyad, KullaniciAdi, Departman, Unvan, OU, Eposta, Gruplar
    (Gruplar birden çok ise ';' ile ayrılır.)
.PARAMETER UpnSonEki
    Kullanıcı asıl adı (UPN) son eki. Örnek: example.local
.PARAMETER ParolaDosyasi
    İsteğe bağlı. Başlangıç parolalarının yazılacağı CSV yolu.
.EXAMPLE
    .\toplu-kullanici-olustur.ps1 -CsvYolu .\ornek-kullanicilar.csv -UpnSonEki example.local -WhatIf
.EXAMPLE
    .\toplu-kullanici-olustur.ps1 -CsvYolu .\ornek-kullanicilar.csv -UpnSonEki example.local -ParolaDosyasi C:\Guvenli\ilk-parolalar.csv
#>
#Requires -Modules ActiveDirectory
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path $_ -PathType Leaf })][string]$CsvYolu,
    [Parameter(Mandatory)][string]$UpnSonEki,
    [string]$ParolaDosyasi
)

function Yeni-RastgeleParola {
    param([int]$Uzunluk = 16)
    $karakterler = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!#$%&*?'.ToCharArray()
    $bayt = New-Object 'byte[]' ($Uzunluk)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        # Her karakter sınıfından en az bir karakter garanti edilir
        do {
            $rng.GetBytes($bayt)
            $parola = -join ($bayt | ForEach-Object { $karakterler[$_ % $karakterler.Length] })
        } until ($parola -cmatch '[a-z]' -and $parola -cmatch '[A-Z]' -and $parola -match '\d' -and $parola -match '[^a-zA-Z0-9]')
    }
    finally { $rng.Dispose() }
    return $parola
}

$kayitlar = Import-Csv -Path $CsvYolu -Encoding UTF8
$ozet = @{ Olusturulan = 0; Atlanan = 0; Hatali = 0 }
$parolaKayitlari = @()

foreach ($k in $kayitlar) {
    $sam = $k.KullaniciAdi.Trim()
    if ([string]::IsNullOrWhiteSpace($sam)) { Write-Warning 'Boş KullaniciAdi, satır atlandı.'; $ozet.Atlanan++; continue }

    if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        Write-Warning "$sam zaten mevcut, atlandı."
        $ozet.Atlanan++
        continue
    }

    if (-not [ADSI]::Exists("LDAP://$($k.OU)")) {
        Write-Error "$sam için OU bulunamadı: $($k.OU)"
        $ozet.Hatali++
        continue
    }

    $parola = Yeni-RastgeleParola
    $parametreler = @{
        Name                  = "$($k.Ad) $($k.Soyad)"
        GivenName             = $k.Ad
        Surname               = $k.Soyad
        DisplayName           = "$($k.Ad) $($k.Soyad)"
        SamAccountName        = $sam
        UserPrincipalName     = "$sam@$UpnSonEki"
        EmailAddress          = $k.Eposta
        Department            = $k.Departman
        Title                 = $k.Unvan
        Path                  = $k.OU
        AccountPassword       = (ConvertTo-SecureString $parola -AsPlainText -Force)
        ChangePasswordAtLogon = $true
        Enabled               = $true
    }

    if ($PSCmdlet.ShouldProcess($sam, 'AD kullanıcısı oluştur')) {
        try {
            New-ADUser @parametreler -ErrorAction Stop
            $ozet.Olusturulan++
            Write-Host "Oluşturuldu: $sam"

            foreach ($grup in ($k.Gruplar -split ';' | Where-Object { $_.Trim() })) {
                try {
                    Add-ADGroupMember -Identity $grup.Trim() -Members $sam -ErrorAction Stop
                }
                catch { Write-Warning "$sam, '$grup' grubuna eklenemedi: $($_.Exception.Message)" }
            }

            $parolaKayitlari += [pscustomobject]@{ KullaniciAdi = $sam; IlkParola = $parola }
        }
        catch {
            Write-Error "$sam oluşturulamadı: $($_.Exception.Message)"
            $ozet.Hatali++
        }
    }
}

if ($ParolaDosyasi -and $parolaKayitlari.Count -gt 0) {
    $parolaKayitlari | Export-Csv -Path $ParolaDosyasi -NoTypeInformation -Encoding UTF8
    Write-Warning "İlk parolalar $ParolaDosyasi dosyasına yazıldı. Dosyayı güvenle iletin ve kullanımdan sonra silin."
}

Write-Host ("Özet: {0} oluşturuldu, {1} atlandı, {2} hatalı." -f $ozet.Olusturulan, $ozet.Atlanan, $ozet.Hatali)
