# Windows Server Active Directory Otomasyonu

![Lisans: MIT](https://img.shields.io/badge/Lisans-MIT-green)
![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE)
![Windows Server 2016+](https://img.shields.io/badge/Windows%20Server-2016%2B-0078D4)
![Dil: Türkçe](https://img.shields.io/badge/Dil-T%C3%BCrk%C3%A7e-red)

Active Directory yönetimini kolaylaştıran PowerShell betikleri ve en iyi uygulama dokümanları.

## Hakkında

Bu depo; toplu kullanıcı oluşturma, OU yapısı kurma, pasif hesap, grup üyelik ve parola süresi raporları gibi günlük AD yönetim görevleri için hazır PowerShell betikleri içerir. Ayrıca AD en iyi uygulamaları, yaygın hatalar ve GPO temelleri dokümanlarıyla eğitim materyali işlevi görür.

Betiklerin hepsi `-WhatIf` desteği (değişiklik yapanlar) veya salt-okunur çalışma (raporlar) ilkesiyle yazılmıştır. Üretim ortamında kullanmadan önce mutlaka test ortamında deneyin.

## İçindekiler

- [Başlarken](#başlarken)
- [Betikler](#betikler)
- [Klasör Yapısı](#klasör-yapısı)
- [Katkıda Bulunma](#katkıda-bulunma)
- [Lisans](#lisans)
- [İ-Akademi Hakkında](#i-akademi-hakkında)

## Başlarken

Gereksinimler:

- Windows Server 2016 veya üzeri ya da RSAT yüklü Windows 10/11 yönetim istasyonu
- ActiveDirectory PowerShell modülü: `Install-WindowsFeature RSAT-AD-PowerShell` (sunucu) veya `Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0` (istemci)
- İlgili görevler için yeterli yetkiler (ör. kullanıcı oluşturmak için hedef OU üzerinde yetki devri)

```powershell
git clone https://github.com/iakademi/windows-server-active-directory.git
cd windows-server-active-directory\scriptler
Import-Module ActiveDirectory
Get-Help .\toplu-kullanici-olustur.ps1 -Full
```

Betikleri çalıştırmak için gerekirse yürütme politikasını oturum bazında ayarlayın:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
```

## Betikler

| Betik | Açıklama |
|-------|----------|
| `toplu-kullanici-olustur.ps1` | CSV dosyasından toplu kullanıcı oluşturur (`-WhatIf` destekli) |
| `ou-yapisi-olustur.ps1` | Standart bir OU hiyerarşisi oluşturur |
| `pasif-hesap-raporu.ps1` | Belirli süredir oturum açmamış hesapları raporlar |
| `grup-uyelik-raporu.ps1` | Grup üyeliklerini (iç içe dahil) raporlar |
| `parola-suresi-dolacaklar.ps1` | Parolası yakında dolacak kullanıcıları raporlar |
| `ornek-kullanicilar.csv` | Örnek giriş dosyası (kurgusal kişiler) |

## Dokümanlar

- [AD En İyi Uygulamaları](docs/ad-en-iyi-uygulamalar.md)
- [Yaygın Hatalar](docs/yaygin-hatalar.md)
- [GPO Temelleri](docs/gpo-temelleri.md)

## Klasör Yapısı

```text
windows-server-active-directory/
├── README.md
├── LICENSE
├── scriptler/   # PowerShell betikleri ve örnek CSV
└── docs/        # Dokümanlar
```

## Katkıda Bulunma

Katkılarınızı memnuniyetle karşılıyoruz.

1. Depoyu fork edin.
2. Yeni bir dal oluşturun: `git checkout -b iyilestirme/konu-adi`
3. Değişikliklerinizi açık commit mesajlarıyla kaydedin.
4. Dalınızı gönderin ve bir Pull Request açın.

Hata bildirimi veya öneri için [Issues](../../issues) bölümünü kullanabilirsiniz. Genel kurallar için organizasyonun [CONTRIBUTING.md](https://github.com/iakademi/.github/blob/main/CONTRIBUTING.md) dosyasına bakın.

## Lisans

Bu proje [MIT Lisansı](LICENSE) ile lisanslanmıştır.

## İ-Akademi Hakkında

[İ-Akademi](https://iakademi.com), İstanbul merkezli bir BT eğitim merkezidir. Microsoft/Office/Power Platform, Cisco, siber güvenlik, yazılım, PMP/Scrum/Agile ve Windows Server/Active Directory alanlarında eğitimler sunar; Pearson VUE ve Kryterion yetkili sınav merkezidir.

Web sitesi: <https://iakademi.com>
