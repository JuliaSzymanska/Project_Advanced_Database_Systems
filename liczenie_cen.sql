-- Funkcja 1. Funkcja zwracaj�c� wsp�czynnik z jakim trzeba b�dzie pomno�y� cen� za po��czenie telefoniczne. Funkcja ma przyjmowa� dwa argumenty:
-- numer_telefonu, id_pokoju. Je�li numer telefonu, na kt�ry zosta�o wykonane po��czenie nale�y do kt�rego� z pokoi w hotelu z kt�rego wykonano po��czenie
-- (na podstawie id_pokoju uzyskujemy id_hotelu z kt�rego wykonano po��czenie) wtedy wsp�czynnik ustawiany jest na 0. Dla numeru telefonu pokoju znajduj�cego
-- si� w innym hotelu wsp�czynnik ustawiany jest na 0.5, dla numer�w telefon�w spoza hotelu wsp�czynnik ustawiany jest na 1.
GO

CREATE OR
ALTER FUNCTION [dbo].[oblicz_wspoczynnik](@numer_telefonu VARCHAR(9),
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


--------------------------------------------------------------------------------
GO
-- Funkcja 2. Funkcja obliczaj�ca zni�k� dla klient�w, kt�rzy posiadaj� rezerwacj� w archiwum rezerwacji, warto�c zni�ki wynosi 25%, 
-- natomiast dla klient�w, kt�rych najstarsza rezerwacja ma wi�cej ni� 10 lat zni�ka wynosi 50%. 
-- Dla klient�w, kt�ry nie maj� rezerwacji w archiwum rezerwacji zni�ka wynosi 0%.
CREATE OR
ALTER FUNCTION [dbo].[oblicz_znizke](@id_klienta INT)
    RETURNS DECIMAL(3, 2)
AS
BEGIN
    DECLARE @wspolczynnik_zniki DECIMAL(3, 2) = 1.00, @najstarsza_data_rezerwacji DATETIME;

    IF NOT EXISTS(SELECT MIN(r.data_rezerwacji)
                  FROM siec_hoteli..archiwum_rezerwacji ar,
                       siec_hoteli..rezerwacje r
                  WHERE ar.id_rezerwacji = r.id_rezerwacji
                    AND r.id_klienta = @id_klienta)
        BEGIN
            RETURN @wspolczynnik_zniki
        END

    SET @najstarsza_data_rezerwacji = (SELECT MIN(r.data_rezerwacji)
                                       FROM siec_hoteli..archiwum_rezerwacji ar,
                                            siec_hoteli..rezerwacje r
                                       WHERE ar.id_rezerwacji = r.id_rezerwacji
                                         AND r.id_klienta = @id_klienta)

    IF (DATEDIFF(YEAR, @najstarsza_data_rezerwacji, GETDATE()) > 10)
        BEGIN
            SET @wspolczynnik_zniki = 0.5
            RETURN @wspolczynnik_zniki
        END

    SET @wspolczynnik_zniki = 0.75
    RETURN @wspolczynnik_zniki

END;
GO

--------------------------------------------------------------------------------
-- Procedura 1. Procedura uaktualniaj�ca cen� za telefon dla rezerwacji o adanym id, 
-- mno��c cene za po��czenie telefoniczne dla hotelu, wsp�czynnik ceny oraz czas trwania rozm�w, dla po��cze� wykonanych dla tego pokoju podczas danej rezerwacji.
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

--------------------------------------------------------------------------------
-- Procedura 2. Procedura uaktualnia cen� za us�ugi dla zadanej rezerwacji mno��c liczb� dni rezerwacji razu sum� cen za wybrane us�ugi. 
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
--------------------------------------------------------------------------------
-- Procedura 3. Procedura uaktualnia cen� za wynaj�cie pokoju dla zadanej rezerwacji 
-- mno��c cen� bazow� za pok�j, liczb� pomieszcze�, liczb� przewidzianych os�b, liczb� dni rezerwacji oraz zni�k�.
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
--------------------------------------------------------------------------------
-- Procedura 4. Procedura uaktualnia cen� ca�kowit� dla zadanej rezerwacji sumuj�c cen� za us�ugi, cen� za telefon oraz cen� za wynaj�cie pokoju. 
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