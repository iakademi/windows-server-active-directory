# Active Directory En İyi Uygulamaları

## 1. Tasarım ve Yapı

- **Basit tutun:** Çoğu kurum için tek orman ve tek etki alanı yeterlidir. Ek etki alanları yalnızca net bir ihtiyaç (yasal, idari sınır) varsa eklenmelidir.
- **Anlamlı bir DNS adı seçin:** Sahip olduğunuz bir alan adının alt etki alanını kullanın (örn. `ad.sirket.com`). Ağ üzerinde yönlendirilemeyen `.local` adları yeni kurulumlarda önerilmez; bu depodaki örnekler yalnızca lab amaçlıdır.
- **OU yapısını yönetim ve GPO ihtiyaçlarına göre tasarlayın:** Kullanıcı, bilgisayar, sunucu ve servis hesaplarını ayrı OU'lara koyun. Ayrıntı için `scriptler/ou-yapisi-olustur.ps1`.
- **Varsayılan konteynerlere (Users, Computers) nesne bırakmayın:** `redirusr` ve `redircmp` ile yeni nesnelerin varsayılan OU'larını değiştirin.
- **OU'ları yanlışlıkla silmeye karşı koruyun:** `ProtectedFromAccidentalDeletion` açık olmalı.
- **Site ve alt ağları (Sites and Services) doğru tanımlayın:** İstemcilerin en yakın DC'yi bulması ve çoğaltma trafiği için gereklidir.

## 2. Etki Alanı Denetleyicileri (DC)

- Her etki alanında **en az iki DC** bulundurun; farklı fiziksel konak/başarısızlık alanlarına yerleştirin.
- DC'lerde başka rol çalıştırmayın (dosya sunucusu, uygulama sunucusu vb.). Mümkünse **Server Core** kullanın.
- FSMO rollerinin yerini belgeleyin; `netdom query fsmo` ile kontrol edin. Aktarım yerine el koyma (seize) yalnızca DC kalıcı olarak kaybedildiyse yapılmalıdır.
- DC'leri yedekleyin (System State) ve **geri yükleme prosedürünü** test edin. Sanallaştırılmış DC'lerde snapshot ile geri dönmek (USN rollback) risklidir; VM-GenerationID destekli platform kullanın.
- Zaman: PDC Emulator rolündeki DC güvenilir bir dış zaman kaynağıyla senkronize edilmeli, diğerleri etki alanı hiyerarşisini izlemeli.
- Düzenli yama uygulayın; kritik güvenlik güncellemelerini önceliklendirin.
- Çoğaltma sağlığı: `repadmin /replsummary`, `repadmin /showrepl`, `dcdiag /v`.

## 3. Kimlik ve Yetki Yönetimi

- **En az yetki ilkesi:** Domain Admins, Enterprise Admins ve Schema Admins gruplarını boş veya çok az üyeli tutun. Enterprise/Schema Admins yalnızca gerektiğinde geçici üye yapılmalıdır.
- **Ayrı yönetici hesapları:** Günlük işler için standart hesap, yönetim için ayrı hesap kullanın. Yönetici hesapları e-posta okumamalı, internette gezinmemelidir.
- **Katmanlı yönetim (tiering):** Tier 0 (DC, kimlik altyapısı), Tier 1 (sunucular), Tier 2 (iş istasyonları) hesaplarını ayırın; üst katman hesapları alt katmanda oturum açmamalıdır.
- **Yetki devri:** Parola sıfırlama, hesap oluşturma gibi görevleri OU bazında "Delegation of Control" ile yardım masasına devredin.
- **Grup stratejisi:** Yetkileri doğrudan kullanıcılara değil gruplara verin. AGDLP (Account → Global → Domain Local → Permission) modelini uygulayın.
- **Servis hesapları:** Mümkün olduğunda gMSA kullanın; elle yönetilenlere uzun rastgele parola verin ve SPN kayıtlarını belgeleyin.
- **Yerel yönetici parolaları:** Windows LAPS ile benzersiz ve otomatik değişen parola.
- **Korumalı Kullanıcılar (Protected Users) grubu:** Yüksek yetkili hesaplar için değerlendirin.

## 4. Parola ve Kimlik Doğrulama

- Etki alanı parola politikasında uzunluğu önceliklendirin (en az 12-14 karakter); ayrıcalıklı hesaplar için **Fine-Grained Password Policy (PSO)** kullanın.
- Mümkünse yasaklı parola listesi (ör. Microsoft Entra Password Protection on-premises) ekleyin.
- NTLM kullanımını denetleyin ve azaltın; LDAP imzalama ve channel binding'i etkinleştirmeyi planlayın.
- krbtgt hesabı parolasını periyodik olarak (iki kez, aralarında çoğaltma süresi bırakarak) değiştirin.
- MFA: Uzak erişim ve bulut yönetimi için zorunlu tutun.

## 5. Hesap Yaşam Döngüsü

- İşe giriş, görev değişikliği ve işten ayrılma süreçlerini İK ile bağlayın.
- Ayrılan kullanıcıyı hemen devre dışı bırakın, grup üyeliklerini inceleyin, "Pasif" OU'ya taşıyın, saklama süresi sonunda silin.
- Düzenli pasif hesap raporu alın (`scriptler/pasif-hesap-raporu.ps1`) ve ayrıcalıklı grup üyeliklerini gözden geçirin (`scriptler/grup-uyelik-raporu.ps1`).
- Parola süresi dolacak kullanıcıları önceden bilgilendirin (`scriptler/parola-suresi-dolacaklar.ps1`).
- **AD Recycle Bin**'i etkinleştirin: `Enable-ADOptionalFeature 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target (Get-ADForest).Name`. Bu işlem geri alınamaz; önce planlayın.

## 6. DNS

- AD DNS bölgelerini AD ile bütünleşik ve güvenli dinamik güncelleme ile yapılandırın.
- İstemcilerin DNS sunucusu olarak yalnızca etki alanı DNS sunucularını gösterin (dış DNS'e doğrudan yönlendirmeyin; forwarder kullanın).
- Eski kayıtlar için scavenging planlayın.

## 7. İzleme ve Denetim

- Gelişmiş denetim politikalarını etkinleştirin: hesap oturumu, hesap yönetimi, dizin hizmeti değişiklikleri.
- Önemli olay kimlikleri: 4624/4625 (oturum), 4720/4722/4725/4726 (hesap), 4728/4732/4756 (güvenlik grubuna üye ekleme), 4740 (hesap kilitlenme), 4768/4769 (Kerberos).
- DC günlüklerini merkezi bir sisteme aktarın.
- Dizin hizmeti, DNS ve DFSR/SYSVOL çoğaltma uyarılarını izleyin.

## 8. Dokümantasyon ve Değişiklik Yönetimi

- Orman/etki alanı mimarisini, FSMO yerlerini, OU ve GPO yapısını belgeleyin.
- Şema değişiklikleri ve GPO düzenlemeleri için değişiklik kaydı tutun; GPO'ları yedekleyin (`Backup-GPO -All -Path <yol>`).
- Kurtarma planı (forest recovery) ve düzenli tatbikat.
