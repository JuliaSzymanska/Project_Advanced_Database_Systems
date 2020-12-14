-- Julia Szymanska 224441
-- Przemek Zdrzalik 224466
-- Martyna Piasecka 224398

--USE siec_hoteli
--GO


-- Napisz funkcjê podaj¹c¹ dla ka¿dego kraju, ile procent wszystkich hoteli znajduje siê w tym kraju.
-- Wywo³aj j¹ wewn¹trz zapytania daj¹cego wynik w postaci dwóch kolumn: nazwa_kraju, nazwa_funkcji
drop FUNCTION if EXISTS [dbo].[okreslprocent]

CREATE FUNCTION [dbo].[okreslprocent](@id CHAR(2))
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

SELECT DISTINCT p.nazwa_panstwa, [dbo].[okreslprocent](p.id_panstwa) AS 'procent_oddzialow'
FROM siec_hoteli..panstwa p
ORDER BY [dbo].[okreslprocent](p.id_panstwa) DESC
GO






-- Stworz procedure, która pracownikowi o zadanym id zwiekszy premie o zadany procent. Oba argumenty posiadaja wartosci domysle, 
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


-- Wyzwalacz nr. 4
USE siec_hoteli
GO
DROP TRIGGER IF EXISTS czy_rezerwacja_moze_byc_dodana
GO
CREATE TRIGGER czy_rezerwacja_moze_byc_dodana
    ON siec_hoteli.dbo.rezerwacje
    INSTEAD OF INSERT
    AS
    DECLARE @data_poczatkowa DATETIME,  @data_koncowa DATETIME
	SELECT @data_poczatkowa = i.data_rezerwacji, @data_koncowa = DATEADD(DAY, i.liczba_dni_rezerwacji, i.data_rezerwacji) FROM inserted i



GO
USE master
GO

-- Sprawdzenie dzialania wyzwalacza.
BEGIN

END
GO