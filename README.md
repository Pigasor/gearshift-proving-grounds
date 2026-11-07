# GearShift Proving Grounds

Godot 4.3 ile geliştirilen, fizik ağırlıklı bir araç sürüş ve mekanik test sahası oyunu.

## Özellikler

- **Gerçekçi sürüş fiziği:** Raycast süspansiyon, tekerlek başına dönüş ve patinaj, lastik sürtünme çemberi, ağırlık transferi, hava direnci ve aerodinamik bastırma kuvveti
- **Motor ve şanzıman:** Yakıt kesmeli devir kesici, motor freni, rev-matching, araç hızına göre vites seçen otomatik şanzıman ve manuel mod
- **10 araç, 16 motor seçeneği:** Spor ve süper arabalar, canavar kamyon ve gerçek ölçülü aile sedanları (benzinli / dizel motorlar, gerçek tork eğrileri)
- **Harita:** Havalimanı (pist 18/36, taksi yolları, apron, terminal, kule, hangarlar), yarış pisti ve tur zamanlayıcı, eğimli virajlı otoyol halkası, drift alanı, stunt parkı, off-road alanı ve tepe parkı
- **Garaj:** Motor gücü, turbo, süspansiyon, kamber, tutuş, çekiş tipi, ABS/TCS ayarları
- **Ayarlar menüsü (ESC):** Görüntü, grafik, ses, kontroller, tuş atamaları ve direksiyon seti kurulumu
- **Direksiyon seti desteği:** Otomatik eksen/pedal algılama, debriyaj, vites kulakçıkları
- **Mini harita** (N: yakın / geniş)

## Çalıştırma

1. [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) indir.
2. Godot'yu aç, **Import** ile bu klasördeki `project.godot` dosyasını seç ve çalıştır (F5).

Windows'ta Godot exe'sini proje klasörüne koyarsan `play.bat` ile de başlatabilirsin.

## Kontroller

| Tuş | Eylem |
|---|---|
| W / S | Gaz / Fren (durunca geri vites) |
| A / D | Direksiyon |
| Space | El freni |
| Shift | Turbo boost |
| E / Q | Vites yükselt / düşür (manuel) |
| M | Otomatik / manuel şanzıman |
| N | Mini harita yakın / geniş |
| C | Kamera |
| T | Ağır çekim |
| TAB | Garaj (araç ve motor seçimi, ayarlar) |
| ESC | Ayarlar menüsü |

Tüm tuşlar ayarlar menüsünden değiştirilebilir. Gamepad ve direksiyon seti desteklenir.

Arayüz fontu: [Saira](https://fonts.google.com/specimen/Saira) (SIL Open Font License, onts/OFL.txt).
