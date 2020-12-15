-- Julia Szymanska 224441
-- Przemek Zdrzalik 224466
-- Martyna Piasecka 224398

DROP DATABASE IF EXISTS siec_hoteli
CREATE DATABASE siec_hoteli
GO

--USE siec_hoteli
--GO

CREATE TABLE siec_hoteli.dbo.panstwa
(
    id_panstwa    CHAR(2)     NOT NULL,
    nazwa_panstwa VARCHAR(40) NOT NULL
);
GO

ALTER TABLE siec_hoteli.dbo.panstwa
    ADD CONSTRAINT panstwa_id_pk PRIMARY KEY (id_panstwa);
GO

CREATE TABLE siec_hoteli.dbo.miasta
(
    id_miasta    INT IDENTITY (10,2) NOT NULL,
    nazwa_miasta VARCHAR(30)         NOT NULL,
    id_panstwa   CHAR(2)             NOT NULL
);
GO

ALTER TABLE siec_hoteli.dbo.miasta
    ADD CONSTRAINT miasta_id_pk PRIMARY KEY (id_miasta);
ALTER TABLE siec_hoteli.dbo.miasta
    ADD CONSTRAINT miasto_panstwo_fk FOREIGN KEY (id_panstwa) REFERENCES panstwa (id_panstwa);
GO

CREATE TABLE siec_hoteli.dbo.hotele
(
    id_hotelu                       INT IDENTITY (100,1) NOT NULL,
    nazwa_hotelu                    VARCHAR(70)          NOT NULL,
    adres_hotelu                    VARCHAR(100)         NOT NULL,
    cena_bazowa_za_pokoj            MONEY                NOT NULL,
    cena_za_polaczenie_telefoniczne MONEY                NOT NULL,
    id_miasta                       INT                  NOT NULL
);
GO

ALTER TABLE siec_hoteli.dbo.hotele
    ADD CONSTRAINT hotele_id_pk PRIMARY KEY (id_hotelu);
ALTER TABLE siec_hoteli.dbo.hotele
    ADD CONSTRAINT cena_bazowa_pokoj_check CHECK (cena_bazowa_za_pokoj > 0);
ALTER TABLE siec_hoteli.dbo.hotele
    ADD CONSTRAINT cena_telefon_check CHECK (cena_za_polaczenie_telefoniczne > 0);
ALTER TABLE siec_hoteli.dbo.hotele
    ADD CONSTRAINT hotel_miasto_fk FOREIGN KEY (id_miasta) REFERENCES miasta (id_miasta);
GO

CREATE TABLE siec_hoteli.dbo.pracownicy
(
    id_pracownika             INT IDENTITY (1,1) NOT NULL,
    imie_pracownika           VARCHAR(20)        NOT NULL,
    nazwisko_pracownika       VARCHAR(40)        NOT NULL,
    email_pracownika          VARCHAR(40) UNIQUE NOT NULL,
    numer_telefonu_pracownika CHAR(9) UNIQUE     NOT NULL,
    data_urodzenia            DATETIME,
    pensja                    MONEY,
    premia                    DECIMAL(2, 2),
    poczatek_pracy            DATETIME           NOT NULL DEFAULT GETDATE(),
    id_hotelu                 INT,
);
GO

ALTER TABLE siec_hoteli.dbo.pracownicy
    ADD CONSTRAINT pracownicy_id_pk PRIMARY KEY (id_pracownika);
ALTER TABLE siec_hoteli.dbo.pracownicy
    ADD CONSTRAINT numer_tel_pracownika_check CHECK (numer_telefonu_pracownika LIKE
                                                     '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]');
ALTER TABLE siec_hoteli.dbo.pracownicy
    ADD CONSTRAINT pensja_pracownika_min CHECK (pensja > 0);
ALTER TABLE siec_hoteli.dbo.pracownicy
    ADD CONSTRAINT data_urodzenia_max CHECK (data_urodzenia < GETDATE());
ALTER TABLE siec_hoteli.dbo.pracownicy
    ADD CONSTRAINT poczatek_pracy_max CHECK (data_urodzenia <= GETDATE());
ALTER TABLE siec_hoteli.dbo.pracownicy
    ADD CONSTRAINT pracownik_hotel_fk FOREIGN KEY (id_hotelu) REFERENCES hotele (id_hotelu);
GO

CREATE TABLE siec_hoteli.dbo.archiwum_pracownikow
(
    koniec_pracy  DATETIME NOT NULL,
    id_pracownika INT      NOT NULL
);
GO

ALTER TABLE siec_hoteli.dbo.archiwum_pracownikow
    ADD CONSTRAINT archiwum_pracownikow_id_pk PRIMARY KEY (id_pracownika);
ALTER TABLE siec_hoteli.dbo.archiwum_pracownikow
    ADD CONSTRAINT archiwum_data_interwal CHECK (koniec_pracy <= GETDATE());
ALTER TABLE siec_hoteli.dbo.archiwum_pracownikow
    ADD CONSTRAINT archiwum_pracownik_fk FOREIGN KEY (id_pracownika) REFERENCES pracownicy (id_pracownika);
GO

CREATE TABLE siec_hoteli.dbo.pokoje
(
    id_pokoju                  INT IDENTITY (100, 1) NOT NULL,
    numer_pokoju               INT                   NOT NULL,
    numer_telefonu_pokoju      CHAR(5) UNIQUE        NOT NULL,
    liczba_przewidzianych_osob INT                   NOT NULL,
    liczba_pomieszczen         INT                   NOT NULL,
    id_hotelu                  INT                   NOT NULL,

    UNIQUE (numer_pokoju, id_hotelu)
);
GO

ALTER TABLE siec_hoteli.dbo.pokoje
    ADD CONSTRAINT pokoje_id_pk PRIMARY KEY (id_pokoju);
ALTER TABLE siec_hoteli.dbo.pokoje
    ADD CONSTRAINT numer_tel_pokoju_check CHECK (numer_telefonu_pokoju LIKE '[0-9][0-9][0-9][0-9][0-9]');
ALTER TABLE siec_hoteli.dbo.pokoje
    ADD CONSTRAINT liczba_przewid_osob_check CHECK (liczba_przewidzianych_osob > 0);
ALTER TABLE siec_hoteli.dbo.pokoje
    ADD CONSTRAINT liczba_pomieszczen_check CHECK (liczba_pomieszczen > 0);
ALTER TABLE siec_hoteli.dbo.pokoje
    ADD CONSTRAINT pokoj_hotel_fk FOREIGN KEY (id_hotelu) REFERENCES hotele (id_hotelu) ON DELETE CASCADE;
GO

CREATE TABLE siec_hoteli.dbo.sprzatanie
(
    id_sprzatania               INT IDENTITY (1,1) NOT NULL,
    data_rozpoczecia_sprzatania DATETIME           NOT NULL,
    data_zakonczenia_sprzatania DATETIME DEFAULT GETDATE(),
    rodzaj_sprzatania           VARCHAR(10),
    id_pokoju                   INT                NOT NULL
);
GO

ALTER TABLE siec_hoteli.dbo.sprzatanie
    ADD CONSTRAINT sprzatanie_id_pk PRIMARY KEY (id_sprzatania);
ALTER TABLE siec_hoteli.dbo.sprzatanie
    ADD CONSTRAINT data_sprzatania_check CHECK (data_zakonczenia_sprzatania >= data_rozpoczecia_sprzatania);
ALTER TABLE siec_hoteli.dbo.sprzatanie
    ADD CONSTRAINT data_zakonczenia_sprzatania_check CHECK (data_zakonczenia_sprzatania <= GETDATE());
ALTER TABLE siec_hoteli.dbo.sprzatanie
    ADD CONSTRAINT rodzaj_sprzatania_wybor CHECK (UPPER(rodzaj_sprzatania) IN ('PODSTAWOWE', 'PELNE'));
ALTER TABLE siec_hoteli.dbo.sprzatanie
    ADD CONSTRAINT sprzatanie_pokoj_fk FOREIGN KEY (id_pokoju) REFERENCES pokoje (id_pokoju) ON DELETE CASCADE;
GO

CREATE TABLE siec_hoteli.dbo.rozmowy_telefoniczne
(
    id_rozmowy_telefonicznej INT IDENTITY (100,1)       NOT NULL,
    numer_telefonu           VARCHAR(9)                 NOT NULL,
    data_rozpoczecia_rozmowy DATETIME                   NOT NULL,
    data_zakonczenia_rozmowy DATETIME DEFAULT GETDATE() NOT NULL,
    id_pokoju                INT                        NOT NULL
);
GO

ALTER TABLE siec_hoteli.dbo.rozmowy_telefoniczne
    ADD CONSTRAINT rozmowy_tel_id_pk PRIMARY KEY (id_rozmowy_telefonicznej);
ALTER TABLE siec_hoteli.dbo.rozmowy_telefoniczne
    ADD CONSTRAINT numer_telefonu_check CHECK (numer_telefonu NOT LIKE '%^(0-9)%');
ALTER TABLE siec_hoteli.dbo.rozmowy_telefoniczne
    ADD CONSTRAINT data_rozmowy_check CHECK (data_zakonczenia_rozmowy >= data_rozpoczecia_rozmowy);
ALTER TABLE siec_hoteli.dbo.rozmowy_telefoniczne
    ADD CONSTRAINT data_zakonczenia_rozmowy_check CHECK (data_zakonczenia_rozmowy <= GETDATE());
ALTER TABLE siec_hoteli.dbo.rozmowy_telefoniczne
    ADD CONSTRAINT rozmowy_pokoj_fk FOREIGN KEY (id_pokoju) REFERENCES pokoje (id_pokoju) ON DELETE CASCADE;
GO

CREATE TABLE siec_hoteli.dbo.klienci
(
    id_klienta             INT IDENTITY (1000,1) NOT NULL,
    imie_klienta           VARCHAR(20)           NOT NULL,
    nazwisko_klienta       VARCHAR(40)           NOT NULL,
    numer_telefonu_klienta CHAR(9) UNIQUE        NOT NULL,
    adres_zamieszkania     VARCHAR(100)          NOT NULL
);
GO

ALTER TABLE siec_hoteli.dbo.klienci
    ADD CONSTRAINT klienci_id_pk PRIMARY KEY (id_klienta);
ALTER TABLE siec_hoteli.dbo.klienci
    ADD CONSTRAINT numer_tel_klienta_check CHECK (numer_telefonu_klienta LIKE
                                                  '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]');
GO

CREATE TABLE siec_hoteli.dbo.rezerwacje
(
    id_rezerwacji         INT IDENTITY (1000,1) NOT NULL,
    data_rezerwacji       DATE                  NOT NULL,
    liczba_dni_rezerwacji INT                   NOT NULL,
    id_pokoju             INT                   NOT NULL,
    id_klienta            INT                   NOT NULL
);

ALTER TABLE siec_hoteli.dbo.rezerwacje
    ADD CONSTRAINT rezerwacje_id_pk PRIMARY KEY (id_rezerwacji);
ALTER TABLE siec_hoteli.dbo.rezerwacje
    ADD CONSTRAINT liczba_dni_check CHECK (liczba_dni_rezerwacji > 0);
ALTER TABLE siec_hoteli.dbo.rezerwacje
    ADD CONSTRAINT rezerwacja_pokoj_fk FOREIGN KEY (id_pokoju) REFERENCES pokoje (id_pokoju) ON DELETE CASCADE;
ALTER TABLE siec_hoteli.dbo.rezerwacje
    ADD CONSTRAINT rezerwacja_klient_fk FOREIGN KEY (id_klienta) REFERENCES klienci (id_klienta);
GO

CREATE TABLE siec_hoteli.dbo.anulowane_rezerwacje
(
    id_rezerwacji         INT  NOT NULL,
    data_rezerwacji       DATE NOT NULL,
    liczba_dni_rezerwacji INT  NOT NULL,
    id_pokoju             INT  NOT NULL,
    id_klienta            INT  NOT NULL
);

ALTER TABLE siec_hoteli.dbo.anulowane_rezerwacje
    ADD CONSTRAINT anulowane_rezerwacje_id_pk PRIMARY KEY (id_rezerwacji);
ALTER TABLE siec_hoteli.dbo.anulowane_rezerwacje
    ADD CONSTRAINT anulowane_rezerwacje_liczba_dni_check CHECK (liczba_dni_rezerwacji > 0);
ALTER TABLE siec_hoteli.dbo.anulowane_rezerwacje
    ADD CONSTRAINT anulowane_rezerwacje_pokoj_fk FOREIGN KEY (id_pokoju) REFERENCES pokoje (id_pokoju) ON DELETE CASCADE;
ALTER TABLE siec_hoteli.dbo.anulowane_rezerwacje
    ADD CONSTRAINT anulowane_rezerwacje_klient_fk FOREIGN KEY (id_klienta) REFERENCES klienci (id_klienta);
GO

CREATE TABLE siec_hoteli.dbo.uslugi
(
    id_uslugi    INT IDENTITY (1,1) NOT NULL,
    nazwa_uslugi VARCHAR(50)        NOT NULL,
    cena_uslugi  MONEY              NOT NULL
);
GO

ALTER TABLE siec_hoteli.dbo.uslugi
    ADD CONSTRAINT uslugi_id_pk PRIMARY KEY (id_uslugi);
ALTER TABLE siec_hoteli.dbo.uslugi
    ADD CONSTRAINT cena_uslugi_check CHECK (cena_uslugi > 0);
GO

CREATE TABLE siec_hoteli.dbo.usluga_dla_rezerwacji
(
    id_uslugi     INT NOT NULL,
    id_rezerwacji INT NOT NULL
);
GO

ALTER TABLE siec_hoteli.dbo.usluga_dla_rezerwacji
    ADD CONSTRAINT usluga_dla_rezerwacji_pk PRIMARY KEY (id_uslugi, id_rezerwacji);
ALTER TABLE siec_hoteli.dbo.usluga_dla_rezerwacji
    ADD CONSTRAINT usluga_dla_rezerwacji_usluga_fk FOREIGN KEY (id_uslugi) REFERENCES uslugi (id_uslugi);
ALTER TABLE siec_hoteli.dbo.usluga_dla_rezerwacji
    ADD CONSTRAINT usluga_dla_rezerwacji_rezerwacja_fk FOREIGN KEY (id_rezerwacji) REFERENCES rezerwacje (id_rezerwacji) ON DELETE CASCADE;
GO

CREATE TABLE siec_hoteli.dbo.archiwum_rezerwacji
(
    cena_calkowita        MONEY DEFAULT 0,
    cena_za_telefon       MONEY DEFAULT 0,
    cena_za_uslugi        MONEY DEFAULT 0,
    cena_wynajecia_pokoju MONEY DEFAULT 0,
    id_rezerwacji         INT NOT NULL,
);
GO

ALTER TABLE siec_hoteli.dbo.archiwum_rezerwacji
    ADD CONSTRAINT archiwum_rezerwacji_id_pk PRIMARY KEY (id_rezerwacji);
ALTER TABLE siec_hoteli.dbo.archiwum_rezerwacji
    ADD CONSTRAINT cena_calkowita_check CHECK (cena_calkowita >= 0);
ALTER TABLE siec_hoteli.dbo.archiwum_rezerwacji
    ADD CONSTRAINT cena_za_telefon_check CHECK (cena_za_telefon >= 0);
ALTER TABLE siec_hoteli.dbo.archiwum_rezerwacji
    ADD CONSTRAINT cena_za_uslugi_check CHECK (cena_za_uslugi >= 0);
ALTER TABLE siec_hoteli.dbo.archiwum_rezerwacji
    ADD CONSTRAINT archiwum_rezerwacji_rezerwacja_fk FOREIGN KEY (id_rezerwacji) REFERENCES rezerwacje (id_rezerwacji);
GO
