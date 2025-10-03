-- PROJE: Online Alışveriş Sistemi
-- Açıklama:
-- Bu veritabanı; müşteri, ürün, kategori, satıcı ve sipariş
-- tablolarını içerir. Ayrıca örnek veri ekleme, güncelleme,
-- raporlama sorguları ve ileri seviye analizler mevcuttur.

-- Temizlik 
DROP TABLE IF EXISTS siparis_detay CASCADE;
DROP TABLE IF EXISTS siparis CASCADE;
DROP TABLE IF EXISTS urun CASCADE;
DROP TABLE IF EXISTS musteri CASCADE;
DROP TABLE IF EXISTS kategori CASCADE;
DROP TABLE IF EXISTS satici CASCADE;

-- A. TABLOLAR VE İLİŞKİLER

-- Müşteri
CREATE TABLE musteri (
    id SERIAL PRIMARY KEY,
    ad VARCHAR(100) NOT NULL,
    soyad VARCHAR(100) NOT NULL,
    email VARCHAR(200) UNIQUE NOT NULL,
    sehir VARCHAR(100),
    kayit_tarihi TIMESTAMP DEFAULT now()
);

-- Kategori
CREATE TABLE kategori (
    id SERIAL PRIMARY KEY,
    ad VARCHAR(100) NOT NULL UNIQUE
);

-- Satıcı
CREATE TABLE satici (
    id SERIAL PRIMARY KEY,
    ad VARCHAR(150) NOT NULL,
    adres TEXT
);

-- Ürün
CREATE TABLE urun (
    id SERIAL PRIMARY KEY,
    ad VARCHAR(200) NOT NULL,
    fiyat NUMERIC(12,2) NOT NULL CHECK (fiyat >= 0),
    stok INT NOT NULL DEFAULT 0,
    kategori_id INT NOT NULL REFERENCES kategori(id) ON DELETE RESTRICT,
    satici_id INT NOT NULL REFERENCES satici(id) ON DELETE RESTRICT
);

-- Sipariş
CREATE TABLE siparis (
    id SERIAL PRIMARY KEY,
    musteri_id INT NOT NULL REFERENCES musteri(id) ON DELETE RESTRICT,
    tarih TIMESTAMP DEFAULT now(),
    toplam_tutar NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (toplam_tutar >= 0),
    odeme_turu VARCHAR(50) NOT NULL
);

-- Sipariş Detay
CREATE TABLE siparis_detay (
    id SERIAL PRIMARY KEY,
    siparis_id INT NOT NULL REFERENCES siparis(id) ON DELETE CASCADE,
    urun_id INT NOT NULL REFERENCES urun(id) ON DELETE RESTRICT,
    adet INT NOT NULL CHECK (adet > 0),
    fiyat NUMERIC(12,2) NOT NULL CHECK (fiyat >= 0),
    created_at TIMESTAMP DEFAULT now(),
    CONSTRAINT unique_siparis_urun UNIQUE (siparis_id, urun_id)
);

-- İndeksler
CREATE INDEX idx_urun_kategori ON urun(kategori_id);
CREATE INDEX idx_urun_satici ON urun(satici_id);
CREATE INDEX idx_siparis_musteri ON siparis(musteri_id);
CREATE INDEX idx_siparis_tarih ON siparis(tarih);

-- B. TRIGGER & TRIGGER FONKSİYONLARI
-- 1) Sipariş toplamını siparis_detay üzerinden hesaplayan fonksiyon
CREATE OR REPLACE FUNCTION fn_recalc_siparis_toplam() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    target_siparis_id INT;
BEGIN
    -- Hangi sipariş id'si etkilendiğini belirle 
    IF (TG_OP = 'INSERT') THEN
        target_siparis_id := NEW.siparis_id;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- update sırasında eski ve yeni siparis_id farklı olabilir
        target_siparis_id := COALESCE(NEW.siparis_id, OLD.siparis_id);
    ELSE
        target_siparis_id := OLD.siparis_id;
    END IF;

    -- Recalculate toplam_tutar for that siparis
    UPDATE siparis
    SET toplam_tutar = COALESCE((
        SELECT SUM(adet * fiyat) FROM siparis_detay WHERE siparis_id = target_siparis_id
    ), 0)
    WHERE id = target_siparis_id;

    RETURN NULL; -- AFTER trigger
END;
$$;

-- 2) Stoğu siparis_detay insert/delete/update ile senkronize eden fonksiyon
CREATE OR REPLACE FUNCTION fn_adjust_stok() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        -- reduce stock
        UPDATE urun SET stok = stok - NEW.adet WHERE id = NEW.urun_id;
    ELSIF (TG_OP = 'DELETE') THEN
        -- restore stock
        UPDATE urun SET stok = stok + OLD.adet WHERE id = OLD.urun_id;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- handle possible urun_id/adet changes
        IF (OLD.urun_id = NEW.urun_id) THEN
            -- same product: adjust by difference
            UPDATE urun SET stok = stok - (NEW.adet - OLD.adet) WHERE id = NEW.urun_id;
        ELSE
            -- different product: restore old, reduce new
            UPDATE urun SET stok = stok + OLD.adet WHERE id = OLD.urun_id;
            UPDATE urun SET stok = stok - NEW.adet WHERE id = NEW.urun_id;
        END IF;
    END IF;

    RETURN NULL;
END;
$$;

-- Trigger'ları oluştur
CREATE TRIGGER trg_recalc_toplam_after_insert
AFTER INSERT OR UPDATE OR DELETE ON siparis_detay
FOR EACH ROW EXECUTE PROCEDURE fn_recalc_siparis_toplam();

CREATE TRIGGER trg_adjust_stok_after_insert
AFTER INSERT OR UPDATE OR DELETE ON siparis_detay
FOR EACH ROW EXECUTE PROCEDURE fn_adjust_stok();

-- C. ÖRNEK VERİ EKLEME (TRIGGER'LAR HAZIR; böylece stok ve toplam otomatik güncellenecek)

-- Müşteriler
INSERT INTO musteri (ad, soyad, email, sehir) VALUES
('Burak', 'Şahin', 'burak.sahin@example.com', 'İstanbul'),
('Zeynep', 'Aydın', 'zeynep.aydin@example.com', 'Ankara'),
('Emre', 'Koç', 'emre.koc@example.com', 'İzmir'),
('Hatice', 'Arslan', 'hatice.arslan@example.com', 'Bursa'),
('Murat', 'Doğan', 'murat.dogan@example.com', 'Antalya'),
('Gamze', 'Çetin', 'gamze.cetin@example.com', 'Adana'),
('Can', 'Polat', 'can.polat@example.com', 'Konya'),
('Selin', 'Güneş', 'selin.gunes@example.com', 'Gaziantep'),
('Tolga', 'Kurt', 'tolga.kurt@example.com', 'Kayseri'),
('Derya', 'Öztürk', 'derya.ozturk@example.com', 'Samsun'),
('Onur', 'Yıldırım', 'onur.yildirim@example.com', 'Trabzon'),
('Merve', 'Kaplan', 'merve.kaplan@example.com', 'Eskişehir'),
('Hakan', 'Ekinci', 'hakan.ekinci@example.com', 'Mersin'),
('Sevgi', 'Kara', 'sevgi.kara@example.com', 'Malatya'),
('Oğuz', 'Taş', 'oguz.tas@example.com', 'Diyarbakır'),
('Aslı', 'Aksoy', 'asli.aksoy@example.com', 'Manisa'),
('Kaan', 'Bozkurt', 'kaan.bozkurt@example.com', 'Sakarya'),
('Nazlı', 'Ergin', 'nazli.ergin@example.com', 'Kocaeli'),
('Cem', 'Uçar', 'cem.ucar@example.com', 'Balıkesir'),
('Şule', 'Sezer', 'sule.sezer@example.com', 'Çanakkale');

-- Kategoriler
INSERT INTO kategori (ad) VALUES
('Elektronik'), ('Giyim'), ('Ev & Yaşam'), ('Kitap');

-- Satıcılar
INSERT INTO satici (ad, adres) VALUES
('SmartTech A.Ş.', 'İstanbul'),
('Moda Mağazacılık', 'Ankara'),
('EvDekor Ltd.', 'İzmir');

-- Ürünler (ilk stok ve fiyat belirleniyor)
INSERT INTO urun (ad, fiyat, stok, kategori_id, satici_id)
VALUES
('Akıllı Telefon X', 8500, 15, 1, 1),
('Kablosuz Kulaklık', 800, 40, 1, 1),
('Kadın Tişört', 150, 60, 2, 2),
('Dekoratif Vazo', 200, 25, 3, 3),
('Roman: Hayat', 60, 100, 4, 3);

-- SİPARİŞLER + SİPARİŞ DETAYLARI

-- 1. Burak Şahin → Telefon + Kulaklık
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Kredi Kartı' FROM musteri WHERE email='burak.sahin@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='burak.sahin@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Akıllı Telefon X'), 1, 8500
),
(
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='burak.sahin@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Kablosuz Kulaklık'), 1, 800
);

-- 2. Zeynep Aydın → Tişört + Kitap
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Havale' FROM musteri WHERE email='zeynep.aydin@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='zeynep.aydin@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Kadın Tişört'), 1, 160
),
(
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='zeynep.aydin@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Roman: Hayat'), 1, 60
);

-- 3. Emre Koç → Telefon
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Kapıda Ödeme' FROM musteri WHERE email='emre.koc@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='emre.koc@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Akıllı Telefon X'), 1, 8500
);

-- 4. Hatice Arslan → Kulaklık + Kitap
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Kredi Kartı' FROM musteri WHERE email='hatice.arslan@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='hatice.arslan@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Kablosuz Kulaklık'), 1, 800
),
(
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='hatice.arslan@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Roman: Hayat'), 1, 60
);

-- 5. Murat Doğan → Tişört
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Havale' FROM musteri WHERE email='murat.dogan@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='murat.dogan@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Kadın Tişört'), 1, 160
);

-- 6. Gamze Çetin → Telefon + Kitap
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Kredi Kartı' FROM musteri WHERE email='gamze.cetin@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='gamze.cetin@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Akıllı Telefon X'), 1, 8500
),
(
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='gamze.cetin@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Roman: Hayat'), 1, 60
);

-- 7. Can Polat → Kulaklık
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Kapıda Ödeme' FROM musteri WHERE email='can.polat@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='can.polat@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Kablosuz Kulaklık'), 1, 800
);

-- 8. Selin Güneş → Tişört + Kitap
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Havale' FROM musteri WHERE email='selin.gunes@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='selin.gunes@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Kadın Tişört'), 1, 160
),
(
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='selin.gunes@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Roman: Hayat'), 1, 60
);

-- 9. Tolga Kurt → Telefon
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Kredi Kartı' FROM musteri WHERE email='tolga.kurt@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='tolga.kurt@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Akıllı Telefon X'), 1, 8500
);

-- 10. Derya Öztürk → Kulaklık + Kitap
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Kapıda Ödeme' FROM musteri WHERE email='derya.ozturk@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='derya.ozturk@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Kablosuz Kulaklık'), 1, 800
),
(
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='derya.ozturk@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Roman: Hayat'), 1, 60
);

-- 11. Onur Yıldırım → Tişört
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Havale' FROM musteri WHERE email='onur.yildirim@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='onur.yildirim@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Kadın Tişört'), 1, 160
);

-- 12. Merve Kaplan → Telefon + Kitap
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Kredi Kartı' FROM musteri WHERE email='merve.kaplan@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='merve.kaplan@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Akıllı Telefon X'), 1, 8500
),
(
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='merve.kaplan@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Roman: Hayat'), 1, 60
);

-- 13. Hakan Ekinci → Kulaklık
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Kapıda Ödeme' FROM musteri WHERE email='hakan.ekinci@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='hakan.ekinci@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Kablosuz Kulaklık'), 1, 800
);

-- 14. Sevgi Kara → Tişört + Kitap
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Havale' FROM musteri WHERE email='sevgi.kara@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='sevgi.kara@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Kadın Tişört'), 1, 160
),
(
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='sevgi.kara@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Roman: Hayat'), 1, 60
);

-- 15. Oğuz Taş → Telefon
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Kredi Kartı' FROM musteri WHERE email='oguz.tas@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='oguz.tas@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Akıllı Telefon X'), 1, 8500
);

-- 16. Aslı Aksoy → Kulaklık + Kitap
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Kapıda Ödeme' FROM musteri WHERE email='asli.aksoy@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='asli.aksoy@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Kablosuz Kulaklık'), 1, 800
),
(
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='asli.aksoy@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Roman: Hayat'), 1, 60
);

-- 17. Kaan Bozkurt → Tişört
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Havale' FROM musteri WHERE email='kaan.bozkurt@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='kaan.bozkurt@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Kadın Tişört'), 1, 160
);

-- 18. Nazlı Ergin → Telefon + Kitap
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Kredi Kartı' FROM musteri WHERE email='nazli.ergin@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='nazli.ergin@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Akıllı Telefon X'), 1, 8500
),
(
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='nazli.ergin@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Roman: Hayat'), 1, 60
);

-- 19. Cem Uçar → Kulaklık
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Kapıda Ödeme' FROM musteri WHERE email='cem.ucar@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='cem.ucar@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Kablosuz Kulaklık'), 1, 800
);

-- 20. Şule Sezer → Tişört + Kitap
INSERT INTO siparis (musteri_id, odeme_turu)
SELECT id, 'Havale' FROM musteri WHERE email='sule.sezer@example.com';
INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES (
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='sule.sezer@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Kadın Tişört'), 1, 160
),
(
  (SELECT id FROM siparis WHERE musteri_id=(SELECT id FROM musteri WHERE email='sule.sezer@example.com') ORDER BY id DESC LIMIT 1),
  (SELECT id FROM urun WHERE ad='Roman: Hayat'), 1, 60
);

-- D. GÜNCELLEMELER / TEMİZLİK / ÖRNEK SORGULAR

-- 1) Eğer ürün fiyatını güncellerseniz, geçmiş siparişlerin fiyatları siparis_detay'da saklandığı için
--    geçmiş siparişlerin toplamı bozulmaz. Yine de isterseniz ürün fiyatını güncelle:
UPDATE urun
SET fiyat = 160
WHERE ad = 'Kadın Tişört';
-- 2) Eğer mevcut veritabanında trigger'lar sonradan eklendiyse ve mevcut tüm siparişlerin toplamlarının düzeltilmesini isterseniz:
UPDATE siparis s
SET toplam_tutar = COALESCE((SELECT SUM(adet * fiyat) FROM siparis_detay sd WHERE sd.siparis_id = s.id), 0);

-- 3) Eğer mevcut stoklarda tutarsızlık varsa (ör. trigger'lar sonradan eklendi) stokları yeniden hesaplamak için:
WITH satilan AS (
  SELECT urun_id, COALESCE(SUM(adet), 0) AS toplam_satilan
  FROM siparis_detay
  GROUP BY urun_id
)
UPDATE urun u
SET stok = u.stok + 0 -- placeholder, replaced by recalculation
FROM (
  SELECT u2.id AS urun_id, (u2.stok + 0 - COALESCE(s.toplam_satilan, 0)) AS recalculated
  FROM urun u2
  LEFT JOIN satilan s ON u2.id = s.urun_id
) recal
WHERE u.id = recal.urun_id;

-- En çok sipariş veren 5 müşteri
SELECT m.id, m.ad, m.soyad, COUNT(s.id) AS siparis_sayisi
FROM musteri m
LEFT JOIN siparis s ON m.id = s.musteri_id
GROUP BY m.id, m.ad, m.soyad
ORDER BY siparis_sayisi DESC
LIMIT 5;

-- En çok satılan ürünler
SELECT u.id, u.ad, SUM(sd.adet) AS toplam_adet
FROM urun u
JOIN siparis_detay sd ON u.id = sd.urun_id
GROUP BY u.id, u.ad
ORDER BY toplam_adet DESC;

-- En yüksek cirosu olan satıcılar
SELECT sa.id, sa.ad AS satici_adi, SUM(sd.adet * sd.fiyat) AS toplam_ciro
FROM satici sa
JOIN urun u ON sa.id = u.satici_id
JOIN siparis_detay sd ON u.id = sd.urun_id
GROUP BY sa.id, sa.ad
ORDER BY toplam_ciro DESC;

-- Şehirlere göre müşteri sayısı
SELECT sehir, COUNT(*) AS musteri_sayisi
FROM musteri
GROUP BY sehir
ORDER BY musteri_sayisi DESC;

-- Kategori bazlı toplam satışlar
SELECT k.ad AS kategori, SUM(sd.adet * sd.fiyat) AS toplam_satis
FROM kategori k
JOIN urun u ON k.id = u.kategori_id
JOIN siparis_detay sd ON u.id = sd.urun_id
GROUP BY k.ad
ORDER BY toplam_satis DESC;

-- Aylara göre sipariş sayısı
SELECT TO_CHAR(DATE_TRUNC('month', s.tarih), 'YYYY-MM') AS yil_ay,
       COUNT(*) AS siparis_sayisi
FROM siparis s
GROUP BY yil_ay
ORDER BY yil_ay;

-- Sipariş detayları (müşteri + ürün + satıcı)
SELECT s.id AS siparis_id, s.tarih,
       m.ad || ' ' || m.soyad AS musteri,
       u.ad AS urun, sd.adet, sd.fiyat,
       sa.ad AS satici
FROM siparis s
JOIN musteri m ON s.musteri_id = m.id
JOIN siparis_detay sd ON s.id = sd.siparis_id
JOIN urun u ON sd.urun_id = u.id
JOIN satici sa ON u.satici_id = sa.id
ORDER BY s.tarih DESC;

-- Hiç satılmamış ürünler
SELECT u.id, u.ad
FROM urun u
LEFT JOIN siparis_detay sd ON u.id = sd.urun_id
WHERE sd.id IS NULL;

-- Hiç sipariş vermemiş müşteriler
SELECT m.id, m.ad, m.soyad
FROM musteri m
LEFT JOIN siparis s ON m.id = s.musteri_id
WHERE s.id IS NULL;

-- Opsiyonel: En çok kazanç sağlayan ilk 3 kategori
SELECT k.id, k.ad AS kategori,
       SUM(sd.adet * sd.fiyat) AS toplam_gelir
FROM kategori k
JOIN urun u ON k.id = u.kategori_id
JOIN siparis_detay sd ON u.id = sd.urun_id
GROUP BY k.id, k.ad
ORDER BY toplam_gelir DESC
LIMIT 3;

-- Opsiyonel: Ortalama sipariş tutarını geçen siparişler
WITH ort AS (
    SELECT AVG(toplam_tutar) AS ortalama_tutar
    FROM siparis
)
SELECT s.id, s.musteri_id, s.toplam_tutar, s.tarih
FROM siparis s, ort
WHERE s.toplam_tutar > ort.ortalama_tutar
ORDER BY s.toplam_tutar DESC;

-- Opsiyonel: En az bir kez elektronik ürün satın alan müşteriler
SELECT DISTINCT m.id, m.ad, m.soyad, m.email, m.sehir
FROM musteri m
JOIN siparis s ON m.id = s.musteri_id
JOIN siparis_detay sd ON s.id = sd.siparis_id
JOIN urun u ON sd.urun_id = u.id
JOIN kategori k ON u.kategori_id = k.id
WHERE k.ad = 'Elektronik'
ORDER BY m.ad, m.soyad;
