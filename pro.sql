-- PROJE: Online Alışveriş Sistemi
-- Açıklama:
-- Bu veritabanı; müşteri, ürün, kategori, satıcı ve sipariş
-- tablolarını içerir. Ayrıca örnek veri ekleme, güncelleme,
-- raporlama sorguları ve ileri seviye analizler mevcuttur.

-- A. TABLOLAR VE İLİŞKİLER

DROP TABLE IF EXISTS siparis_detay CASCADE;
DROP TABLE IF EXISTS siparis CASCADE;
DROP TABLE IF EXISTS urun CASCADE;
DROP TABLE IF EXISTS musteri CASCADE;
DROP TABLE IF EXISTS kategori CASCADE;
DROP TABLE IF EXISTS satici CASCADE;

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
    kategori_id INT NOT NULL REFERENCES kategori(id),
    satici_id INT NOT NULL REFERENCES satici(id)
);

-- Sipariş
CREATE TABLE siparis (
    id SERIAL PRIMARY KEY,
    musteri_id INT NOT NULL REFERENCES musteri(id),
    tarih TIMESTAMP DEFAULT now(),
    toplam_tutar NUMERIC(12,2) NOT NULL CHECK (toplam_tutar >= 0),
    odeme_turu VARCHAR(50) NOT NULL
);

-- Sipariş Detay
CREATE TABLE siparis_detay (
    id SERIAL PRIMARY KEY,
    siparis_id INT NOT NULL REFERENCES siparis(id) ON DELETE CASCADE,
    urun_id INT NOT NULL REFERENCES urun(id),
    adet INT NOT NULL CHECK (adet > 0),
    fiyat NUMERIC(12,2) NOT NULL,
    CONSTRAINT unique_siparis_urun UNIQUE (siparis_id, urun_id)
);

-- İndeksler
CREATE INDEX idx_urun_kategori ON urun(kategori_id);
CREATE INDEX idx_urun_satici ON urun(satici_id);
CREATE INDEX idx_siparis_musteri ON siparis(musteri_id);
CREATE INDEX idx_siparis_tarih ON siparis(tarih);

-- B. VERİ EKLEME VE GÜNCELLEME

-- Müşteriler
INSERT INTO musteri (ad, soyad, email, sehir)
VALUES 
('Ahmet', 'Yılmaz', 'ahmet@example.com', 'İstanbul'),
('Ayşe', 'Demir', 'ayse@example.com', 'Ankara'),
('Mehmet', 'Kaya', 'mehmet@example.com', 'İzmir'),
('Elif', 'Çelik', 'elif@example.com', 'Antalya');

-- Kategoriler
INSERT INTO kategori (ad) VALUES
('Elektronik'), ('Giyim'), ('Ev & Yaşam'), ('Kitap');

-- Satıcılar
INSERT INTO satici (ad, adres) VALUES
('SmartTech A.Ş.', 'İstanbul'),
('Moda Mağazacılık', 'Ankara'),
('EvDekor Ltd.', 'İzmir');

-- Ürünler
INSERT INTO urun (ad, fiyat, stok, kategori_id, satici_id)
VALUES
('Akıllı Telefon X', 8500, 15, 1, 1),
('Kablosuz Kulaklık', 800, 40, 1, 1),
('Kadın Tişört', 150, 60, 2, 2),
('Dekoratif Vazo', 200, 25, 3, 3),
('Roman: Hayat', 60, 100, 4, 3);

-- Insert Into
INSERT INTO siparis (musteri_id, toplam_tutar, odeme_turu)
VALUES (1, 9300, 'Kredi Kartı');

INSERT INTO siparis_detay (siparis_id, urun_id, adet, fiyat)
VALUES 
(1, 1, 1, 8500), -- Telefon
(1, 2, 1, 800);  -- Kulaklık

-- Update
UPDATE urun
SET fiyat = 160
WHERE ad = 'Kadın Tişört';

-- Update sonrası stok takibi
UPDATE urun SET stok = stok - 1 WHERE id = 1;  -- Telefon
UPDATE urun SET stok = stok - 1 WHERE id = 2;  -- Kulaklık

-- Delete
DELETE FROM urun WHERE ad = 'Dekoratif Vazo';

-- Delete (sipariş vermeyen müşteriyi silip alan kazanma işi)
DELETE FROM musteri
WHERE id = 4 AND id NOT IN (SELECT musteri_id FROM siparis);

-- C. VERİ SORGULAMA VE RAPORLAMA

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

-- Siparişlerde müşteri + ürün + satıcı bilgisi
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


-- D. OPSİYONEL GÖREVLER

-- En çok kazanç sağlayan ilk 3 kategori
SELECT k.id, k.ad AS kategori,
       SUM(sd.adet * sd.fiyat) AS toplam_gelir
FROM kategori k
JOIN urun u ON k.id = u.kategori_id
JOIN siparis_detay sd ON u.id = sd.urun_id
GROUP BY k.id, k.ad
ORDER BY toplam_gelir DESC
LIMIT 3;

-- Ortalama sipariş tutarını geçen siparişler
WITH ort AS (
    SELECT AVG(toplam_tutar) AS ortalama_tutar
    FROM siparis
)
SELECT s.id, s.musteri_id, s.toplam_tutar, s.tarih
FROM siparis s, ort
WHERE s.toplam_tutar > ort.ortalama_tutar
ORDER BY s.toplam_tutar DESC;

-- En az bir kez elektronik ürün satın alan müşteriler
SELECT DISTINCT m.id, m.ad, m.soyad, m.email, m.sehir
FROM musteri m
JOIN siparis s ON m.id = s.musteri_id
JOIN siparis_detay sd ON s.id = sd.siparis_id
JOIN urun u ON sd.urun_id = u.id
JOIN kategori k ON u.kategori_id = k.id
WHERE k.ad = 'Elektronik'
ORDER BY m.ad, m.soyad;
