# GearShift Proving Grounds

Godot 4.3 ile geliştirilen, fizik ağırlıklı bir araç sürüş ve mekanik test sahası oyunu.

**[⬇️ Son sürümü indir (Windows .exe)](https://github.com/Pigasor/gearshift-proving-grounds/releases/latest/download/GearShiftProvingGrounds.exe)** — her güncellemede otomatik olarak yeniden derlenir.

## Özellikler

- **Gerçekçi sürüş fiziği:** Raycast süspansiyon, tekerlek başına dönüş ve patinaj, lastik sürtünme çemberi, ağırlık transferi, hava direnci ve aerodinamik bastırma kuvveti; zemine göre tutuş (çim/toprakta araç kayar), havada ve çarpışmada serbest dönen gövde, duvardan sekme; canavar kamyon dik duvarlara tırmanabilir; araç devrilince ekranda düzeltme uyarısı
- **Gündüz / gece döngüsü:** Güneş ve ay hareket eder, gün batımı renkleri, gece otoyol, yarış pisti ve dağ yolundaki sokak lambaları, stadyum projektörleri ve pist kenarı ışıkları yanar; saat ve gün uzunluğu Ayarlar > Görüntü'den ayarlanır. Farlar: park lambası, kısa far, uzun far (L / K)
- **Lastik efektleri:** Patinaj, kilitlenme ve driftte zemine göre lastik izi (asfaltta siyah, çimde ezik iz, toprakta tekerlek izi), asfaltta lastik dumanı, çim/toprak/kumda tekerleğin dönüş yönüne savrulan parçalar (izler 5 dakikada silinir); 1. viteste el freni + gaz ile burnout, TCS kapalıyken donut, fren + gazla devir tutup kalkış (önden çekişlilerde fren + gazla yerinde patinaj)
- **Motor ve şanzıman:** Yakıt kesmeli devir kesici, motor freni, rev-matching, araç hızına göre vites seçen otomatik şanzıman ve manuel mod
- **50 araç, 62 motor seçeneği:** Elektrikli (Porshe Taykan, Tezla Model S / Model 3, Tog T10X), Paganni Huayra, Fiatt Serce, Tofask Kartal, Amerikan klasikleri (Bel Er 57, Charjer 69, Shelbi GT500 67), lüks (Mersedes S 600 W140, Reynç Rovır Sport 2018).
  Ayrıca: Her sınıftan dörder-beşer araba: spor (Porshe 911 Turbo Es, BMV Em4, Nisson Zed...), muscle (Forde Mustank, Chevrolay Kamaro, Pontiak Trans Em '77), hiper (Kenigseg Yesko, MakLaren Pe1, Ferraro LaFerrara), NASCAR, 4 canavar kamyon, arazi (Jip Rangler, Toyoda Land Kruzer, Polaros Razer), sedan (Korolla, Pasat, Logann), klasik (Tofask Dogan, Murat 131, Renolt 12 Toros), traktör, 4x4 tüp şasili buggy (görünür amortisörler), gerçek ölçülü aile sedanları ve klasik arkadan itişli Tofask Sahin (benzinli / dizel motorlar, gerçek tork eğrileri, ısı dalgalanması, gaz ve viteste egzoz pufları, dizelde siyah duman, turbo alevi,; garajda her araba için son seçilen motor hatırlanır)
- **Harita:** Havalimanı (pist 18/36, taksi yolları, apron, terminal, kule, hangarlar), tribünlü ve seyircili 1 millik NASCAR stadyumu, 110 m yüksekliğinde dağ (zirveye dolambaçlı toprak yol + taşlı, çalılı, devrik ağaçlı dik off-road yokuşu), yarış pisti ve tur zamanlayıcı, eğimli virajlı otoyol halkası, drift alanı, stunt parkı, off-road alanı ve tepe parkı
- **Garaj (sekmeli, her ayarda açıklama balonu):** Araç / Motor / Süspansiyon / Sürüş — motor gücü (50-2000 HP), turbo, süspansiyon, kamber, tutuş, çekiş tipi, ABS/TCS ayarları
- **Ayarlar menüsü (ESC):** Dil (English / Türkçe), görüntü, grafik, ses, kontroller, tuş atamaları ve direksiyon seti kurulumu
- **Direksiyon seti desteği:** Otomatik eksen/pedal algılama; gaz, fren, debriyaj, el freni (buton veya analog kol), vites kulakçıkları ve H vites kolu
- **Mini harita** (N: yakın / geniş)

## Çalıştırma

1. [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) indir.
2. Godot'yu aç, **Import** ile bu klasördeki `project.godot` dosyasını seç ve çalıştır (F5).

Windows'ta Godot exe'sini proje klasörüne koyarsan `play.bat` ile de başlatabilirsin.

Oyunu bu bilgisayara normal bir program gibi kurmak (exe + masaüstü kısayolu) ya da kurulu oyunu güncellemek için:
`powershell -ExecutionPolicy Bypass -File tools/install_local.ps1`

## Kontroller

| Tuş | Eylem |
|---|---|
| W / S | Gaz / Fren (durduktan sonra S'ye yeniden basınca geri vites) |
| A / D | Direksiyon |
| Space | El freni |
| Shift | Turbo boost |
| E / Q | Vites yükselt / düşür (manuel) |
| G | Otomatik / manuel şanzıman |
| M | Büyük harita (oyun durur; çift tıklanan yere ışınlanma) |
| N | Mini harita yakın / geniş |
| L | Farlar: 1. basış park lambaları, 2. basış kısa far, 3. basış kapalı |
| K | Uzun far aç / kapat |
| C | Kamera |
| T | Ağır çekim |
| R | Aracı düzelt: ters dönünce olduğu yere dik bırakır (gamepad: Y) |
| TAB | Garaj (araç ve motor seçimi, ayarlar) |
| ESC | Ayarlar menüsü |

Tüm tuşlar ayarlar menüsünden değiştirilebilir. Gamepad ve direksiyon seti desteklenir.

Arayüz fontu: [Chakra Petch](https://fonts.google.com/specimen/Chakra+Petch) (SIL Open Font License, `fonts/OFL.txt`).

