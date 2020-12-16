-- Julia Szymanska 224441
-- Przemek Zdrzalik 224466
-- Martyna Piasecka 224398


-- Procedura 1. Procedura uaktualniaj¹ca cenê za telefon dla rezerwacji o adanym id, 
-- mno¿¹c cene za po³¹czenie telefoniczne dla hotelu, wspó³czynnik ceny oraz czas trwania rozmów, dla po³¹czeñ wykonanych dla tego pokoju podczas danej rezerwacji.
DROP PROCEDURE IF EXISTS [dbo].[ustaw_cene_za_telefon]
GO
CREATE PROCEDURE [dbo].[ustaw_cene_za_telefon] @id_rezerwacji INT
AS
BEGIN
    UPDATE siec_hoteli..archiwum_rezerwacji
    SET archiwum_rezerwacji.cena_za_telefon = (SELECT SUM(DATEDIFF(MINUTE, rt.data_rozpoczecia_rozmowy,
                                                                   rt.data_zakonczenia_rozmowy) *
                                                          h.cena_za_polaczenie_telefoniczne *
                                                          dbo.oblicz_wspoczynnik(rt.numer_telefonu, rt.id_pokoju))
                                               FROM siec_hoteli..rozmowy_telefoniczne rt,
                                                    siec_hoteli..rezerwacje rez,
                                                    siec_hoteli..hotele h,
                                                    siec_hoteli..pokoje p
                                               WHERE rez.id_pokoju = rt.id_pokoju
                                                 AND @id_rezerwacji = rez.id_rezerwacji
                                                 AND h.id_hotelu = p.id_hotelu
                                                 AND p.id_pokoju = rez.id_pokoju
                                                 AND rt.data_rozpoczecia_rozmowy > rez.data_rezerwacji
                                                 AND rt.data_rozpoczecia_rozmowy <
                                                     DATEADD(DAY, rez.liczba_dni_rezerwacji, rez.data_rezerwacji)
    )
    WHERE siec_hoteli.dbo.archiwum_rezerwacji.id_rezerwacji = @id_rezerwacji
END
GO

-- Sprawdzenie dzia³ania procedury jest sprawdzane przy sprawdzaniu wyzwalacza ustaw_cene_archiwum.

--------------------------------------------------------------------------------
-- Procedura 2. Procedura uaktualnia cenê za us³ugi dla zadanej rezerwacji mno¿¹c liczbê dni rezerwacji razu sumê cen za wybrane us³ugi. 
GO
DROP PROCEDURE IF EXISTS [dbo].[ustaw_cene_za_uslugi]
GO
CREATE PROCEDURE [dbo].[ustaw_cene_za_uslugi] @id_rezerwacji INT
AS
BEGIN
    UPDATE siec_hoteli..archiwum_rezerwacji
    SET cena_za_uslugi = (SELECT t2.iloczyn_sum
                          FROM (SELECT t.suma_cen * r.liczba_dni_rezerwacji iloczyn_sum
                                FROM (
                                         SELECT ur.id_rezerwacji, SUM(u.cena_uslugi) suma_cen
                                         FROM siec_hoteli..archiwum_rezerwacji ar,
                                              siec_hoteli..usluga_dla_rezerwacji ur,
                                              siec_hoteli..uslugi u
                                         WHERE ar.id_rezerwacji = ur.id_rezerwacji
                                           AND ur.id_uslugi = u.id_uslugi
                                           AND ar.id_rezerwacji = @id_rezerwacji
                                         GROUP BY ur.id_rezerwacji
                                     ) t,
                                     siec_hoteli..rezerwacje r
                                WHERE r.id_rezerwacji = t.id_rezerwacji) AS t2)
    WHERE archiwum_rezerwacji.id_rezerwacji = @id_rezerwacji
END
GO

-- Sprawdzenie dzia³ania procedury jest sprawdzane przy sprawdzaniu wyzwalacza ustaw_cene_archiwum.

--------------------------------------------------------------------------------
-- Procedura 3. Procedura uaktualnia cenê za wynajêcie pokoju dla zadanej rezerwacji 
-- mno¿¹c cenê bazow¹ za pokój, liczbê pomieszczeñ, liczbê przewidzianych osób, liczbê dni rezerwacji oraz zni¿kê.
GO
DROP PROCEDURE IF EXISTS [dbo].[ustaw_cene_za_wynajecie_pokoju]
GO
CREATE PROCEDURE [dbo].[ustaw_cene_za_wynajecie_pokoju] @id_rezerwacji INT
AS
BEGIN
    UPDATE siec_hoteli..archiwum_rezerwacji
    SET cena_wynajecia_pokoju = (SELECT h.cena_bazowa_za_pokoj * p.liczba_pomieszczen * p.liczba_przewidzianych_osob *
                                        r.liczba_dni_rezerwacji * ([dbo].[oblicz_znizke](r.id_klienta)) cena_rezerwacji
                                 FROM siec_hoteli..rezerwacje r,
                                      siec_hoteli..hotele h,
                                      siec_hoteli..pokoje p
                                 WHERE r.id_pokoju = p.id_pokoju
                                   AND p.id_hotelu = h.id_hotelu
                                   AND r.id_rezerwacji = @id_rezerwacji)
    WHERE archiwum_rezerwacji.id_rezerwacji = @id_rezerwacji
END
GO

-- Sprawdzenie dzia³ania procedury jest sprawdzane przy sprawdzaniu wyzwalacza ustaw_cene_archiwum.

--------------------------------------------------------------------------------
-- Procedura 4. Procedura uaktualnia cenê ca³kowit¹ dla zadanej rezerwacji sumuj¹c cenê za us³ugi, cenê za telefon oraz cenê za wynajêcie pokoju. 
GO
DROP PROCEDURE IF EXISTS [dbo].[ustaw_cene_calkowita]
GO
CREATE PROCEDURE [dbo].[ustaw_cene_calkowita] @id_rezerwacji INT
AS
BEGIN
    UPDATE siec_hoteli..archiwum_rezerwacji
    SET cena_calkowita = ISNULL(cena_za_uslugi, 0) + ISNULL(cena_za_telefon, 0) + ISNULL(cena_wynajecia_pokoju, 0)
    WHERE archiwum_rezerwacji.id_rezerwacji = @id_rezerwacji
END
GO

-- Sprawdzenie dzia³ania procedury jest sprawdzane przy sprawdzaniu wyzwalacza ustaw_cene_archiwum.

--------------------------------------------------------------------------------
-- Procedura 5. Procedura, która pracownikowi o zadanym id zwiekszy premie o zadany procent. Oba argumenty posiadaja wartosci domysle,
-- dla procentu jest to 10%, natomiast jestli nie zostalo podane id pracownika, wszystkim pracownikom podwyzsz premie. Maksymalna premia to 9.99.
GO
DROP PROCEDURE IF EXISTS premia_procedura
GO
CREATE PROCEDURE premia_procedura @id INT = -1, @procent INT = 10
AS
BEGIN
    IF @id = -1
        BEGIN
            UPDATE siec_hoteli.dbo.pracownicy
            SET premia = 0
            WHERE premia IS NULL;


            UPDATE siec_hoteli.dbo.pracownicy
            SET premia = CASE
                             WHEN premia * ((100.00 + @procent) / 100.00) < 10
                                 THEN premia * ((100.00 + @procent) / 100.00)
                             ELSE premia
                END

        END
    ELSE
        BEGIN
            UPDATE siec_hoteli.dbo.pracownicy
            SET premia = 0
            WHERE premia IS NULL
              AND @id = id_pracownika

            UPDATE siec_hoteli.dbo.pracownicy
            SET premia = CASE
                             WHEN premia * ((100.00 + @procent) / 100.00) < 10
                                 THEN premia * ((100.00 + @procent) / 100.00)
                             ELSE premia
                END
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

BEGIN
    DECLARE @procent3 INT = 50
    SELECT * FROM siec_hoteli..pracownicy
    EXEC premia_procedura @procent = @procent3
    SELECT * FROM siec_hoteli..pracownicy
END

BEGIN
    DECLARE @id3 INT = 46
    SELECT * FROM siec_hoteli..pracownicy WHERE id_pracownika = @id3
    EXEC premia_procedura @id = @id3
    SELECT * FROM siec_hoteli..pracownicy WHERE id_pracownika = @id3
END

BEGIN
    SELECT * FROM siec_hoteli..pracownicy
    EXEC premia_procedura
    SELECT * FROM siec_hoteli..pracownicy
END


--------------------------------------------------------------------------------
-- Procedura 6. Procedura na podstawie pobranych paramterów tworzy nowego klienta oraz now¹ rezerwacjê. 

GO
DROP PROCEDURE IF EXISTS [dbo].[rezerwacja_dla_nowego]
GO
CREATE PROCEDURE [dbo].[rezerwacja_dla_nowego] @data_rezerwacji DATE, @liczba_dni INT, @id_pokoju INT,
                                               @imie_klienta VARCHAR(20), @nazwisko_klienta VARCHAR(40),
                                               @nr_tel CHAR(9), @adres VARCHAR(100)
AS
BEGIN
    INSERT INTO siec_hoteli..klienci(imie_klienta, nazwisko_klienta, numer_telefonu_klienta, adres_zamieszkania)
    VALUES (@imie_klienta, @nazwisko_klienta, @nr_tel, @adres)

    DECLARE @id_klienta INT = (SELECT TOP 1 k.id_klienta
                               FROM siec_hoteli..klienci k
                               WHERE k.imie_klienta = @imie_klienta
                                 AND k.nazwisko_klienta = @nazwisko_klienta
                                 AND @nr_tel = k.numer_telefonu_klienta
                                 AND k.adres_zamieszkania = @adres
                               ORDER BY k.id_klienta DESC
    )

    INSERT INTO siec_hoteli..rezerwacje(data_rezerwacji, liczba_dni_rezerwacji, id_pokoju, id_klienta)
    VALUES (@data_rezerwacji, @liczba_dni, @id_pokoju, @id_klienta)

END
GO

-- Sprawdzenie dzia³ania procedury
BEGIN
    DECLARE @data_rezerwacji DATE = '2022/12/01', @liczba_dni INT = 5, @id_pokoju INT = 153,
        @imie_klienta VARCHAR(20) = 'Kamil', @nazwisko_klienta VARCHAR(40) = 'Stachura',
        @nr_tel CHAR(9) = '144768432', @adres VARCHAR(100) = 'Politechniki 43 92-431 Lodz Polska'

    SELECT k.id_klienta, imie_klienta, nazwisko_klienta, numer_telefonu_klienta, adres_zamieszkania
    FROM siec_hoteli..klienci k
    WHERE k.imie_klienta = @imie_klienta
      AND k.nazwisko_klienta = @nazwisko_klienta
      AND k.numer_telefonu_klienta = @nr_tel
      AND k.adres_zamieszkania = @adres

    SELECT re.id_rezerwacji,
           re.data_rezerwacji,
           re.liczba_dni_rezerwacji,
           re.id_pokoju,
           re.id_klienta,
           kl.imie_klienta,
           kl.nazwisko_klienta
    FROM siec_hoteli..rezerwacje re,
         siec_hoteli..klienci kl
    WHERE re.id_klienta = kl.id_klienta
      AND imie_klienta = @imie_klienta
      AND nazwisko_klienta = @nazwisko_klienta
      AND numer_telefonu_klienta = @nr_tel
      AND adres_zamieszkania = @adres

    EXEC rezerwacja_dla_nowego @data_rezerwacji, @liczba_dni, @id_pokoju, @imie_klienta, @nazwisko_klienta, @nr_tel,
         @adres

    SELECT k.id_klienta, imie_klienta, nazwisko_klienta, numer_telefonu_klienta, adres_zamieszkania
    FROM siec_hoteli..klienci k
    WHERE k.imie_klienta = @imie_klienta
      AND k.nazwisko_klienta = @nazwisko_klienta
      AND k.numer_telefonu_klienta = @nr_tel
      AND k.adres_zamieszkania = @adres
    
    SELECT re.id_rezerwacji,
           re.data_rezerwacji,
           re.liczba_dni_rezerwacji,
           re.id_pokoju,
           re.id_klienta,
           kl.imie_klienta,
           kl.nazwisko_klienta
    FROM siec_hoteli..rezerwacje re,
         siec_hoteli..klienci kl
    WHERE re.id_klienta = kl.id_klienta
      AND imie_klienta = @imie_klienta
      AND nazwisko_klienta = @nazwisko_klienta
      AND numer_telefonu_klienta = @nr_tel
      AND adres_zamieszkania = @adres
END

--------------------------------------------------------------------------------
-- Procedura 7. Procedura dla zadanego pokoju wyœwietla informacjê czy pokój by³ sprz¹tany po ostatniej rezerwacji. 


GO
DROP PROCEDURE IF EXISTS [dbo].[sprawdz_sprzatanie]
GO
CREATE PROCEDURE [dbo].[sprawdz_sprzatanie] @id_pokoju INT
AS
BEGIN
    IF NOT EXISTS(SELECT s.id_pokoju
                  FROM siec_hoteli..sprzatanie s,
                       siec_hoteli..pokoje p,
                       siec_hoteli..rezerwacje r
                  WHERE s.id_pokoju = @id_pokoju
                    AND r.id_pokoju = @id_pokoju
                    AND p.id_pokoju = @id_pokoju
                    AND r.id_rezerwacji = (SELECT TOP 1 r1.id_rezerwacji
                                           FROM siec_hoteli..rezerwacje r1
                                           WHERE r1.id_pokoju = @id_pokoju
                                             AND r1.data_rezerwacji < GETDATE()
                                           ORDER BY r1.data_rezerwacji DESC)
                    AND DATEADD(DAY, r.liczba_dni_rezerwacji, r.data_rezerwacji) < s.data_rozpoczecia_sprzatania
                    AND s.id_sprzatania = (SELECT TOP 1 s1.id_sprzatania
                                           FROM siec_hoteli..sprzatanie s1
                                           WHERE s1.id_pokoju = @id_pokoju
                                           ORDER BY s1.data_rozpoczecia_sprzatania DESC))
        PRINT ('Pokoj nie byl sprzatany')
    ELSE
        PRINT ('Pokoj byl sprzatany')
END
GO


-- Sprawdzenie dzia³ania procedury
BEGIN
    DECLARE @id_pokoju INT = 151

    EXEC sprawdz_sprzatanie @id_pokoju

    SELECT * FROM siec_hoteli..sprzatanie WHERE id_pokoju = 151

    INSERT INTO siec_hoteli.dbo.sprzatanie(data_rozpoczecia_sprzatania, data_zakonczenia_sprzatania, rodzaj_sprzatania,
                                           id_pokoju)
    VALUES ('2020/12/15 12:00:00', '2020/12/15 14:30:00', 'Pelne', @id_pokoju);

    EXEC sprawdz_sprzatanie @id_pokoju
END
GO

-- Procedura 8. Procedura dla zadanego pañstwa zmienia cenê bazow¹ za pokój znajduj¹cych siê w nim hoteli.
-- Jeœli cena bazowa za pokój jest wiêksza od 120% œredniej w sieci hoteli to cena zostaje zmniejszona o 8%,
-- jesli cena bazowa za pokój jest mniejsza od 80% œredniej w sieci hoteli to cena zostaje zwiêkszona o 11%.

GO
DROP PROCEDURE IF EXISTS [dbo].[sprawdz_ceny]
GO
CREATE PROCEDURE [dbo].[sprawdz_ceny] @id_panstwa VARCHAR(2)
AS
BEGIN
    IF (SELECT AVG(h.cena_bazowa_za_pokoj)
        FROM siec_hoteli..miasta m,
             siec_hoteli..hotele h
        WHERE h.id_miasta = m.id_miasta
          AND m.id_panstwa = @id_panstwa) > (SELECT AVG(h2.cena_bazowa_za_pokoj) * 1.20 FROM siec_hoteli..hotele h2)
        BEGIN
            UPDATE siec_hoteli..hotele
            SET cena_bazowa_za_pokoj = cena_bazowa_za_pokoj * 0.92
            WHERE id_miasta IN (SELECT m.id_miasta FROM siec_hoteli..miasta m WHERE m.id_panstwa = @id_panstwa)
        END
    ELSE
        IF (SELECT AVG(h.cena_bazowa_za_pokoj)
            FROM siec_hoteli..miasta m,
                 siec_hoteli..hotele h
            WHERE h.id_miasta = m.id_miasta
              AND m.id_panstwa = @id_panstwa) < (SELECT AVG(h2.cena_bazowa_za_pokoj) * 0.8 FROM siec_hoteli..hotele h2)
            BEGIN
                UPDATE siec_hoteli..hotele
                SET cena_bazowa_za_pokoj = cena_bazowa_za_pokoj * 1.11
                WHERE id_miasta IN (SELECT m.id_miasta FROM siec_hoteli..miasta m WHERE m.id_panstwa = @id_panstwa)
            END
END
GO


-- Sprawdzenie dzialania
BEGIN
    DECLARE @id_panstwa VARCHAR(2) = 'PL'

    SELECT AVG(h.cena_bazowa_za_pokoj), m.id_panstwa
    FROM siec_hoteli..miasta m,
         siec_hoteli..hotele h
    WHERE m.id_panstwa = @id_panstwa
      AND h.id_miasta = m.id_miasta
    GROUP BY m.id_panstwa

    EXECUTE [dbo].sprawdz_ceny 'PL'

    SELECT AVG(h.cena_bazowa_za_pokoj), m.id_panstwa
    FROM siec_hoteli..miasta m,
         siec_hoteli..hotele h
    WHERE m.id_panstwa = @id_panstwa
      AND h.id_miasta = m.id_miasta
    GROUP BY m.id_panstwa
END