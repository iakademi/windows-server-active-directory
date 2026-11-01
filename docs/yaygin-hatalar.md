# Active Directory'de Yaygın Hatalar ve Çözümleri

## 1. Kimlik Doğrulama ve Oturum Açma

| Belirti | Olası neden | Çözüm |
|---------|-------------|-------|
| "The trust relationship between this workstation and the primary domain failed" | Bilgisayar hesabı parolası DC ile uyumsuz (eski snapshot, uzun süre kapalı makine) | Yerel yönetici ile `Test-ComputerSecureChannel -Repair -Credential (Get-Credential)`; olmazsa etki alanından çıkarıp yeniden katın |
| Kullanıcı sürekli kilitleniyor | Eski parola ile çalışan servis, eşlenmiş sürücü, mobil cihaz, zamanlanmış görev | Kilitlenmeyi tetikleyen kaynağı DC'de 4740 olayının "Caller Computer Name" alanından bulun |
| Saat farkı nedeniyle Kerberos hatası (KRB_AP_ERR_SKEW) | İstemci ve DC arasında 5 dakikadan fazla fark | Zaman senkronizasyonunu düzeltin: `w32tm /resync` |
| "The specified domain either does not exist or could not be contacted" | İstemcinin DNS ayarı yanlış | İstemci DNS'ini etki alanı DNS sunucusuna çevirin; `nslookup -type=SRV _ldap._tcp.dc._msdcs.<alanadi>` ile SRV kaydını doğrulayın |

## 2. Çoğaltma ve DC Sorunları

| Belirti | Olası neden | Çözüm |
|---------|-------------|-------|
| `repadmin /replsummary` hata gösteriyor | DNS, ağ, güvenlik duvarı veya zaman sorunu | `dcdiag /test:dns /v`, DNS kayıtlarını ve portları (TCP/UDP 53, 88, 135, 389, 445, dinamik RPC) kontrol edin |
| SYSVOL/NETLOGON paylaşılmıyor | DFSR başlatılamadı, çoğaltma bekliyor | DFSR olay günlüğünü inceleyin; `dfsrdiag` ile durumu doğrulayın |
| Bir DC kalıcı olarak kaybedildi ama listede duruyor | Metadata temizlenmedi | DC nesnesini ADUC'tan silip metadata temizliğini yapın, DNS/SRV ve Sites kayıtlarını temizleyin |
| USN rollback | DC'nin snapshot'tan geri yüklenmesi | Etkilenen DC'yi ağdan ayırın; zorla kaldırıp yeniden terfi ettirin |

## 3. Yönetim Hataları

1. **Her yöneticiye Domain Admin vermek.** Çözüm: yetki devri ve rol bazlı gruplar.
2. **Servis hesaplarını Domain Admin yapmak.** Çözüm: en az yetki, gMSA.
3. **Parolası hiç dolmayan hesaplar bırakmak.** Çözüm: raporlayın, gMSA'ya geçin veya uzun rastgele parola kullanın.
4. **Varsayılan Users/Computers konteynerlerine nesne bırakmak.** Çözüm: OU yapısına taşıyın, `redirusr/redircmp` ile yönlendirin.
5. **Default Domain Policy'yi kalabalıklaştırmak.** Çözüm: yalnızca parola/kilitleme/Kerberos ayarlarını orada tutun; diğerleri için ayrı GPO oluşturun.
6. **Tek DC ile çalışmak.** Çözüm: en az iki DC ve yedekleme.
7. **Yedeksiz GPO ve AD değişikliği.** Çözüm: değişiklikten önce `Backup-GPO` ve System State yedeği.
8. **DC'lerde web gezintisi ve e-posta.** Çözüm: yönetimi güvenli bir yönetim istasyonundan yapın.
9. **Eski kayıtları (stale DNS, eski bilgisayar hesapları) temizlememek.** Çözüm: scavenging ve pasif hesap raporu.
10. **AD Recycle Bin'i etkinleştirmemek.** Silinen nesneler geri getirilemeyebilir.

## 4. PowerShell ile Yapılan Hatalar

- `Get-ADUser -Filter *` ile tüm nesneleri çekip filtrelemek yerine `-Filter` veya `-LDAPFilter` ile sunucu tarafında filtreleyin.
- `-Properties *` kullanmak yerine yalnızca gereken özellikleri isteyin.
- Toplu değişikliklerde `-WhatIf` ve `-Confirm` kullanmamak. Önce raporu üretip inceleyin.
- `LastLogonDate` / `LastLogonTimestamp` değerinin 9-14 gün gecikmeli çoğaltıldığını unutmak; hassas senaryoda `LastLogon` her DC'den sorgulanmalıdır.
- Parolaları betik içine düz metin yazmak. Gizli bilgi için `Get-Credential`, SecretManagement veya kurumsal bir kasa kullanın.

## 5. Hızlı Tanılama Komutları

```powershell
dcdiag /v
repadmin /replsummary
repadmin /showrepl
netdom query fsmo
nltest /dsgetdc:<alanadi>
Get-ADDomainController -Filter * | Select-Object Name, Site, IPv4Address, OperatingSystem
Get-ADReplicationFailure -Target <DC-adi>
w32tm /query /status
gpresult /r
```
