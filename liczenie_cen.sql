-- Dodaj funkcjê zwracaj¹c¹ wspó³czynnik z jakim trzeba bêdzie pomno¿yæ cenê za po³¹czenie telefoniczne. Funkcja ma przyjmowaæ dwa argumenty:
-- numer_telefonu, id_pokoju. Jeœli numer telefonu, na który zosta³o wykonane po³¹czenie nale¿y do któregoœ z pokoi w hotelu z którego wykonano po³¹czenie
-- (na podstawie id_pokoju uzyskujemy id_hotelu z którego wykonano po³¹czenie) wtedy wspó³czynnik ustawiany jest na 0. Dla numeru telefonu pokoju znajduj¹cego
-- siê w innym hotelu wspó³czynnik ustawiany jest na 0.5, dla numerów telefonów spoza hotelu wspó³czynnik ustawiany jest na 1.
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
-- Obliczamy zni¿kê dla klientów którzy ju¿ kupowali w naszym hotelu
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

    IF (DATEDIFF(YEAR, @najstarsza_data_rezerwacji, GETDATE()))
        BEGIN
            SET @wspolczynnik_zniki = 0.5
            RETURN @wspolczynnik_zniki
        END

    SET @wspolczynnik_zniki = 0.75
    RETURN @wspolczynnik_zniki

END;
GO

DECLARE @najstarsza_data_rezerwacji DATETIME;
SET @najstarsza_data_rezerwacji = (SELECT MIN(r.data_rezerwacji)
                                   FROM siec_hoteli..archiwum_rezerwacji ar,
                                        siec_hoteli..rezerwacje r
                                   WHERE ar.id_rezerwacji = r.id_rezerwacji
                                     AND r.id_klienta = 1001)


SELECT id_klienta
FROM siec_hoteli..klienci k
WHERE k.id_klienta NOT IN (SELECT r.id_klienta
                           FROM siec_hoteli..archiwum_rezerwacji ar,
                                siec_hoteli..rezerwacje r
                           WHERE r.id_rezerwacji = ar.id_rezerwacji)

SELECT *
FROM siec_hoteli..archiwum_rezerwacji

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

--------------------------------------------------------------------------------
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


SELECT *
FROM siec_hoteli..archiwum_rezerwacji
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
  AND r.id_pokoju = p.id_pokoju
  AND p.id_pokoju = rt.id_pokoju

SELECT *
FROM siec_hoteli..rozmowy_telefoniczne
WHERE id_pokoju = 110

SELECT r.liczba_dni_rezerwacji,
       h.cena_bazowa_za_pokoj,
       p.liczba_pomieszczen,
       p.liczba_przewidzianych_osob,
       ar.cena_wynajecia_pokoju
FROM siec_hoteli..archiwum_rezerwacji ar,
     siec_hoteli..rezerwacje r,
     siec_hoteli..hotele h,
     siec_hoteli..pokoje p
WHERE ar.id_rezerwacji = r.id_rezerwacji
  AND r.id_pokoju = p.id_pokoju
  AND p.id_hotelu = h.id_hotelu