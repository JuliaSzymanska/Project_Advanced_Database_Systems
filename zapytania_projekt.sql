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
    DROP FUNCTION okreslprocent
GO
CREATE FUNCTION okreslprocent(@id CHAR(2))
    RETURNS FLOAT
AS
BEGIN
    DECLARE @procent FLOAT
    DECLARE @ileogolem FLOAT, @ilewkraju FLOAT

    SET @ilewkraju = (SELECT COUNT(*)
                      FROM siec_hoteli..hotele h,
                           siec_hoteli..miasta m,
                           siec_hoteli..panstwa p
                      WHERE m.id_miasta = h.id_miasta
                        AND p.id_panstwa = m.id_panstwa
                        AND p.id_panstwa = @id)

    SET @ileogolem = (SELECT COUNT(*)
                      FROM siec_hoteli..hotele)

    SET @procent = (@ilewkraju / @ileogolem) * 100

    RETURN @procent
END
GO

SELECT DISTINCT p.nazwa_panstwa, dbo.okreslprocent(p.id_panstwa) AS 'procent_oddzialow'
FROM siec_hoteli..panstwa p
ORDER BY dbo.okreslprocent(p.id_panstwa) DESC
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


SELECT *
FROM siec_hoteli..archiwum_rezerwacji
WHERE id_rezerwacji = 1033

SELECT r.data_rezerwacji, r.liczba_dni_rezerwacji, r.id_pokoju, r.id_klienta, u.nazwa_uslugi, u.cena_uslugi
FROM siec_hoteli..rezerwacje r,
     siec_hoteli..usluga_dla_rezerwacji ur,
     siec_hoteli..uslugi u
WHERE r.id_rezerwacji = 1009
  AND ur.id_rezerwacji = r.id_rezerwacji
  AND u.id_uslugi = ur.id_uslugi

SELECT *
FROM siec_hoteli..usluga_dla_rezerwacji
WHERE id_rezerwacji = 1009

SELECT *
FROM siec_hoteli..rezerwacje
WHERE id_rezerwacji = 1009

SELECT ar.id_rezerwacji, u.nazwa_uslugi
FROM siec_hoteli..rezerwacje ar,
     siec_hoteli..usluga_dla_rezerwacji ur,
     siec_hoteli..uslugi u
WHERE ar.id_rezerwacji = ur.id_rezerwacji
  AND ur.id_uslugi = u.id_uslugi
ORDER BY ar.id_rezerwacji

SELECT r.id_rezerwacji,
       rt.data_rozpoczecia_rozmowy,
       rt.data_zakonczenia_rozmowy,
       r.data_rezerwacji,
       ar.cena_za_telefon,
       p.id_pokoju
FROM siec_hoteli..archiwum_rezerwacji ar,
     siec_hoteli..rezerwacje r,
     siec_hoteli..rozmowy_telefoniczne rt,
     siec_hoteli..pokoje p
WHERE ar.id_rezerwacji = r.id_rezerwacji
  AND ar.id_rezerwacji = 1033
  AND r.id_pokoju = p.id_pokoju
  AND p.id_pokoju = rt.id_pokoju

SELECT *
FROM siec_hoteli..rozmowy_telefoniczne
WHERE id_pokoju = 110