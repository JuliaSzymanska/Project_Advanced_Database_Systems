-- Julia Szymanska 224441
-- Przemek Zdrzalik 224466
-- Martyna Piasecka 224398

--USE siec_hoteli
--GO


-- Napisz funkcj� podaj�c� dla ka�dego kraju, ile procent wszystkich hoteli znajduje si� w tym kraju.
-- Wywo�aj j� wewn�trz zapytania daj�cego wynik w postaci dw�ch kolumn: nazwa_kraju, nazwa_funkcji
IF EXISTS(SELECT 1
          FROM sys.objects
          WHERE type = 'FN'
            AND name = 'okreslProcent')
    DROP FUNCTION okreslProcent
GO
CREATE FUNCTION okreslProcent (@id CHAR(2))
	RETURNS FLOAT
AS
BEGIN
	DECLARE @procent FLOAT
	DECLARE @ileOgolem FLOAT, @ileWKraju FLOAT

	SET @ileWKraju =	(SELECT COUNT(*) 
						FROM	siec_hoteli..hotele h, 
								siec_hoteli..miasta m,
								siec_hoteli..panstwa p
						WHERE m.id_miasta = h.id_miasta
							AND p.id_panstwa = m.id_panstwa
							AND p.id_panstwa = @id)

	SET @ileOgolem =	(SELECT COUNT(*) 
						FROM siec_hoteli..hotele)

	SET @procent = (@ileWKraju/@ileOgolem) * 100

	RETURN @procent
END
GO

SELECT DISTINCT p.nazwa_panstwa, dbo.okreslProcent(p.id_panstwa) AS 'procent_oddzialow'
FROM siec_hoteli..panstwa p
ORDER BY dbo.okreslProcent(p.id_panstwa) DESC
GO



-- Dodaj funkcj� zwracaj�c� wsp�czynnik z jakim trzeba b�dzie pomno�y� cen� za po��czenie telefoniczne. Funkcja ma przyjmowa� dwa argumenty:
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

-- Stworz procedure, kt�ra pracownikowi o zadanym id zwiekszy premie o zadany procent. Oba argumenty posiadaja wartosci domysle, 
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


-- Wyzwalacz nr. 1 - Po zmianie premii, jesli premia jest zwi�kszona o wi�cej ni� 10 punkt�w procentowych, zwi�ksz pensj� pracownika o po�ow� iloczyny premii i pensji
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


-- Wyzwalacz nr. 2 - Przy usuni�ciu rezerwacji jest ona wprowadzana do tabeli anulowane_rezerwacje. 
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


--------------------------------------------------------------------------------

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

--SELECT *
--FROM siec_hoteli..archiwum_rezerwacji
--WHERE id_rezerwacji = 1009
--EXEC dbo.ustaw_cene_za_uslugi 1009
--SELECT *
--FROM siec_hoteli..archiwum_rezerwacji
--WHERE id_rezerwacji = 1009


--------------------------------------------------------------------------------
GO
DROP PROCEDURE IF EXISTS [dbo].[ustaw_cene_za_wynajecie_pokoju]
GO
CREATE PROCEDURE [dbo].[ustaw_cene_za_wynajecie_pokoju] @id_rezerwacji INT
AS
BEGIN
    UPDATE siec_hoteli..archiwum_rezerwacji
    SET cena_wynajecia_pokoju = (SELECT h.cena_bazowa_za_pokoj * p.liczba_pomieszczen * p.liczba_przewidzianych_osob *
                                        r.liczba_dni_rezerwacji cena_rezerwacji
                                 FROM siec_hoteli..rezerwacje r,
                                      siec_hoteli..hotele h,
                                      siec_hoteli..pokoje p
                                 WHERE r.id_pokoju = p.id_pokoju
                                   AND p.id_hotelu = h.id_hotelu
                                   AND r.id_rezerwacji = @id_rezerwacji)
    WHERE archiwum_rezerwacji.id_rezerwacji = @id_rezerwacji
END
GO

--SELECT h.cena_bazowa_za_pokoj * p.liczba_pomieszczen * p.liczba_przewidzianych_osob *
--       r.liczba_dni_rezerwacji cena_rezerwacji
--FROM siec_hoteli..rezerwacje r,
--     siec_hoteli..hotele h,
--     siec_hoteli..pokoje p
--WHERE r.id_pokoju = p.id_pokoju
--  AND p.id_hotelu = h.id_hotelu
--GO
--USE master
--GO


--------------------------------------------------------------------------------
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



-- Wyzwalacz nr. 3 - Po wprowdzeniu rezerwacji do archiwum_rezerwacji ustaw cene_za_telefon obliczajac cene kazdej rozmowy, 
-- mnozac liczbe minut rozmowy razy cene_za_polaczenie_telefoniczne razy wspolczynnik obliczony za pomoca funkcji.
USE siec_hoteli
GO
DROP TRIGGER IF EXISTS ustaw_cene_archiwum
GO

CREATE TRIGGER ustaw_cene_archiwum
    ON siec_hoteli.dbo.archiwum_rezerwacji
    AFTER INSERT
    AS
    DECLARE
        @id_rez INT
DECLARE kursor CURSOR FOR
    SELECT id_rezerwacji
    FROM inserted

BEGIN
    OPEN kursor
    FETCH NEXT FROM kursor INTO @id_rez
    WHILE @@FETCH_STATUS = 0
        BEGIN
            EXEC [master].[dbo].[ustaw_cene_za_telefon] @id_rez
            EXEC [master].[dbo].[ustaw_cene_za_uslugi] @id_rez
            EXEC [master].[dbo].[ustaw_cene_za_wynajecie_pokoju] @id_rez
            EXEC [master].[dbo].[ustaw_cene_calkowita] @id_rez
            FETCH NEXT FROM kursor INTO @id_rez
        END
    CLOSE kursor
    DEALLOCATE kursor
END
GO
USE master
GO


SELECT * FROM siec_hoteli..archiwum_rezerwacji
GO

INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1049);

INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1050);

INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1023);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1001);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1005);

INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1009);

INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1010);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1019);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1032);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1033);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1034);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1035);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1036);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1037);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1038);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1039);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1040);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1041);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1042);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1043);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1044);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1045);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1046);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1047);
INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
                                                id_rezerwacji)
VALUES (0, 0, 0, 1048);
GO


SELECT * FROM siec_hoteli..archiwum_rezerwacji WHERE id_rezerwacji = 1033

SELECT r.data_rezerwacji, r.liczba_dni_rezerwacji, r.id_pokoju, r.id_klienta, u.nazwa_uslugi, u.cena_uslugi
FROM siec_hoteli..rezerwacje r, siec_hoteli..usluga_dla_rezerwacji ur, siec_hoteli..uslugi u 
WHERE r.id_rezerwacji = 1009
AND ur.id_rezerwacji = r.id_rezerwacji
AND u.id_uslugi = ur.id_uslugi

SELECT * FROM siec_hoteli..usluga_dla_rezerwacji WHERE id_rezerwacji = 1009

SELECT * FROM siec_hoteli..rezerwacje WHERE id_rezerwacji = 1009

SELECT ar.id_rezerwacji, u.nazwa_uslugi
FROM siec_hoteli..rezerwacje ar, siec_hoteli..usluga_dla_rezerwacji ur, siec_hoteli..uslugi u
WHERE ar.id_rezerwacji = ur.id_rezerwacji
AND ur.id_uslugi = u.id_uslugi
ORDER BY ar.id_rezerwacji

SELECT r.id_rezerwacji, rt.data_rozpoczecia_rozmowy, rt.data_zakonczenia_rozmowy, r.data_rezerwacji, ar.cena_za_telefon , p.id_pokoju
FROM siec_hoteli..archiwum_rezerwacji ar, siec_hoteli..rezerwacje r, siec_hoteli..rozmowy_telefoniczne rt, siec_hoteli..pokoje p
WHERE ar.id_rezerwacji = r.id_rezerwacji
AND ar.id_rezerwacji = 1033
AND r.id_pokoju = p.id_pokoju
AND p.id_pokoju = rt.id_pokoju

SELECT * FROM siec_hoteli..rozmowy_telefoniczne where id_pokoju = 110