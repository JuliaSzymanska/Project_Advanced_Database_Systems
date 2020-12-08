-- 1. Wyœwietl liczbê pokoi w ka¿dym z hoteli. Na koñcu dodaj podsumowanie ile jest ³¹cznie pokoi.
SELECT IIF(h.nazwa_hotelu IS NULL, 'Suma', h.nazwa_hotelu) AS 'Nazwa Hotelu',
       COUNT(*)                                            AS 'Liczba pokoi'
FROM siec_hoteli.dbo.pokoje p,
     siec_hoteli.dbo.hotele h
WHERE p.id_hotelu = h.id_hotelu
GROUP BY ROLLUP (nazwa_hotelu)
ORDER BY IIF(h.nazwa_hotelu IS NULL, 1, 0),
         [Nazwa Hotelu]
GO

-- 2. Wyœwietl nazwê hotelu, cenê bazow¹ za pokój, nazwê miasta przy tworzeniu rankingu hoteli na podstawie ceny bazowej za 
-- pokój bez przeskoku.  
SELECT nazwa_hotelu,
       cena_bazowa_za_pokoj,
       nazwa_miasta,
       DENSE_RANK() OVER (ORDER BY cena_bazowa_za_pokoj DESC) AS 'Ranking cen pokoi'
FROM siec_hoteli.dbo.hotele h,
     siec_hoteli.dbo.miasta m
WHERE h.id_miasta = m.id_miasta
GO

-- 3. Wyœwietl œredni¹ cenê po³¹czeñ telefonicznych hoteli dla miasta zaokr¹glone do drugiej liczby po przecinku wraz z nazw¹ miasta, 
-- posortowane po œredniej.
SELECT DISTINCT nazwa_miasta,
                ROUND(AVG(cena_za_polaczenie_telefoniczne) OVER (PARTITION BY nazwa_miasta),
                      2) AS 'Srednia cena polaczen telefonicznych'
FROM siec_hoteli.dbo.hotele h,
     siec_hoteli.dbo.miasta m
WHERE h.id_miasta = m.id_miasta
ORDER BY [Srednia cena polaczen telefonicznych] DESC
GO

-- 4. Wyœwietl liczbê pokoi dla których nie przewidziano rezerwacji. 
SELECT nazwa_hotelu, COUNT(id_pokoju) AS 'Liczba pokoi bez rezerwacji'
FROM siec_hoteli.dbo.pokoje,
     siec_hoteli.dbo.hotele
WHERE id_pokoju NOT IN (SELECT id_pokoju FROM siec_hoteli.dbo.rezerwacje)
  AND pokoje.id_hotelu = hotele.id_hotelu
GROUP BY nazwa_hotelu
ORDER BY [Liczba pokoi bez rezerwacji] DESC
GO


-- 5. Wyœwietl piêæ najbli¿szych dat rezerwacji i rezerwacje przewidziane na te daty.
SELECT r1.id_rezerwacji, r1.data_rezerwacji, r1.liczba_dni_rezerwacji
FROM siec_hoteli.dbo.rezerwacje r1
WHERE r1.data_rezerwacji IN
      (SELECT DISTINCT TOP 5 r2.data_rezerwacji
       FROM siec_hoteli.dbo.rezerwacje r2
       WHERE r2.data_rezerwacji > GETDATE()
       ORDER BY r2.data_rezerwacji)
ORDER BY r1.data_rezerwacji
GO

-- 6. Wyœwietl imiona, nazwiska, adresy klientów, którzy mieszkaj¹ w Hiszpani.
SELECT imie_klienta, nazwisko_klienta, adres_zamieszkania
FROM siec_hoteli.dbo.klienci
WHERE adres_zamieszkania LIKE '%Hiszpania%'
GO

-- 7. Wyœwietl wszystkie rezerwacje przewidziane na miesi¹c lipiec, które jeszcze siê nie odby³y.
SELECT id_rezerwacji, liczba_dni_rezerwacji, data_rezerwacji
FROM siec_hoteli.dbo.rezerwacje
WHERE MONTH(data_rezerwacji) = 7
  AND data_rezerwacji > GETDATE()
ORDER BY id_rezerwacji
GO

-- 8. Wyœwietl id_sprzatania, id_pokoju, czas trwania sprzatania jako czas_trwania wszystkich pe³nych sprz¹tañ.
SELECT id_sprzatania,
       id_pokoju,
       CAST(data_rozpoczecia_sprzatania AS DATE)                                    AS 'Data rozpoczecia sprzatania',
       CAST(data_rozpoczecia_sprzatania AS TIME(0))                                 AS 'Godzina rozpoczecia sprzatania',
       CAST((data_zakonczenia_sprzatania - data_rozpoczecia_sprzatania) AS TIME(0)) AS 'Czas trwania'
FROM siec_hoteli.dbo.sprzatanie
WHERE rodzaj_sprzatania = 'Pelne'
ORDER BY data_rozpoczecia_sprzatania
GO

-- 9. Wyœwietl wszystkie rozmowy telefoniczne, które trwa³y d³u¿ej ni¿ 5 minut.
SELECT *
FROM siec_hoteli.dbo.rozmowy_telefoniczne r
WHERE DATEDIFF(MINUTE, r.data_rozpoczecia_rozmowy, r.data_zakonczenia_rozmowy) > 5
ORDER BY data_rozpoczecia_rozmowy
GO

-- 10. Wyœwietl wszystkich klientow, ktorzy dzownili z telefonu pokojowego do innych klientow. 
SELECT k1.imie_klienta + ' ' + k1.nazwisko_klienta 'Imie i nazwisko odbiorcy',
       k1.numer_telefonu_klienta                   'Numer telefonu odbiorcy',
       k2.imie_klienta + ' ' + k2.nazwisko_klienta 'Imie i nazwisko dzowniacego',
       p.numer_telefonu_pokoju                     'Numer telefonu pokoju'
FROM siec_hoteli.dbo.klienci k1,
     siec_hoteli.dbo.klienci k2,
     siec_hoteli.dbo.pokoje p,
     siec_hoteli.dbo.rozmowy_telefoniczne rt,
     siec_hoteli.dbo.rezerwacje rez
WHERE rt.numer_telefonu = k1.numer_telefonu_klienta
  AND rt.id_pokoju = p.id_pokoju
  AND p.id_pokoju = rez.id_pokoju
  AND rez.id_klienta = k2.id_klienta
  AND rez.data_rezerwacji < rt.data_rozpoczecia_rozmowy
  AND DATEADD(DAY, rez.liczba_dni_rezerwacji, rez.data_rezerwacji) > rt.data_rozpoczecia_rozmowy


-- 11. Wyswietl pracownikow, ktorzy maja najwieksza pensje w danym hotelu. 
SELECT p.imie_pracownika + ' ' + p.nazwisko_pracownika pracownik, p.pensja, h.nazwa_hotelu
FROM siec_hoteli.dbo.pracownicy p,
     siec_hoteli.dbo.hotele h
WHERE p.pensja IN (SELECT MAX(pensja) FROM siec_hoteli.dbo.pracownicy p2 WHERE p2.id_hotelu = p.id_hotelu)
  AND p.id_hotelu = h.id_hotelu
ORDER BY p.nazwisko_pracownika


-- 12. Wyswietl pracownikow z archiwum pracownikow, ktorzy pracuja dluzej niz srednia dlugosc pracy w tym miescie. 
SELECT p.imie_pracownika + ' ' + p.nazwisko_pracownika 'Imie i nazwisko pracownika', m.nazwa_miasta
FROM siec_hoteli.dbo.pracownicy p,
     siec_hoteli.dbo.archiwum_pracownikow ap,
     siec_hoteli.dbo.hotele h,
     siec_hoteli.dbo.miasta m
WHERE ap.id_pracownika = p.id_pracownika
  AND p.id_hotelu = h.id_hotelu
  AND h.id_miasta = m.id_miasta
  AND DATEDIFF(DAY, p.poczatek_pracy, ap.koniec_pracy) > (
    SELECT AVG(DATEDIFF(DAY, p2.poczatek_pracy, ap2.koniec_pracy))
    FROM siec_hoteli.dbo.pracownicy p2,
         siec_hoteli.dbo.archiwum_pracownikow ap2,
         siec_hoteli.dbo.hotele h2,
         siec_hoteli.dbo.miasta m2
    WHERE ap2.id_pracownika = p2.id_pracownika
      AND p2.id_hotelu = h2.id_hotelu
      AND h2.id_miasta = m2.id_miasta
      AND m2.id_miasta = m.id_miasta
    GROUP BY m2.id_miasta)
GROUP BY m.nazwa_miasta, p.imie_pracownika, p.nazwisko_pracownika, p.poczatek_pracy, ap.koniec_pracy


-- 13. Wyœwietla panstwo, w ktorym najwiecej sie wydaje na oplacenie pracownikow.

SELECT SUM(p.pensja) suma, pan.nazwa_panstwa
FROM siec_hoteli..panstwa pan,
     siec_hoteli..miasta m,
     siec_hoteli..hotele h,
     siec_hoteli..pracownicy p,
     (SELECT MAX(a.suma) AS max_suma
      FROM (
               SELECT SUM(p.pensja) suma
               FROM siec_hoteli..panstwa pan,
                    siec_hoteli..miasta m,
                    siec_hoteli..hotele h,
                    siec_hoteli..pracownicy p
               WHERE pan.id_panstwa = m.id_panstwa
                 AND m.id_miasta = h.id_miasta
                 AND p.id_hotelu = h.id_hotelu
               GROUP BY pan.nazwa_panstwa
           ) AS a) AS pms
WHERE pan.id_panstwa = m.id_panstwa
  AND m.id_miasta = h.id_miasta
  AND p.id_hotelu = h.id_hotelu
GROUP BY pan.nazwa_panstwa, pms.max_suma
HAVING SUM(p.pensja) = max_suma

-- 14. Wypisz klienta który mia³ najwiecej skonczonych rezerwacji. 
SELECT k.imie_klienta, k.nazwisko_klienta, COUNT(k.id_klienta) ilosc_rezerwacji
FROM siec_hoteli..klienci k,
     siec_hoteli..rezerwacje r
WHERE k.id_klienta = r.id_klienta
  AND DATEADD(DAY, r.liczba_dni_rezerwacji, r.data_rezerwacji) < GETDATE()
GROUP BY k.id_klienta, imie_klienta, nazwisko_klienta, numer_telefonu_klienta, adres_zamieszkania
HAVING COUNT(k.id_klienta) = (SELECT TOP 1 COUNT(k.id_klienta)
                              FROM siec_hoteli..klienci k,
                                   siec_hoteli..rezerwacje r
                              WHERE k.id_klienta = r.id_klienta
                                AND DATEADD(DAY, r.liczba_dni_rezerwacji, r.data_rezerwacji) < GETDATE()
                              GROUP BY k.id_klienta
                              ORDER BY COUNT(k.id_klienta) DESC)


-- 15. Wypisz najwiecej sprz¹tany pokój.
SELECT p.id_pokoju, COUNT(*) 'Ilosc sprzatan'
FROM siec_hoteli..pokoje p,
     siec_hoteli..sprzatanie s
WHERE p.id_pokoju = s.id_pokoju
GROUP BY p.id_pokoju
HAVING (COUNT(p.id_pokoju)) = (SELECT TOP 1 COUNT(*) count
                               FROM siec_hoteli..pokoje p,
                                    siec_hoteli..sprzatanie s
                               WHERE p.id_pokoju = s.id_pokoju
                               GROUP BY p.id_pokoju
                               ORDER BY count DESC)

--16. Wyswietl najczesciej wykupowana usluge
SELECT COUNT(*) ilosc, u.nazwa_uslugi 'Nazwa uslugi'
FROM siec_hoteli..uslugi u,
     siec_hoteli..usluga_dla_rezerwacji ur
WHERE ur.id_uslugi = u.id_uslugi
GROUP BY u.nazwa_uslugi
HAVING COUNT(*) = (SELECT MAX(i.ile)
                   FROM (SELECT COUNT(*) 'Ile', us.id_uslugi 'Usluga'
                         FROM siec_hoteli..usluga_dla_rezerwacji us
                         GROUP BY us.id_uslugi) i)


-- 17. Wyswietl nazwe hotelu, miasto oraz panstwo, w ktorych znajduje sie hotel, a takze kwote, dla hotelu, dla ktorego byla najdrozsza rezerwacja. 
SELECT h.nazwa_hotelu, m.nazwa_miasta, pan.nazwa_panstwa, max_kwota.[Kwota rezerwacji]
FROM (SELECT MAX(ar2.cena_calkowita) 'Kwota rezerwacji' FROM siec_hoteli..archiwum_rezerwacji ar2) max_kwota,
     siec_hoteli..archiwum_rezerwacji ar,
     siec_hoteli..rezerwacje r,
     siec_hoteli..pokoje p,
     siec_hoteli..hotele h,
     siec_hoteli..miasta m,
     siec_hoteli..panstwa pan
WHERE max_kwota.[Kwota rezerwacji] = ar.cena_calkowita
  AND ar.id_rezerwacji = r.id_rezerwacji
  AND r.id_pokoju = p.id_pokoju
  AND p.id_hotelu = h.id_hotelu
  AND h.id_miasta = m.id_miasta
  AND m.id_panstwa = pan.id_panstwa


-- 18 Wypisz klijentów, którzy mieli rezerwacje, posortowani po sumie wartoœci ich rezerwacji
SELECT SUM(h.cena_bazowa_za_pokoj * r.liczba_dni_rezerwacji) suma, k.imie_klienta, k.nazwisko_klienta
FROM siec_hoteli..klienci k,
     siec_hoteli..rezerwacje r,
     siec_hoteli..pokoje p,
     siec_hoteli..hotele h
WHERE k.id_klienta = r.id_klienta
  AND r.id_pokoju = p.id_pokoju
  AND h.id_hotelu = p.id_hotelu
GROUP BY k.id_klienta, k.imie_klienta, k.nazwisko_klienta
ORDER BY suma DESC



--------------------------------------------------------- FUNKCJA ---------------------------------------------------------------------------------------
-- 10. Wyœwietl id_rezerwacji, licza_dni_rezerwacji, data_rezerwacji oraz datê wymeldowania jako data_wymeldowania.
--SELECT id_rezerwacji, liczba_dni_rezerwacji, data_rezerwacji, DATEADD(DAY, liczba_dni_rezerwacji, data_rezerwacji) AS data_wymeldowania
--FROM rezerwacje
--GO

------------------------------------------------- FUNKCJA ----------------------------------------------------------------
-- 16. Podwy¿sz wszystkim hotelom cenê bazow¹ za pokój o 5%.
--UPDATE hotele
--SET cena_bazowa_za_pokoj = 1.05 * cena_bazowa_za_pokoj
--SELECT id_hotelu, cena_bazowa_za_pokoj
--FROM hotele
--GO


-- 17. Dodaj funkcjê zwracaj¹c¹ wspó³czynnik z jakim trzeba bêdzie pomno¿yæ cenê za po³¹czenie telefoniczne. Funkcja ma przyjmowaæ dwa argumenty:
-- numer_telefonu, id_pokoju. Jeœli numer telefonu, na który zosta³o wykonane po³¹czenie nale¿y do któregoœ z pokoi w hotelu z którego wykonano po³¹czenie 
-- (na podstawie id_pokoju uzyskujemy id_hotelu z którego wykonano po³¹czenie) wtedy wspó³czynnik ustawiany jest na 0. Dla numeru telefonu pokoju znajduj¹cego 
-- siê w innym hotelu wspó³czynnik ustawiany jest na 0.5, dla numerów telefonów spoza hotelu wspó³czynnik ustawiany jest na 1.

GO
CREATE OR
ALTER FUNCTION oblicz_wspoczynnik(@numer_telefonu VARCHAR(9),
                                  @id_pokoju INT)
    RETURNS FLOAT(2)
AS
BEGIN
    DECLARE @wspolczynnik FLOAT(2);

    IF EXISTS(SELECT *
              FROM siec_hoteli.dbo.pokoje p
              WHERE p.numer_telefonu_pokoju = @numer_telefonu
                AND p.id_hotelu = (SELECT id_hotelu
                                   FROM siec_hoteli.dbo.pokoje p
                                   WHERE p.id_pokoju = @id_pokoju))
        BEGIN
            SET @wspolczynnik = 0.00
        END
    ELSE
        IF EXISTS(SELECT *
                  FROM siec_hoteli.dbo.pokoje p
                  WHERE @numer_telefonu = p.numer_telefonu_pokoju
                    AND p.id_hotelu != (SELECT id_hotelu
                                        FROM siec_hoteli.dbo.pokoje p
                                        WHERE @id_pokoju = p.id_pokoju))
            BEGIN
                SET @wspolczynnik = 0.50
            END
        ELSE
            BEGIN
                SET @wspolczynnik = 1.00
            END
    RETURN @wspolczynnik;
END;
GO

--SELECT * FROM siec_hoteli..archiwum_rezerwacji

--UPDATE siec_hoteli..archiwum_rezerwacji
--SET cena_za_telefon = t.suma_cen
--FROM 
--    (
--        SELECT r.id_pokoju, rt.data_rozpoczecia_rozmowy,
--		SUM(DATEDIFF(MINUTE, rt.data_rozpoczecia_rozmowy, rt.data_zakonczenia_rozmowy) * h.cena_za_polaczenie_telefoniczne *  dbo.oblicz_wspoczynnik(rt.numer_telefonu, rt.id_pokoju)) suma_cen
--        FROM siec_hoteli..rozmowy_telefoniczne rt, siec_hoteli..hotele h, siec_hoteli..pokoje p, siec_hoteli..archiwum_rezerwacji ar, siec_hoteli..rezerwacje r
--        WHERE ar.id_rezerwacji = r.id_rezerwacji
--		AND r.id_pokoju = p.id_pokoju
--		AND rt.id_pokoju = p.id_pokoju
--		AND p.id_hotelu = h.id_hotelu
--		AND r.data_rezerwacji < rt.data_rozpoczecia_rozmowy
--		AND DATEADD(DAY, r.liczba_dni_rezerwacji, r.data_rezerwacji) > rt.data_rozpoczecia_rozmowy
--        GROUP BY r.id_pokoju, rt.data_rozpoczecia_rozmowy
--    ) t, siec_hoteli..rezerwacje r2
--WHERE siec_hoteli..archiwum_rezerwacji.id_rezerwacji = r2.id_rezerwacji
--AND r2.id_pokoju = t.id_pokoju
--AND r2.data_rezerwacji < t.data_rozpoczecia_rozmowy
--AND DATEADD(DAY, r2.liczba_dni_rezerwacji, r2.data_rezerwacji) > t.data_rozpoczecia_rozmowy

--SELECT * FROM siec_hoteli..archiwum_rezerwacji


--19. Stworz procedure, która pracownikowi o zadanym id zwiekszy premie o zadany procent. Oba argumenty posiadaja wartosci domysle, 
-- dla procentu jest to 1%, natomiast jestli nie zostalo podane id pracownika, wszystkim pracownikom podwyzsz premie.
GO
DROP PROCEDURE IF EXISTS premia_procedura
GO
CREATE PROCEDURE premia_procedura @id INT = -1, @procent INT = 1
AS
BEGIN
    IF @id = -1
        BEGIN
            UPDATE siec_hoteli.dbo.pracownicy
            SET premia = 0
            WHERE premia IS NULL;

            UPDATE siec_hoteli.dbo.pracownicy
            SET premia = premia * ((100.00 + @procent) / 100.00)
        END
    ELSE
        BEGIN
            UPDATE siec_hoteli.dbo.pracownicy
            SET premia = 0
            WHERE premia IS NULL
              AND @id = id_pracownika

            UPDATE siec_hoteli.dbo.pracownicy
            SET premia = premia * ((100.00 + @procent) / 100.00)
            WHERE @id = id_pracownika
        END
END
GO

-- Sprawdzenie dzialania procedury. 
BEGIN
    DECLARE @id INT = 12, @procent INT = 50
    SELECT * FROM siec_hoteli..pracownicy WHERE id_pracownika = 12
    EXEC premia_procedura @id, @procent
    SELECT * FROM siec_hoteli..pracownicy WHERE id_pracownika = 12
END

BEGIN
    DECLARE @id2 INT = 46, @procent2 INT = 50
    SELECT * FROM siec_hoteli..pracownicy WHERE id_pracownika = 46
    EXEC premia_procedura @id2, @procent2
    SELECT * FROM siec_hoteli..pracownicy WHERE id_pracownika = 46
END

-- 20. Stworz wyzwalacz, ktory podczas wstawiania do tabeli archiwum pracownikow zmieni wartosc kolumny czy_aktywny na wartosc 0. 
-- USE siec_hoteli
-- GO
-- DROP TRIGGER IF EXISTS set_czy_aktywny
-- GO
-- Create Trigger set_czy_aktywny
--     on dbo.archiwum_pracownikow
--     for insert
--     as
--     update dbo.pracownicy
--     set dbo.pracownicy.czy_aktywny = 0
--     where dbo.pracownicy.id_pracownika = inserted.id_pracownika
-- go


-- Wyzwalacz nr. 1 - Po zmianie premii, jesli premia jest zwiêkszona o wiêcej ni¿ 10 punktów procentowych, zwiêksz pensjê pracownika o po³owê iloczyny premii i pensji
USE siec_hoteli
GO
DROP TRIGGER IF EXISTS zwieksz_pensje
GO
CREATE TRIGGER zwieksz_pensje
    ON siec_hoteli.dbo.pracownicy
    AFTER UPDATE
    AS
    IF (UPDATE(premia))
        BEGIN
            UPDATE dbo.pracownicy
            SET dbo.pracownicy.pensja += i.pensja * i.premia * 0.5
            FROM inserted i
            WHERE dbo.pracownicy.id_pracownika = i.id_pracownika
              AND (i.premia - dbo.pracownicy.premia) > 0.1
        END
GO
USE master
GO

-- Sprawdzenie dzialania wyzwalacza.
BEGIN
    DECLARE @id2 INT = 46, @procent2 INT = 50
    SELECT * FROM siec_hoteli..pracownicy WHERE id_pracownika = 46
    EXEC premia_procedura @id2, @procent2
    SELECT * FROM siec_hoteli..pracownicy WHERE id_pracownika = 46
END


-- Wyzwalacz nr. 2 - Przy usuniêciu rezerwacji jest ona wprowadzana do tabeli anulowane_rezerwacje. 

USE siec_hoteli
GO
DROP TRIGGER IF EXISTS przenies_do_anulowanych
GO
CREATE TRIGGER przenies_do_anulowanych
    ON siec_hoteli.dbo.rezerwacje
    FOR DELETE
    AS
    INSERT INTO siec_hoteli.dbo.anulowane_rezerwacje
    SELECT d.id_rezerwacji, d.data_rezerwacji, d.liczba_dni_rezerwacji, d.id_pokoju, d.id_klienta
    FROM deleted d
GO
USE master
GO

-- Sprawdzenie dzialania wyzwalacza.
BEGIN
    SELECT * FROM siec_hoteli..rezerwacje
    SELECT * FROM siec_hoteli..anulowane_rezerwacje

    DELETE siec_hoteli..rezerwacje
    WHERE id_rezerwacji = 1000

    SELECT * FROM siec_hoteli..rezerwacje
    SELECT * FROM siec_hoteli..anulowane_rezerwacje
END
GO

USE siec_hoteli
GO
DROP TRIGGER IF EXISTS ustaw_cene_archiwum
GO
CREATE TRIGGER ustaw_cene_archiwum
    ON siec_hoteli.dbo.archiwum_rezerwacji
    AFTER INSERT
    AS
    UPDATE siec_hoteli..archiwum_rezerwacji
    SET archiwum_rezerwacji.cena_za_telefon = (SELECT SUM(DATEDIFF(MINUTE, rt.data_rozpoczecia_rozmowy,
                                                                   rt.data_zakonczenia_rozmowy) *
                                                          h.cena_za_polaczenie_telefoniczne *
                                                          dbo.oblicz_wspoczynnik(rt.numer_telefonu, rt.id_pokoju))
                                               FROM inserted i,
                                                    siec_hoteli..rozmowy_telefoniczne rt,
                                                    siec_hoteli..rezerwacje rez,
                                                    siec_hoteli..hotele h,
                                                    siec_hoteli..pokoje p
                                               WHERE rez.id_pokoju = rt.id_pokoju
                                                 AND i.id_rezerwacji = rez.id_rezerwacji
                                                 AND h.id_hotelu = p.id_hotelu
                                                 AND p.id_pokoju = rez.id_pokoju
                                                 AND i.id_rezerwacji_arch =
                                                     siec_hoteli.dbo.archiwum_rezerwacji.id_rezerwacji_arch
    )
    WHERE siec_hoteli.dbo.archiwum_rezerwacji.id_rezerwacji = (SELECT i.id_rezerwacji FROM inserted i)
GO
USE master
GO
-- trigger - on delete - przy usunieciu klienta usuwane sa jego wszystkie rezerwacje, 
-- przy usunieciu pracownika jest dodawany do archiwum

-- trigger - instead of insert - przy wstawianiu rezerwacji do archiwum, wstawiana jest rezerwacja z cena za telefon wyliczona funkcji
