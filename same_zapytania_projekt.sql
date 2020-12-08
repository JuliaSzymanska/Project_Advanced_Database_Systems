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


-- 18 Wypisz klientów, którzy mieli rezerwacje, posortowani po sumie wartoœci ich rezerwacji
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
