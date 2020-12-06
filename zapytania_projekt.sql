USE siec_hoteli
GO

-- 1. Wyœwietl liczbê pokoi w ka¿dym z hoteli. Na koñcu dodaj podsumowanie ile jest ³¹cznie pokoi. 
SELECT COUNT(*) as 'Liczba pokoi', nazwa_hotelu 
FROM pokoje p, hotele h
WHERE p.id_hotelu = h.id_hotelu
GROUP BY ROLLUP(nazwa_hotelu)
ORDER BY [Liczba pokoi]
GO

-- 2. Wyœwietl nazwê hotelu, cenê bazow¹ za pokój, nazwê miasta przy tworzeniu rankingu hoteli na podstawie ceny bazowej za 
-- pokój bez przeskoku.  
SELECT nazwa_hotelu, cena_bazowa_za_pokoj, nazwa_miasta,
DENSE_RANK() OVER (ORDER BY cena_bazowa_za_pokoj DESC) AS 'Ranking cen pokoi'
FROM hotele h, miasta m
WHERE h.id_miasta = m.id_miasta
GO

-- 3. Wyœwietl œredni¹ cenê po³¹czeñ telefonicznych hoteli dla miasta zaokr¹glone do drugiej liczby po przecinku wraz z nazw¹ miasta, 
-- posortowane po œredniej.
SELECT DISTINCT nazwa_miasta, ROUND(AVG(cena_za_polaczenie_telefoniczne) OVER (PARTITION BY nazwa_miasta), 2) AS 'Srednia cena polaczen telefonicznych'
FROM hotele h, miasta m
WHERE h.id_miasta = m.id_miasta
ORDER BY [Srednia cena polaczen telefonicznych] DESC
GO

-- 4. Wyœwietl liczbê pokoi dla których nie przewidziano rezerwacji. 
SELECT COUNT(id_pokoju) as 'Liczba pokoi bez rezerwacji' 
FROM pokoje
WHERE id_pokoju NOT IN (SELECT id_pokoju FROM rezerwacje)
GO

-- 5. Wyœwietl piêæ najbli¿szych rezerwacji. 
SELECT top 5 id_rezerwacji, data_rezerwacji, liczba_dni_rezerwacji
FROM rezerwacje
GROUP BY data_rezerwacji, id_rezerwacji, liczba_dni_rezerwacji
ORDER BY data_rezerwacji ASC
GO

-- 6. Wyœwietl wszystkie rezerwacje (id_rezerwacji, data_rezerwacji, liczba_dni_rezerwacji) dla klienta o nazwisku Kowalczyk.
SELECT id_rezerwacji, data_rezerwacji, liczba_dni_rezerwacji
FROM rezerwacje r, klienci k
WHERE r.id_klienta = k.id_klienta AND k.nazwisko_klienta = 'KOWALCZYK'
GROUP BY data_rezerwacji, id_rezerwacji, liczba_dni_rezerwacji
ORDER BY data_rezerwacji ASC
GO

-- 7. Wyœwietl wszystkie us³ugi, które s¹ zarejestrowane dla rezerwacji dla klienta o nazwisku 'Dudziak'. 
SELECT DISTINCT u.nazwa_uslugi 
FROM uslugi u, usluga_dla_rezerwacji ur, klienci k, rezerwacje r
WHERE ur.id_uslugi = u.id_uslugi
AND ur.id_rezerwacji = r.id_rezerwacji
AND r.id_klienta = k.id_klienta
AND k.nazwisko_klienta LIKE 'Dudziak'
GO

-- 8. Wyœwietl imiona, nazwiska, numery telefonów klietów, których imiê koñczy siê na literkê 'a'.
SELECT imie_klienta, nazwisko_klienta, numer_telefonu_klienta 
FROM klienci
WHERE imie_klienta LIKE '%a'
GO

-- 9. Wyœwietl imiona, nazwiska, adresy klientów, którzy mieszkaj¹ w Hiszpani. 
SELECT imie_klienta, nazwisko_klienta, adres_zamieszkania 
FROM klienci
WHERE adres_zamieszkania LIKE '%Hiszpania%'
GO

-- 10. Wyœwietl id_rezerwacji, licza_dni_rezerwacji, data_rezerwacji oraz datê wymeldowania jako data_wymeldowania. 
SELECT id_rezerwacji, liczba_dni_rezerwacji, data_rezerwacji, DATEADD(DAY, liczba_dni_rezerwacji, data_rezerwacji) AS data_wymeldowania
FROM rezerwacje
GO

-- 11. Wyœwietl wszystkie rezerwacje przewidziane na miesi¹c lipiec. 
SELECT id_rezerwacji, liczba_dni_rezerwacji, data_rezerwacji
FROM rezerwacje
WHERE MONTH(data_rezerwacji) = 7
ORDER BY id_rezerwacji
GO

-- 12. Wyœwietl id_sprzatania, id_pokoju, czas trwania sprzatania jako czas_trwania wszystkich pe³nych sprz¹tañ. 
SELECT id_sprzatania, id_pokoju, CAST((data_zakonczenia_sprzatania - data_rozpoczecia_sprzatania) AS TIME(0)) AS czas_trwania 
FROM sprzatanie
WHERE rodzaj_sprzatania = 'Pelne'
GO

-- 13. Wyœwietl wszystkie rozmowy telefoniczne, które trwa³y d³u¿ej ni¿ 5 minut.
SELECT * FROM rozmowy_telefoniczne rt
WHERE DATEDIFF(MINUTE, data_rozpoczecia_rozmowy, CAST(data_zakonczenia_rozmowy AS TIME)) > 5
GO

-- 14. Wyœwietl id_rezerwacji oraz data_rezerwacji dla wszystkich rezerwacji odbywaj¹cych siê po 15 sierpnia 2021 roku. 
SELECT id_rezerwacji, data_rezerwacji 
FROM rezerwacje 
WHERE data_rezerwacji > CONVERT(DATE, '2021/08/15')
GO

-- 15. Wyœwietl wszystkich klientów, których numer telefonu zaczyna siê od liczby '6' i koñczy siê na liczbê 2, ich imiê i nazwisko 
-- po³¹cz w jednej kolumnie o nazwie imie_i_nazwisko. 
SELECT CONCAT(imie_klienta, ' ', nazwisko_klienta) AS imie_i_nazwisko, numer_telefonu_klienta 
FROM klienci
WHERE numer_telefonu_klienta LIKE '6%2'
GO

-- 16. Podwy¿sz wszystkim hotelom cenê bazow¹ za pokój o 5%.
UPDATE hotele
SET cena_bazowa_za_pokoj = 1.05 * cena_bazowa_za_pokoj
SELECT id_hotelu, cena_bazowa_za_pokoj 
FROM hotele
GO

-- 17. Dodaj funkcjê zwracaj¹c¹ wspó³czynnik z jakim trzeba bêdzie pomno¿yæ cenê za po³¹czenie telefoniczne. Funkcja ma przyjmowaæ dwa argumenty: 
-- numer_telefonu, id_pokoju. Jeœli numer telefonu, na który zosta³o wykonane po³¹czenie nale¿y do któregoœ z pokoi w hotelu z którego wykonano po³¹czenie 
-- (na podstawie id_pokoju uzyskujemy id_hotelu z którego wykonano po³¹czenie) wtedy wspó³czynnik ustawiany jest na 0. Dla numeru telefonu pokoju znajduj¹cego 
-- siê w innym hotelu wspó³czynnik ustawiany jest na 0.5, dla numerów telefonów spoza hotelu wspó³czynnik ustawiany jest na 1. 
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