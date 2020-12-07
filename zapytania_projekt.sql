-- 1. Wy�wietl liczb� pokoi w ka�dym z hoteli. Na ko�cu dodaj podsumowanie ile jest ��cznie pokoi.
SELECT case when h.nazwa_hotelu is null then 'Suma' else h.nazwa_hotelu end as 'Nazwa Hotelu',
       COUNT(*)                                                             as 'Liczba pokoi'
FROM siec_hoteli.dbo.pokoje p,
     siec_hoteli.dbo.hotele h
WHERE p.id_hotelu = h.id_hotelu
GROUP BY ROLLUP (nazwa_hotelu)
ORDER BY CASE WHEN h.nazwa_hotelu IS NULL THEN 1 else 0 END,
         [Nazwa Hotelu]
GO

-- 2. Wy�wietl nazw� hotelu, cen� bazow� za pok�j, nazw� miasta przy tworzeniu rankingu hoteli na podstawie ceny bazowej za 
-- pok�j bez przeskoku.  
SELECT nazwa_hotelu,
       cena_bazowa_za_pokoj,
       nazwa_miasta,
       DENSE_RANK() OVER (ORDER BY cena_bazowa_za_pokoj DESC) AS 'Ranking cen pokoi'
FROM siec_hoteli.dbo.hotele h,
     siec_hoteli.dbo.miasta m
WHERE h.id_miasta = m.id_miasta
GO

-- 3. Wy�wietl �redni� cen� po��cze� telefonicznych hoteli dla miasta zaokr�glone do drugiej liczby po przecinku wraz z nazw� miasta, 
-- posortowane po �redniej.
SELECT DISTINCT nazwa_miasta,
                ROUND(AVG(cena_za_polaczenie_telefoniczne) OVER (PARTITION BY nazwa_miasta),
                      2) AS 'Srednia cena polaczen telefonicznych'
FROM siec_hoteli.dbo.hotele h,
     siec_hoteli.dbo.miasta m
WHERE h.id_miasta = m.id_miasta
ORDER BY [Srednia cena polaczen telefonicznych] DESC
GO

-- 4. Wy�wietl liczb� pokoi dla kt�rych nie przewidziano rezerwacji. 
SELECT nazwa_hotelu, COUNT(id_pokoju) as 'Liczba pokoi bez rezerwacji'
FROM siec_hoteli.dbo.pokoje,
     siec_hoteli.dbo.hotele
WHERE id_pokoju NOT IN (SELECT id_pokoju FROM siec_hoteli.dbo.rezerwacje)
  AND pokoje.id_hotelu = hotele.id_hotelu
GROUP BY nazwa_hotelu
ORDER BY [Liczba pokoi bez rezerwacji] DESC
GO


-- 5. Wy�wietl pi�� najbli�szych dat rezerwacji i rezerwacje przewidziane na te daty.
SELECT id_rezerwacji, data_rezerwacji, liczba_dni_rezerwacji
FROM siec_hoteli.dbo.rezerwacje
WHERE data_rezerwacji IN
      (SELECT DISTINCT TOP 5 data_rezerwacji FROM rezerwacje WHERE data_rezerwacji > GETDATE() ORDER BY data_rezerwacji)
ORDER BY data_rezerwacji
GO

-- 6. Wy�wietl imiona, nazwiska, adresy klient�w, kt�rzy mieszkaj� w Hiszpani.
SELECT imie_klienta, nazwisko_klienta, adres_zamieszkania
FROM siec_hoteli.dbo.klienci
WHERE adres_zamieszkania LIKE '%Hiszpania%'
GO

-- 7. Wy�wietl wszystkie rezerwacje przewidziane na miesi�c lipiec, kt�re jeszcze si� nie odby�y.
SELECT id_rezerwacji, liczba_dni_rezerwacji, data_rezerwacji
FROM siec_hoteli.dbo.rezerwacje
WHERE MONTH(data_rezerwacji) = 7
  AND data_rezerwacji > GETDATE()
ORDER BY id_rezerwacji
GO

-- 8. Wy�wietl id_sprzatania, id_pokoju, czas trwania sprzatania jako czas_trwania wszystkich pe�nych sprz�ta�.
SELECT id_sprzatania,
       id_pokoju,
       CAST(data_rozpoczecia_sprzatania AS DATE)                                    AS 'Data rozpoczecia sprzatania',
       CAST(data_rozpoczecia_sprzatania AS TIME(0))                                 AS 'Godzina rozpoczecia sprzatania',
       CAST((data_zakonczenia_sprzatania - data_rozpoczecia_sprzatania) AS TIME(0)) AS 'Czas trwania'
FROM siec_hoteli.dbo.sprzatanie
WHERE rodzaj_sprzatania = 'Pelne'
ORDER BY data_rozpoczecia_sprzatania
GO

-- 9. Wy�wietl wszystkie rozmowy telefoniczne, kt�re trwa�y d�u�ej ni� 5 minut.
SELECT *
FROM siec_hoteli.dbo.rozmowy_telefoniczne r
WHERE DATEDIFF(MINUTE, r.data_rozpoczecia_rozmowy, r.data_zakonczenia_rozmowy) > 5
ORDER BY data_rozpoczecia_rozmowy
GO

-- 10. Wy�wietl wszystkich klientow, ktorzy dzownili z telefonu pokojowego do innych klientow. 
select k1.imie_klienta + ' ' + k1.nazwisko_klienta 'Imie i nazwisko odbiorcy', k1.numer_telefonu_klienta 'Numer telefonu odbiorcy', 
k2.imie_klienta + ' ' + k2.nazwisko_klienta 'Imie i nazwisko dzowniacego', p.numer_telefonu_pokoju 'Numer telefonu pokoju'
from siec_hoteli.dbo.klienci k1,
     siec_hoteli.dbo.klienci k2,
     siec_hoteli.dbo.pokoje p,
     siec_hoteli.dbo.rozmowy_telefoniczne rt,
     siec_hoteli.dbo.rezerwacje rez
where rt.numer_telefonu = k1.numer_telefonu_klienta
  and rt.id_pokoju = p.id_pokoju
  and p.id_pokoju = rez.id_pokoju
  and rez.id_klienta = k2.id_klienta
  and rez.data_rezerwacji < rt.data_rozpoczecia_rozmowy
  and dateadd(day, rez.liczba_dni_rezerwacji, rez.data_rezerwacji) > rt.data_rozpoczecia_rozmowy


--------------------------------------------------------- FUNKCJA ---------------------------------------------------------------------------------------
-- 10. Wy�wietl id_rezerwacji, licza_dni_rezerwacji, data_rezerwacji oraz dat� wymeldowania jako data_wymeldowania.
--SELECT id_rezerwacji, liczba_dni_rezerwacji, data_rezerwacji, DATEADD(DAY, liczba_dni_rezerwacji, data_rezerwacji) AS data_wymeldowania
--FROM rezerwacje
--GO

------------------------------------------------- FUNKCJA ----------------------------------------------------------------
-- 16. Podwy�sz wszystkim hotelom cen� bazow� za pok�j o 5%.
--UPDATE hotele
--SET cena_bazowa_za_pokoj = 1.05 * cena_bazowa_za_pokoj
--SELECT id_hotelu, cena_bazowa_za_pokoj
--FROM hotele
--GO

----------------------------------------Napisac cos co wyswietli wszystkich klientow ktorzy dzownili --------------------------------------------------------
-- 17. Dodaj funkcj� zwracaj�c� wsp�czynnik z jakim trzeba b�dzie pomno�y� cen� za po��czenie telefoniczne. Funkcja ma przyjmowa� dwa argumenty:
-- numer_telefonu, id_pokoju. Je�li numer telefonu, na kt�ry zosta�o wykonane po��czenie nale�y do kt�rego� z pokoi w hotelu z kt�rego wykonano po��czenie 
-- (na podstawie id_pokoju uzyskujemy id_hotelu z kt�rego wykonano po��czenie) wtedy wsp�czynnik ustawiany jest na 0. Dla numeru telefonu pokoju znajduj�cego 
-- si� w innym hotelu wsp�czynnik ustawiany jest na 0.5, dla numer�w telefon�w spoza hotelu wsp�czynnik ustawiany jest na 1.

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

--19. 

CREATE PROCEDURE premia @id INT = -1, @procent INT = -1
AS
BEGIN
    IF @procent = -1 AND @id = -1
        BEGIN
            UPDATE siec_hoteli.dbo.pracownicy
            SET premia = 0
            WHERE premia IS NULL;
        END
    ELSE
        IF @procent = -1 AND @id != -1
            BEGIN
                UPDATE siec_hoteli.dbo.pracownicy
                SET premia = 0
                WHERE premia IS NULL
                  AND @id = id_pracownika
            END
        ELSE
            IF @procent != -1 AND @id != -1
                BEGIN
                    UPDATE siec_hoteli.dbo.pracownicy
                    SET premia = premia * ((100.00 + @procent) / 100.00)
                    WHERE @id = id_pracownika
                END
            ELSE
                BEGIN
                    DECLARE kursor_premia CURSOR FOR
                        SELECT id_pracownika FROM siec_hoteli.dbo.pracownicy
                    DECLARE @id_kr INT
                    BEGIN
                        OPEN kursor_premia
                        FETCH NEXT FROM kursor_premia INTO @id_kr
                        WHILE @@FETCH_STATUS = 0
                            BEGIN
                                UPDATE siec_hoteli.dbo.pracownicy
                                SET premia = premia * ((100.00 + @procent) / 100.00)
                                WHERE CURRENT OF kursor_premia
                                FETCH NEXT FROM kursor_premia INTO @id_kr
                            END
                        CLOSE kursor_premia
                        DEALLOCATE kursor_premia
                    END

                END

END
GO