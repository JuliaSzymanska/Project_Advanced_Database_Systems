-- Funkcja 1. Funkcja zwracaj�c� wsp�czynnik z jakim trzeba b�dzie pomno�y� cen� za po��czenie telefoniczne. Funkcja ma przyjmowa� dwa argumenty:
-- numer_telefonu, id_pokoju. Je�li numer telefonu, na kt�ry zosta�o wykonane po��czenie nale�y do kt�rego� z pokoi w hotelu z kt�rego wykonano po��czenie
-- (na podstawie id_pokoju uzyskujemy id_hotelu z kt�rego wykonano po��czenie) wtedy wsp�czynnik ustawiany jest na 0. Dla numeru telefonu pokoju znajduj�cego
-- si� w innym hotelu wsp�czynnik ustawiany jest na 0.5, dla numer�w telefon�w spoza sieci hoteli wsp�czynnik ustawiany jest na 1.
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

-- Sprawdzenie dzia�ania funkcji
-- Dla przypadku gdzie, niekt�re pokoje s� w tym samym hotelu co numer, na ktory jest wykonywane po��czenie, natomiast pozosta�e znajduj� si� w innym hotelu.
DECLARE @numer_telefonu VARCHAR(9) = '69421' 
SELECT [dbo].[oblicz_wspoczynnik](@numer_telefonu, id_pokoju) FROM siec_hoteli..rozmowy_telefoniczne

-- Dla przypadku, gdy numer, na kt�ry wykonywane jest po��czenie jest spoza sieci hoteli. 
SET @numer_telefonu = '205947321'
SELECT [dbo].[oblicz_wspoczynnik](@numer_telefonu, id_pokoju) FROM siec_hoteli..rozmowy_telefoniczne


--------------------------------------------------------------------------------
GO
-- Funkcja 2. Funkcja obliczaj�ca zni�k� dla klient�w, kt�rzy posiadaj� rezerwacj� w archiwum rezerwacji, warto�c zni�ki wynosi 25%, 
-- natomiast dla klient�w, kt�rych najstarsza rezerwacja ma wi�cej ni� 10 lat zni�ka wynosi 50%. 
-- Dla klient�w, kt�ry nie maj� rezerwacji w archiwum rezerwacji zni�ka wynosi 0%.
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

-- Sprawdzenie dzia�ania funkcji
-- Gdy klienci nie mieli jak dot�d �adnej rezerwacji
SELECT k.id_klienta, [dbo].[oblicz_znizke](id_klienta) znizka FROM siec_hoteli..klienci k 
WHERE k.id_klienta NOT IN (
	SELECT id_klienta FROM siec_hoteli..rezerwacje r, siec_hoteli..archiwum_rezerwacji ar 
	WHERE r.id_rezerwacji = ar.id_rezerwacji)

-- Gdy klienci mieli pierwsz� rezerwacj� wcze�niej ni� 10 lat temu. 
SELECT k.id_klienta, [dbo].[oblicz_znizke](id_klienta) znizka FROM siec_hoteli..klienci k 
WHERE k.id_klienta IN (
	SELECT id_klienta FROM siec_hoteli..rezerwacje r, siec_hoteli..archiwum_rezerwacji ar 
	WHERE r.id_rezerwacji = ar.id_rezerwacji AND DATEDIFF(YEAR, r.data_rezerwacji, GETDATE()) < 10)

-- Gdy klienci mieli pierwsz� rezerwacj� dawniej ni� 10 lat temu. 
SELECT k.id_klienta, [dbo].[oblicz_znizke](id_klienta) znizka FROM siec_hoteli..klienci k 
WHERE k.id_klienta IN (
	SELECT id_klienta FROM siec_hoteli..rezerwacje r, siec_hoteli..archiwum_rezerwacji ar 
	WHERE r.id_rezerwacji = ar.id_rezerwacji AND DATEDIFF(YEAR, r.data_rezerwacji, GETDATE()) > 10)

--------------------------------------------------------------------------------
-- Funkcja 3. Funkcja podaje dla ka�dego kraju, ile procent wszystkich hoteli znajduje si� w tym kraju.
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