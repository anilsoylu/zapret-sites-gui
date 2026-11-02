# Site Erişimi

Türkiye'de bazı siteler DPI ile engelleniyor. Discord bunlardan biri: DNS sorgusu sahte bir adrese yönlendiriliyor, doğru IP'ye bağlanınca TLS el sıkışması SNI üzerinden kesiliyor. Bu uygulama seçtiğin alan adları için [zapret](https://github.com/bol-van/zapret) ile DPI bypass açar ve aynı alan adlarının DNS sorgularını Cloudflare DoT ile çözer. Listede olmayan siteler normal bağlantıyla çalışmaya devam eder.

Ubuntu 26.04, GNOME 50 ve Wayland üzerinde test edildi. `systemd-resolved` kullanan Debian ve Ubuntu sistemlerinde çalışır.

## Özellikler

- Seçili alan adları için TCP 80 ve 443 bypass'ı
- Discord sesi için UDP 443, 3478, 19294-19344 ve 50000-50100 aralığı
- Yalnızca listedeki alan adları için şifreli DNS, diğerleri router DNS'ini kullanır
- Aç/kapat anahtarı, hazır site listeleri ve elle düzenlenebilir alan adı listesi
- Uygulama kapansa da servisler çalışmaya devam eder
- Yeniden başlatmada son durum korunur

## Kurulum

Gerekenler: root yetkisi, internet bağlantısı ve apt.

```bash
git clone https://github.com/anilsoylu/zapret-sites-gui.git
cd zapret-sites-gui
sudo ./install.sh
```

Script bağımlılıkları kurar, zapret v72.13 kaynağını indirip `/opt/zapret` altında derler, servisleri ve arayüzü yerleştirir. Sonunda uygulama menüsüne "Site Erişimi" kısayolu eklenir.

Kurulumdan sonra:

```bash
zapret-sites-gui
```

veya uygulama menüsünden **Site Erişimi**'ni aç.

## Kullanım

Üst çubuktaki anahtar bypass'ı açar ve kapatır. Anahtar açıkken `zapret` ve `zapret-dns` servisleri etkinleşir, kapalıyken durur ve önyüklemeden çıkarılır.

Hazır listeler düğmeleri Discord, Instagram, Roblox, YouTube, X ve Telegram alan adlarını metin kutusuna ekler. Listeye elle de alan adı yazabilirsin, her satıra bir tane. Alt alan adları üst alan adıyla birlikte kapsanır. Değişiklikler **Kaydet**'e basınca uygulanır ve servisler yeniden başlar.

Arayüzü kapatmak bypass'ı durdurmaz. Bypass'ı kapatmak için anahtarı kullan.

## Nasıl çalışıyor

zapret'in `nfqws` bileşeni, seçili alan adlarına giden paketleri netfilter kuyruğundan geçirir ve TLS ClientHello paketini iki parçaya bölerek gönderir. DPI cihazı SNI alanını tek pakette göremediği için bağlantıyı engelleyemez. `MODE_FILTER=hostlist` sayesinde yalnızca `/opt/zapret/ipset/zapret-hosts-user.txt` içindeki alan adları bu işlemden geçer.

DNS tarafında `zapretdns` adında bir dummy ağ arayüzü (`10.53.53.1/32`) oluşturulur. `resolvectl` ile bu arayüze Cloudflare DoT sunucuları atanır ve yalnızca listedeki alan adları bu arayüze yönlendirilir. Diğer alan adları sistemin normal DNS sunucusunu kullanır, yani split DNS uygulanır.

Kurulan dosyalar:

| Yol | İçerik |
| --- | --- |
| `/opt/zapret` | zapret kaynağı ve derlenmiş ikililer |
| `/opt/zapret/ipset/zapret-hosts-user.txt` | Kapsanan alan adları |
| `/usr/local/bin/zapret-sites-gui` | GTK4 arayüzü |
| `/usr/local/libexec/zapret-gui-helper` | Root yetkisiyle çalışan dar kapsamlı yardımcı |
| `/usr/local/sbin/zapret-dns-setup.sh` | Split DNS kurulumu |
| `/usr/local/sbin/zapret-dns-teardown.sh` | Dummy arayüzü kaldırma |
| `/etc/systemd/system/zapret.service` | Bypass servisi |
| `/etc/systemd/system/zapret-dns.service` | DNS servisi |
| `/etc/sudoers.d/zapret-gui` | Yardımcı için NOPASSWD kuralı |

Arayüz root olarak çalışmaz. Yalnızca `status`, `on`, `off` ve `set-list` komutlarını kabul eden yardımcıyı `sudo` ile çağırır. Sudoers kuralı tek bir dosyaya ve tek bir komuta izin verir.

## Strateji

Strateji Superonline hattında `blockcheck.sh` ile bulundu:

```text
TCP 443: --dpi-desync=multisplit --dpi-desync-split-pos=2
TCP 80:  --dpi-desync=multisplit --dpi-desync-split-pos=method+2
UDP:     --dpi-desync=fake --dpi-desync-repeats=6 --filter-l7=discord,stun
```

Farklı bir ISS'de çalışmazsa `/opt/zapret/blockcheck.sh` ile kendi stratejini bulup `/opt/zapret/config` içindeki `NFQWS_OPT` satırını değiştirebilirsin.

## Hız

50 MB'lık bir Cloudflare indirmesinde bypass açıkken 31-34 MB/s, kapalıyken 33-35 MB/s ölçtüm. Fark %3 civarında. `nfqws` boşta CPU kullanmıyor, yalnızca kuyruğa düşen paketleri işliyor.

## Sınırlar

- Roblox gibi IP seviyesinde engellenen sitelerde işe yaramaz. Bypass SNI tabanlı DPI'ı atlatır, IP bloğunu değil.
- Yalnızca kurulduğu makinenin trafiğini etkiler. Router'da çalışmaz.
- `DISABLE_IPV6=1` ayarlı. nfqws kuralları IPv4 için yazıldı, IPv6 trafiği bypass edilmez.
- Servisler root yetkisiyle çalışır. Kurulum ve kaldırma `sudo` gerektirir.

## Kaldırma

```bash
sudo ./uninstall.sh
```

Bu komut servisleri durdurur, kurulan dosyaları ve sudoers kuralını siler. zapret kaynağını da silmek için:

```bash
sudo ./uninstall.sh --purge
```

## Lisans

MIT. Ayrıntılar için [LICENSE](LICENSE).
