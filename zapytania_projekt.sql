-- Julia Szymanska 224441
-- Przemek Zdrzalik 224466
-- Martyna Piasecka 224398

--USE siec_hoteli
--GO


-- Napisz funkcjê podaj¹c¹ dla ka¿dego kraju, ile procent wszystkich hoteli znajduje siê w tym kraju.
-- Wywo³aj j¹ wewn¹trz zapytania daj¹cego wynik w postaci dwóch kolumn: nazwa_kraju, nazwa_funkcji
DROP FUNCTION IF EXISTS [dbo].[okreslprocent]
GO
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


