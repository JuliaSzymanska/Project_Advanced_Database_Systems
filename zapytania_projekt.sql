USE siec_hoteli
GO

-- 1. Wy�wietl liczb� pokoi w ka�dym z hoteli. Na ko�cu dodaj podsumowanie ile jest ��cznie pokoi. 
SELECT COUNT(*) as 'Liczba pokoi', nazwa_hotelu 
FROM pokoje p, hotele h
WHERE p.id_hotelu = h.id_hotelu
GROUP BY ROLLUP(nazwa_hotelu)
ORDER BY [Liczba pokoi]
GO

-- 2. Wy�wietl nazw� hotelu, cen� bazow� za pok�j, nazw� miasta przy tworzeniu rankingu hoteli na podstawie ceny bazowej za 
-- pok�j bez przeskoku.  
SELECT nazwa_hotelu, cena_bazowa_za_pokoj, nazwa_miasta,
DENSE_RANK() OVER (ORDER BY cena_bazowa_za_pokoj DESC) AS 'Ranking cen pokoi'
FROM hotele h, miasta m
WHERE h.id_miasta = m.id_miasta
GO

-- 3. Wy�wietl �redni� cen� po��cze� telefonicznych hoteli dla miasta zaokr�glone do drugiej liczby po przecinku wraz z nazw� miasta, 
-- posortowane po �redniej.
SELECT DISTINCT nazwa_miasta, ROUND(AVG(cena_za_polaczenie_telefoniczne) OVER (PARTITION BY nazwa_miasta), 2) AS 'Srednia cena polaczen telefonicznych'
FROM hotele h, miasta m
WHERE h.id_miasta = m.id_miasta
ORDER BY [Srednia cena polaczen telefonicznych] DESC
GO

-- 4. Wy�wietl liczb� pokoi dla kt�rych nie przewidziano rezerwacji. 
SELECT COUNT(id_pokoju) as 'Liczba pokoi bez rezerwacji' 
FROM pokoje
WHERE id_pokoju NOT IN (SELECT id_pokoju FROM rezerwacje)
GO

-- 5. Wy�wietl pi�� najbli�szych rezerwacji. 
SELECT top 5 id_rezerwacji, data_rezerwacji, liczba_dni_rezerwacji
FROM rezerwacje
GROUP BY data_rezerwacji, id_rezerwacji, liczba_dni_rezerwacji
ORDER BY data_rezerwacji ASC
GO

-- 6. Wy�wietl wszystkie rezerwacje (id_rezerwacji, data_rezerwacji, liczba_dni_rezerwacji) dla klienta o nazwisku Kowalczyk.
SELECT id_rezerwacji, data_rezerwacji, liczba_dni_rezerwacji
FROM rezerwacje r, klienci k
WHERE r.id_klienta = k.id_klienta AND k.nazwisko_klienta = 'KOWALCZYK'
GROUP BY data_rezerwacji, id_rezerwacji, liczba_dni_rezerwacji
ORDER BY data_rezerwacji ASC
GO

-- 7. Wy�wietl wszystkie us�ugi, kt�re s� zarejestrowane dla rezerwacji dla klienta o nazwisku 'Dudziak'. 
SELECT DISTINCT u.nazwa_uslugi 
FROM uslugi u, usluga_dla_rezerwacji ur, klienci k, rezerwacje r
WHERE ur.id_uslugi = u.id_uslugi
AND ur.id_rezerwacji = r.id_rezerwacji
AND r.id_klienta = k.id_klienta
AND k.nazwisko_klienta LIKE 'Dudziak'
GO

-- 8. Wy�wietl imiona, nazwiska, numery telefon�w kliet�w, kt�rych imi� ko�czy si� na literk� 'a'.
SELECT imie_klienta, nazwisko_klienta, numer_telefonu_klienta 
FROM klienci
WHERE imie_klienta LIKE '%a'
GO

-- 9. Wy�wietl imiona, nazwiska, adresy klient�w, kt�rzy mieszkaj� w Hiszpani. 
SELECT imie_klienta, nazwisko_klienta, adres_zamieszkania 
FROM klienci
WHERE adres_zamieszkania LIKE '%Hiszpania%'
GO

-- 10. Wy�wietl id_rezerwacji, licza_dni_rezerwacji, data_rezerwacji oraz dat� wymeldowania jako data_wymeldowania. 
SELECT id_rezerwacji, liczba_dni_rezerwacji, data_rezerwacji, DATEADD(DAY, liczba_dni_rezerwacji, data_rezerwacji) AS data_wymeldowania
FROM rezerwacje
GO

-- 11. Wy�wietl wszystkie rezerwacje przewidziane na miesi�c lipiec. 
SELECT id_rezerwacji, liczba_dni_rezerwacji, data_rezerwacji
FROM rezerwacje
WHERE MONTH(data_rezerwacji) = 7
ORDER BY id_rezerwacji
GO

-- 12. Wy�wietl id_sprzatania, id_pokoju, czas trwania sprzatania jako czas_trwania wszystkich pe�nych sprz�ta�. 
SELECT id_sprzatania, id_pokoju, CAST((data_zakonczenia_sprzatania - data_rozpoczecia_sprzatania) AS TIME(0)) AS czas_trwania 
FROM sprzatanie
WHERE rodzaj_sprzatania = 'Pelne'
GO

-- 13. Wy�wietl wszystkie rozmowy telefoniczne, kt�re trwa�y d�u�ej ni� 5 minut.
SELECT * FROM rozmowy_telefoniczne rt
WHERE DATEDIFF(MINUTE, data_rozpoczecia_rozmowy, CAST(data_zakonczenia_rozmowy AS TIME)) > 5
GO

-- 14. Wy�wietl id_rezerwacji oraz data_rezerwacji dla wszystkich rezerwacji odbywaj�cych si� po 15 sierpnia 2021 roku. 
SELECT id_rezerwacji, data_rezerwacji 
FROM rezerwacje 
WHERE data_rezerwacji > CONVERT(DATE, '2021/08/15')
GO

-- 15. Wy�wietl wszystkich klient�w, kt�rych numer telefonu zaczyna si� od liczby '6' i ko�czy si� na liczb� 2, ich imi� i nazwisko 
-- po��cz w jednej kolumnie o nazwie imie_i_nazwisko. 
SELECT CONCAT(imie_klienta, ' ', nazwisko_klienta) AS imie_i_nazwisko, numer_telefonu_klienta 
FROM klienci
WHERE numer_telefonu_klienta LIKE '6%2'
GO

-- 16. Podwy�sz wszystkim hotelom cen� bazow� za pok�j o 5%.
UPDATE hotele
SET cena_bazowa_za_pokoj = 1.05 * cena_bazowa_za_pokoj
SELECT id_hotelu, cena_bazowa_za_pokoj 
FROM hotele
GO

-- 17. Dodaj funkcj� zwracaj�c� wsp�czynnik z jakim trzeba b�dzie pomno�y� cen� za po��czenie telefoniczne. Funkcja ma przyjmowa� dwa argumenty: 
-- numer_telefonu, id_pokoju. Je�li numer telefonu, na kt�ry zosta�o wykonane po��czenie nale�y do kt�rego� z pokoi w hotelu z kt�rego wykonano po��czenie 
-- (na podstawie id_pokoju uzyskujemy id_hotelu z kt�rego wykonano po��czenie) wtedy wsp�czynnik ustawiany jest na 0. Dla numeru telefonu pokoju znajduj�cego 
-- si� w innym hotelu wsp�czynnik ustawiany jest na 0.5, dla numer�w telefon�w spoza hotelu wsp�czynnik ustawiany jest na 1. 
GO
CREATE OR ALTER FUNCTION oblicz_wspoczynnik 
(
	@numer_telefonu VARCHAR(9), 
	@id_pokoju INT
)
RETURNS FLOAT(2)
AS BEGIN
      DECLARE @wspolczynnik FLOAT(2); 
	  
      IF EXISTS (SELECT * FROM pokoje p 
				WHERE p.numer_telefonu_pokoju = @numer_telefonu
	  AND p.id_hotelu = (SELECT id_hotelu 
						FROM pokoje p 
						WHERE p.id_pokoju = @id_pokoju)) 
		BEGIN
			SET @wspolczynnik = 0.00
		END
	  ELSE IF EXISTS (SELECT * FROM pokoje p 
					  WHERE @numer_telefonu = p.numer_telefonu_pokoju
	  AND p.id_hotelu != (SELECT id_hotelu 
						FROM pokoje p 
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

--19. 

CREATE PROCEDURE premia
@id INT = -1, @procent INT = -1
AS
BEGIN
	IF @procent = -1 AND @id = -1
		BEGIN
			UPDATE pracownicy
			SET premia = 0
			WHERE premia IS NULL;
		END
	ELSE IF @procent = -1 AND @id != -1
		BEGIN
			UPDATE pracownicy
			SET premia = 0
			WHERE premia IS NULL
			AND @id = id_pracownika
		END
	ELSE IF @procent != -1 AND @id != -1
		BEGIN
			UPDATE pracownicy
			SET premia = premia * ((100.00 + @procent) / 100.00)
			WHERE @id = id_pracownika
		END
	ELSE 
		BEGIN
			DECLARE kursor_premia CURSOR FOR
				SELECT id_pracownika FROM pracownicy
			DECLARE @id_kr INT
			BEGIN
			OPEN kursor_premia
			FETCH NEXT FROM kursor_premia INTO @id_kr
			WHILE @@FETCH_STATUS = 0
				BEGIN
					UPDATE pracownicy
					SET premia = premia * ((100.00 + @procent) / 100.00)
					WHERE CURRENT OF kursor_premia
					FETCH NEXT FROM kursor_premia INTO @id_kr
				END
			CLOSE kursor_placa
			DEALLOCATE kursor_placa
		END
		
		END

END
GO