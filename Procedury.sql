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


--------------------------------------------------------------------------------
-- Procedura 6.  Tworzymy rezerwacje dla nowego u¿ytkownika


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
                               FROM klienci k
                               WHERE k.imie_klienta = @imie_klienta
                                 AND k.nazwisko_klienta = @nazwisko_klienta
                                 AND @nr_tel = k.numer_telefonu_klienta
                                 AND k.adres_zamieszkania = @adres
                               ORDER BY k.id_klienta DESC
    )

    INSERT INTO siec_hoteli..rezerwacje(data_rezerwacji, liczba_dni_rezerwacji, id_pokoju, id_klienta)
    VALUES (@data_rezerwacji, @liczba_dni, @id_pokoju, @id_klienta)

END

