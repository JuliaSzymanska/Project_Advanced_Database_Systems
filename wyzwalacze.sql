-- Julia Szymanska 224441
-- Przemek Zdrzalik 224466
-- Martyna Piasecka 224398

-- Wyzwalacz nr. 1 - Po zmianie premii, jesli premia jest zwiêkszona o wiêcej ni¿ 10 punktów procentowych, 
-- zwiêksz pensjê pracownika o po³owê iloczyny premii i pensji
USE siec_hoteli
GO

DROP TRIGGER IF EXISTS zwieksz_pensje
GO

CREATE TRIGGER zwieksz_pensje
    ON siec_hoteli.dbo.pracownicy
    INSTEAD OF UPDATE
    AS
    IF (UPDATE(premia))
        BEGIN
            UPDATE dbo.pracownicy
            SET dbo.pracownicy.pensja += i.pensja * i.premia * 0.5
            FROM inserted i
            WHERE dbo.pracownicy.id_pracownika = i.id_pracownika
              AND (i.premia - dbo.pracownicy.premia) > 0.1

            UPDATE dbo.pracownicy
            SET premia = i.premia
            FROM inserted i
            WHERE dbo.pracownicy.id_pracownika = i.id_pracownika
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


-- Sprawdzenie dzialania wyzwalacza
SELECT *
FROM siec_hoteli..archiwum_rezerwacji
GO

INSERT INTO siec_hoteli.dbo.archiwum_rezerwacji(cena_calkowita, cena_za_telefon, cena_za_uslugi,
												id_rezerwacji)
VALUES 
		(0, 0, 0, 1049),
		(0, 0, 0, 1050),
		(0, 0, 0, 1023),
		(0, 0, 0, 1001),
		(0, 0, 0, 1005),
		(0, 0, 0, 1009),
		(0, 0, 0, 1010),
		(0, 0, 0, 1019),
		(0, 0, 0, 1032),
		(0, 0, 0, 1033),
		(0, 0, 0, 1034),
		(0, 0, 0, 1035),
		(0, 0, 0, 1036),
		(0, 0, 0, 1037),
		(0, 0, 0, 1038),
		(0, 0, 0, 1039),
		(0, 0, 0, 1040),
		(0, 0, 0, 1041),
		(0, 0, 0, 1042),
		(0, 0, 0, 1043),
		(0, 0, 0, 1044),
		(0, 0, 0, 1045),
		(0, 0, 0, 1046),
		(0, 0, 0, 1047), 
		(0, 0, 0, 1048),
		(0, 0, 0, 1051);
GO

GO

-- Wyzwalacz nr. 4 Przy wprowadzaniu rezerwacji sprawdzane jest czy data nie konfliktuje z istniej¹cymi rezerwacjami dla tego pokoju : )
USE siec_hoteli
GO

DROP TRIGGER IF EXISTS czy_rezerwacja_moze_byc_dodana
GO

CREATE TRIGGER czy_rezerwacja_moze_byc_dodana
    ON siec_hoteli.dbo.rezerwacje
    INSTEAD OF INSERT
    AS
    DECLARE
        @id_rezerwacji         INT,
        @data_rezerwacji       DATE,
        @liczba_dni_rezerwacji INT,
        @id_pokoju             INT,
        @id_klienta            INT
DECLARE kursor CURSOR FOR
    SELECT i.id_rezerwacji, i.data_rezerwacji, i.liczba_dni_rezerwacji, i.id_pokoju, i.id_klienta
    FROM inserted i
BEGIN
    OPEN kursor
    FETCH NEXT FROM kursor INTO @id_rezerwacji, @data_rezerwacji, @liczba_dni_rezerwacji, @id_pokoju, @id_klienta
    WHILE @@FETCH_STATUS = 0
        BEGIN
            IF NOT EXISTS(SELECT *
                          FROM siec_hoteli..rezerwacje r
                          WHERE ((r.data_rezerwacji >= @data_rezerwacji
                              AND r.data_rezerwacji <=
                                  DATEADD(DAY, @liczba_dni_rezerwacji, @data_rezerwacji))
                              OR (DATEADD(DAY, r.liczba_dni_rezerwacji, r.data_rezerwacji) >=
                                  @data_rezerwacji AND
                                  DATEADD(DAY, r.liczba_dni_rezerwacji, r.data_rezerwacji) <=
                                  DATEADD(DAY, @liczba_dni_rezerwacji, @data_rezerwacji))))
                BEGIN
                    INSERT INTO siec_hoteli..rezerwacje (data_rezerwacji, liczba_dni_rezerwacji, id_pokoju, id_klienta)
                    VALUES (@data_rezerwacji, @liczba_dni_rezerwacji, @id_pokoju, @id_klienta)
                END
            ELSE
                RAISERROR ('Ten pokoj jest juz zajety w tym terminie.', 14, 1)
            FETCH NEXT FROM kursor INTO @id_rezerwacji, @data_rezerwacji, @liczba_dni_rezerwacji, @id_pokoju, @id_klienta
        END
    CLOSE kursor
    DEALLOCATE kursor
END
GO

USE master
GO

-- Sprawdzenie dzialania wyzwalacza.
BEGIN
    INSERT INTO siec_hoteli.dbo.rezerwacje(data_rezerwacji, liczba_dni_rezerwacji, id_pokoju, id_klienta)
    VALUES ('2025/12/19', 5, 101, 1002);
    INSERT INTO siec_hoteli.dbo.rezerwacje(data_rezerwacji, liczba_dni_rezerwacji, id_pokoju, id_klienta)
    VALUES ('2025/12/21', 7, 101, 1031);
END
GO

-- Trigger 5 - Przed usuniêciem hotelu wszyscy pracownicy pracuj¹cy w danym hotelu przenoszeni s¹ do archiwum pracowników a ich hotel ustawiany jest na Null
USE siec_hoteli
GO

DROP TRIGGER IF EXISTS usun_hotel
GO

CREATE TRIGGER usun_hotel
    ON siec_hoteli.dbo.hotele
    INSTEAD OF DELETE
    AS
BEGIN
    UPDATE siec_hoteli..pracownicy
    SET id_hotelu = NULL
    WHERE id_hotelu IN (SELECT d.id_hotelu FROM deleted d)

    DECLARE kursor CURSOR FOR
        SELECT p.id_pracownika, p.id_hotelu
        FROM siec_hoteli..pracownicy p

    DECLARE @id_prac INT, @id_hotel INT

    BEGIN
        OPEN kursor
        FETCH NEXT FROM kursor INTO @id_prac, @id_hotel
        WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @id_hotel IS NULL
                    BEGIN
                        IF NOT EXISTS(SELECT *
                                      FROM siec_hoteli..archiwum_pracownikow p
                                      WHERE p.id_pracownika = @id_prac)
                            BEGIN
                                INSERT INTO siec_hoteli..archiwum_pracownikow(koniec_pracy, id_pracownika)
                                VALUES (GETDATE(), @id_prac)
                            END
                    END
                FETCH NEXT FROM kursor INTO @id_prac, @id_hotel
            END
        CLOSE kursor
        DEALLOCATE kursor
    END
    DELETE FROM siec_hoteli..hotele WHERE id_hotelu IN (SELECT d.id_hotelu FROM deleted d)
END
GO

USE master
GO

-- Sprawdzenie dzialania wyzwalacza
BEGIN
	SELECT *
	FROM siec_hoteli..archiwum_pracownikow
	DELETE
	FROM siec_hoteli..hotele
	WHERE id_hotelu = 100
	SELECT *
	FROM siec_hoteli..archiwum_pracownikow
END