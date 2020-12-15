-- Funkcja 1. Funkcja zwracaj¹c¹ wspó³czynnik z jakim trzeba bêdzie pomno¿yæ cenê za po³¹czenie telefoniczne. Funkcja ma przyjmowaæ dwa argumenty:
-- numer_telefonu, id_pokoju. Jeœli numer telefonu, na który zosta³o wykonane po³¹czenie nale¿y do któregoœ z pokoi w hotelu z którego wykonano po³¹czenie
-- (na podstawie id_pokoju uzyskujemy id_hotelu z którego wykonano po³¹czenie) wtedy wspó³czynnik ustawiany jest na 0. Dla numeru telefonu pokoju znajduj¹cego
-- siê w innym hotelu wspó³czynnik ustawiany jest na 0.5, dla numerów telefonów spoza sieci hoteli wspó³czynnik ustawiany jest na 1.
DROP FUNCTION IF EXISTS [dbo].[oblicz_wspoczynnik]
GO
CREATE FUNCTION [dbo].[oblicz_wspoczynnik](@numer_telefonu VARCHAR(9),
                                          @id_pokoju INT)
    RETURNS DECIMAL(3, 2)
AS
BEGIN
    DECLARE @wspolczynnik DECIMAL(3, 2) = 1.00;

    IF EXISTS(SELECT *
              FROM siec_hoteli.dbo.pokoje p
              WHERE p.numer_telefonu_pokoju = @numer_telefonu
                AND p.id_hotelu = (SELECT id_hotelu
                                   FROM siec_hoteli.dbo.pokoje p
                                   WHERE p.id_pokoju = @id_pokoju))
        BEGIN
            SET @wspolczynnik = 0.00
			RETURN @wspolczynnik;
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
				RETURN @wspolczynnik;
            END
        ELSE
            BEGIN
                SET @wspolczynnik = 1.00
				RETURN @wspolczynnik;
            END
    RETURN @wspolczynnik;
END;
GO

-- Sprawdzenie dzia³ania funkcji
-- Dla przypadku gdzie, niektóre pokoje s¹ w tym samym hotelu co numer, na ktory jest wykonywane po³¹czenie, natomiast pozosta³e znajduj¹ siê w innym hotelu.
DECLARE @numer_telefonu VARCHAR(9) = '69421' 
SELECT [dbo].[oblicz_wspoczynnik](@numer_telefonu, id_pokoju) FROM siec_hoteli..rozmowy_telefoniczne

-- Dla przypadku, gdy numer, na który wykonywane jest po³¹czenie jest spoza sieci hoteli. 
SET @numer_telefonu = '205947321'
SELECT [dbo].[oblicz_wspoczynnik](@numer_telefonu, id_pokoju) FROM siec_hoteli..rozmowy_telefoniczne


--------------------------------------------------------------------------------
GO
-- Funkcja 2. Funkcja obliczaj¹ca zni¿kê dla klientów, którzy posiadaj¹ rezerwacjê w archiwum rezerwacji, wartoœc zni¿ki wynosi 25%, 
-- natomiast dla klientów, których najstarsza rezerwacja ma wiêcej ni¿ 10 lat zni¿ka wynosi 50%. 
-- Dla klientów, który nie maj¹ rezerwacji w archiwum rezerwacji zni¿ka wynosi 0%.
DROP FUNCTION IF EXISTS [dbo].[oblicz_znizke]
GO
CREATE FUNCTION [dbo].[oblicz_znizke](@id_klienta INT)
    RETURNS DECIMAL(3, 2)
AS
BEGIN
    DECLARE @wspolczynnik_zniki DECIMAL(3, 2) = 1.00, @najstarsza_data_rezerwacji DATETIME;

    IF NOT EXISTS (SELECT r.data_rezerwacji
                  FROM siec_hoteli..archiwum_rezerwacji ar,
                       siec_hoteli..rezerwacje r
                  WHERE ar.id_rezerwacji = r.id_rezerwacji
                    AND r.id_klienta = @id_klienta 
					ORDER BY r.data_rezerwacji)
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

-- Sprawdzenie dzia³ania funkcji
-- Gdy klienci nie mieli jak dot¹d ¿adnej rezerwacji
SELECT k.id_klienta, [dbo].[oblicz_znizke](id_klienta) znizka FROM siec_hoteli..klienci k 
WHERE k.id_klienta NOT IN (
	SELECT id_klienta FROM siec_hoteli..rezerwacje r, siec_hoteli..archiwum_rezerwacji ar 
	WHERE r.id_rezerwacji = ar.id_rezerwacji)

-- Gdy klienci mieli pierwsz¹ rezerwacjê wczeœniej ni¿ 10 lat temu. 
SELECT k.id_klienta, [dbo].[oblicz_znizke](id_klienta) znizka FROM siec_hoteli..klienci k 
WHERE k.id_klienta IN (
	SELECT id_klienta FROM siec_hoteli..rezerwacje r, siec_hoteli..archiwum_rezerwacji ar 
	WHERE r.id_rezerwacji = ar.id_rezerwacji AND DATEDIFF(YEAR, r.data_rezerwacji, GETDATE()) < 10)

-- Gdy klienci mieli pierwsz¹ rezerwacjê dawniej ni¿ 10 lat temu. 
SELECT k.id_klienta, [dbo].[oblicz_znizke](id_klienta) znizka FROM siec_hoteli..klienci k 
WHERE k.id_klienta IN (
	SELECT id_klienta FROM siec_hoteli..rezerwacje r, siec_hoteli..archiwum_rezerwacji ar 
	WHERE r.id_rezerwacji = ar.id_rezerwacji AND DATEDIFF(YEAR, r.data_rezerwacji, GETDATE()) > 10)

--------------------------------------------------------------------------------
-- Funkcja 3. Funkcja podaje dla ka¿dego kraju, ile procent wszystkich hoteli znajduje siê w tym kraju.
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