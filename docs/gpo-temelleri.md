# Grup İlkesi (GPO) Temelleri

Grup İlkesi, bilgisayar ve kullanıcı ayarlarını Active Directory üzerinden merkezi olarak yönetmeyi sağlar.

## Kavramlar

| Kavram | Açıklama |
|--------|----------|
| GPO | Ayarlar kümesi. Bilgisayar Yapılandırması ve Kullanıcı Yapılandırması olmak üzere iki bölümü vardır |
| Bağlantı (Link) | GPO'nun site, etki alanı veya OU'ya bağlanması |
| Kapsam (Scope) | GPO'nun hangi nesnelere uygulanacağı (bağlantı + güvenlik filtreleme + WMI filtreleme) |
| Güvenlik filtreleme | "Authenticated Users" yerine belirli gruplara uygulama (Apply group policy iznine sahip olanlar) |
| SYSVOL | GPO şablon dosyalarının DC'ler arasında çoğaltıldığı paylaşım |
| ADMX/ADMW | Yönetim şablonları. Merkezi depo (`\\<alanadi>\SYSVOL\<alanadi>\Policies\PolicyDefinitions`) önerilir |

## İşlem Sırası (LSDOU)

1. **L**ocal (yerel ilke)
2. **S**ite
3. **D**omain (etki alanı)
4. **OU** (üstten alta, iç içe OU'larda en yakın OU en son uygulanır)

Sonra uygulanan önceki ayarı geçersiz kılar. Önemli kavramlar:

- **Enforced:** Alt seviyedeki GPO tarafından geçersiz kılınamaz.
- **Block Inheritance:** OU'da üst seviyeden gelen GPO'ları engeller (Enforced olanlar yine geçer).
- **Loopback işleme:** Kullanıcı ayarlarını oturum açılan bilgisayara göre uygular (terminal sunucuları, kiosk). *Merge* veya *Replace* modunda çalışır.

## Yenileme

- Bilgisayar ayarları açılışta, kullanıcı ayarları oturum açarken uygulanır.
- Arka planda iş istasyonlarında yaklaşık 90 dakika (+ rastgele 0-30 dk), DC'lerde 5 dakika aralıkla yenilenir.
- Elle yenileme: `gpupdate /force`

## Tanılama

```powershell
gpresult /r                    # Uygulanan GPO özeti
gpresult /h rapor.html         # Ayrıntılı HTML rapor
Get-GPResultantSetOfPolicy -ReportType Html -Path .\rsop.html
Get-GPO -All | Select-Object DisplayName, GpoStatus, ModificationTime
Get-GPInheritance -Target "OU=Satis,DC=example,DC=local"
```

Olay Görüntüleyici: *Applications and Services Logs > Microsoft > Windows > GroupPolicy > Operational*.

## Örnek GPO Senaryoları

| GPO | Hedef | Ayarlar (örnek) |
|-----|-------|------------------|
| Parola ve kilitleme | Etki alanı (Default Domain Policy) | Minimum uzunluk, kilitleme eşiği ve süresi |
| Ekran kilidi | Kullanıcılar OU | Etkin olmama süresi 10 dk, parola ile devam |
| Windows Update | İş istasyonları | Güncelleme kanalı, yeniden başlatma saatleri |
| Güvenlik duvarı | Tümü | Profiller etkin, gelen bağlantı engeli |
| Sürücü eşleme | Departman kullanıcıları | Group Policy Preferences > Drive Maps, güvenlik filtreli |
| USB kısıtı | İş istasyonları | Çıkarılabilir depolama yazma engeli |
| Yazılım kısıtlama / AppLocker | Seçili makineler | Önce denetim modu |

## Oluşturma Örneği (PowerShell)

```powershell
New-GPO -Name 'WKS-Ekran-Kilidi' -Comment 'Ekran koruyucu ve kilit'
Set-GPRegistryValue -Name 'WKS-Ekran-Kilidi' `
    -Key 'HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop' `
    -ValueName 'ScreenSaveTimeOut' -Type String -Value '600'
Set-GPRegistryValue -Name 'WKS-Ekran-Kilidi' `
    -Key 'HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop' `
    -ValueName 'ScreenSaverIsSecure' -Type String -Value '1'
New-GPLink -Name 'WKS-Ekran-Kilidi' -Target 'OU=Kullanicilar,OU=Sirket,DC=example,DC=local' -LinkEnabled Yes
Backup-GPO -Name 'WKS-Ekran-Kilidi' -Path C:\GPOYedek
```

## En İyi Uygulamalar

1. **Default Domain Policy ve Default Domain Controllers Policy'yi minimum tutun**; diğer ayarlar için yeni GPO'lar oluşturun.
2. **Anlamlı isimlendirme:** `WKS-` (iş istasyonu), `SRV-`, `USR-` ön ekleri ve amaç.
3. **Bilgisayar ve kullanıcı ayarlarını ayırın**; kullanılmayan bölümü "Disable" ederek işlem süresini azaltın.
4. **Küçük ve amaca yönelik GPO'lar** hata ayıklamayı kolaylaştırır.
5. **Önce test OU'su:** Pilot grupla deneyin.
6. **Yedekleyin ve belgeleyin:** `Backup-GPO`, değişiklik açıklamaları.
7. **Güvenlik filtrelemede** "Read" iznini koruyun (MS16-072 sonrası Authenticated Users veya Domain Computers için okuma gerekir).
8. **WMI filtrelerini** gerektiği kadar kullanın; yavaşlatabilir.
9. **Kullanılmayan ve bağlantısız GPO'ları** düzenli temizleyin.
10. **Düzenli denetim:** Kimin hangi GPO'yu değiştirdiğini olay günlüğü ve sürüm kontrolüyle izleyin.

## Group Policy Preferences (GPP) ve Parola Uyarısı

GPP ile yerel hesap parolası veya servis parolası **tanımlamayın**: bu parolalar SYSVOL'de geri çözülebilir biçimde saklanır. Yerel yönetici parolaları için Windows LAPS kullanın.
