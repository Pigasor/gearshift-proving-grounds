# GearShift Proving Grounds

Godot 4.3 ile geliştirilen, fizik ağırlıklı bir araç sürüş ve mekanik test sahası oyunu.

## Özellikler

- **Gerçekçi sürüş fiziği:** Raycast süspansiyon, tekerlek başına dönüş ve patinaj, lastik sürtünme çemberi, ağırlık transferi, hava direnci ve aerodinamik bastırma kuvveti
- **Lastik efektleri:** Patinaj, kilitlenme ve driftte zemine göre lastik izi (asfaltta siyah, çimde ezik iz, toprakta tekerlek izi), asfaltta lastik dumanı, çim/toprak/kumda tekerleğin dönüş yönüne savrulan parçalar; 1. viteste el freni + gaz ile burnout
- **Motor ve şanzıman:** Yakıt kesmeli devir kesici, motor freni, rev-matching, araç hızına göre vites seçen otomatik şanzıman ve manuel mod
- **14 araç, 22 motor seçeneği:** Spor ve süper arabalar, NASCAR stok arabası, canavar kamyon, traktör, 4x4 tüp şasili buggy (görünür amortisörler), gerçek ölçülü aile sedanları ve klasik arkadan itişli Tofash Sahin (benzinli / dizel motorlar, gerçek tork eğrileri, GPU parçacıklı egzoz dumanı ve turbo alevi)
- **Harita:** Havalimanı (pist 18/36, taksi yolları, apron, terminal, kule, hangarlar), tribünlü ve seyircili 1 millik NASCAR stadyumu, 110 m yüksekliğinde dağ (zirveye dolambaçlı asfalt yol + taşlı, çalılı, devrik ağaçlı dik off-road yokuşu), yarış pisti ve tur zamanlayıcı, eğimli virajlı otoyol halkası, drift alanı, stunt parkı, off-road alanı ve tepe parkı
- **Garaj (sekmeli, her ayarda açıklama balonu):** Araç / Motor / Süspansiyon / Sürüş — motor gücü (50-2000 HP), turbo, süspansiyon, kamber, tutuş, çekiş tipi, ABS/TCS ayarları
- **Ayarlar menüsü (ESC):** Dil (English / Türkçe), görüntü, grafik, ses, kontroller, tuş atamaları ve direksiyon seti kurulumu
- **Direksiyon seti desteği:** Otomatik eksen/pedal algılama; gaz, fren, debriyaj, el freni (buton veya analog kol), vites kulakçıkları ve H vites kolu
- **Mini harita** (N: yakın / geniş)

## Çalıştırma

1. [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) indir.
2. Godot'yu aç, **Import** ile bu klasördeki `project.godot` dosyasını seç ve çalıştır (F5).

Windows'ta Godot exe'sini proje klasörüne koyarsan `play.bat` ile de başlatabilirsin.

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
| C | Kamera |
| T | Ağır çekim |
| R | Aracı düzelt: ters dönünce olduğu yere dik bırakır (gamepad: Y) |
| TAB | Garaj (araç ve motor seçimi, ayarlar) |
| ESC | Ayarlar menüsü |

Tüm tuşlar ayarlar menüsünden değiştirilebilir. Gamepad ve direksiyon seti desteklenir.

Arayüz fontu: [Chakra Petch](https://fonts.google.com/specimen/Chakra+Petch) (SIL Open Font License, `fonts/OFL.txt`).
