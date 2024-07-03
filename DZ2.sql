CREATE TABLE Automobili
(
    ID                SERIAL PRIMARY KEY,
    Model             VARCHAR(50),
    Marka             VARCHAR(50) NOT NULL,
    GodinaProizvodnje INT         NOT NULL
);

CREATE TABLE Instruktor
(
    OIB       VARCHAR(11) PRIMARY KEY,
    Ime       VARCHAR(50) NOT NULL,
    Prezime   VARCHAR(50) NOT NULL,
    Automobil INT REFERENCES Automobili (ID)
);

CREATE TABLE Polaznik
(
    OIB                VARCHAR(11) PRIMARY KEY,
    Ime                VARCHAR(50)    NOT NULL,
    Prezime            VARCHAR(50)    NOT NULL,
    UkupnaSkolarina    DECIMAL(10, 2) NOT NULL,
    UplacenoIznos      DECIMAL(10, 2) CHECK (UplacenoIznos >= UkupnaSkolarina / 3 AND UplacenoIznos <= UkupnaSkolarina),
    UkupnoSatiVoznje   INT DEFAULT 35 NOT NULL,
    OdradenoSatiVoznje INT DEFAULT 0 CHECK (OdradenoSatiVoznje >= 0 AND OdradenoSatiVoznje <= UkupnoSatiVoznje)
);

CREATE TABLE Ispit
(
    ID          SERIAL PRIMARY KEY,
    Datum       DATE    NOT NULL,
    Vrijeme     TIME    NOT NULL,
    PolaznikOIB VARCHAR(11) REFERENCES Polaznik (OIB),
    Tip         VARCHAR(50) CHECK (Tip IN ('teorija', 'prva_pomoc', 'voznja')),
    Polozen     BOOLEAN NOT NULL
);

CREATE TABLE Voznja
(
    ID            SERIAL PRIMARY KEY,
    Datum         DATE NOT NULL,
    Vrijeme       TIME NOT NULL,
    BrojSati      INT  NOT NULL,
    PolaznikOIB   VARCHAR(11) REFERENCES Polaznik (OIB),
    InstruktorOIB VARCHAR(11) REFERENCES Instruktor (OIB)
);

CREATE VIEW StanjePolaznika AS
SELECT
    p.OIB AS OIB,
    p.Ime AS Ime,
    p.Prezime AS Prezime,
    CASE
        WHEN p.UkupnaSkolarina - p.UplacenoIznos > 0 THEN 'Nije plaćeno'
        ELSE 'Plaćeno'
    END AS FinancijskiStatus,
    CASE
        WHEN EXISTS (SELECT * FROM Ispit WHERE Tip = 'teorija' AND Polozen = true AND PolaznikOIB = p.OIB) THEN 'Da'
        ELSE 'Ne'
    END AS PolozenaTeorija,
    CASE
        WHEN EXISTS (SELECT * FROM Ispit WHERE Tip = 'prva_pomoc' AND Polozen = true AND PolaznikOIB = p.OIB) THEN 'Da'
        ELSE 'Ne'
    END AS PolozenaPrvaPomoc,
    p.OdradenoSatiVoznje,
    (SELECT COUNT(*) FROM Ispit WHERE Tip = 'voznja' AND PolaznikOIB = p.OIB) AS BrojIzlazakaNaIspitVoznje,
    p.UkupnoSatiVoznje - 35 AS UkupniDodatniSati
FROM
    Polaznik p;

CREATE OR REPLACE FUNCTION DodajUplatu(
    polaznik_oib VARCHAR(11),
    iznos DECIMAL
) RETURNS VOID AS $$
BEGIN
    UPDATE Polaznik
    SET UplacenoIznos = UplacenoIznos + iznos
    WHERE OIB = polaznik_oib;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION UpdejtajPolaznika() RETURNS TRIGGER AS $$
BEGIN
    UPDATE Polaznik
    SET OdradenoSatiVoznje = OdradenoSatiVoznje + NEW.BrojSati
    WHERE OIB = NEW.PolaznikOIB;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ProvjeriIspite() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.Tip = 'voznja' THEN
        IF NOT EXISTS (
            SELECT 1
            FROM Ispit
            WHERE PolaznikOIB = NEW.PolaznikOIB AND Polozen = true AND Tip IN ('teorija')
        ) THEN
            RAISE EXCEPTION 'Polaznik % % nije položio ispit iz teroije.', (SELECT Ime FROM Polaznik WHERE OIB = NEW.PolaznikOIB), (SELECT Prezime FROM Polaznik WHERE OIB = NEW.PolaznikOIB);
        END IF;

        IF NOT EXISTS(
            SELECT 1
            FROM Ispit
            WHERE PolaznikOIB = NEW.PolaznikOIB AND Polozen = true AND Tip IN ('prva_pomoc')
        )THEN
            RAISE EXCEPTION 'Polaznik % % nije položio ispit iz prve pomoći.', (SELECT Ime FROM Polaznik WHERE OIB = NEW.PolaznikOIB), (SELECT Prezime FROM Polaznik WHERE OIB = NEW.PolaznikOIB);
        END IF;

        IF NOT EXISTS(
            SELECT 1
            FROM Polaznik
            WHERE OIB = NEW.PolaznikOIB AND UkupnoSatiVoznje = OdradenoSatiVoznje
        )THEN
            RAISE EXCEPTION 'Polaznik % % nije odradio dovoljan broj sati vožnje', (SELECT Ime FROM Polaznik WHERE OIB = NEW.PolaznikOIB), (SELECT Prezime FROM Polaznik WHERE OIB = NEW.PolaznikOIB);
        END IF;

        IF NEW.Polozen = false THEN
            UPDATE Polaznik
            SET UkupnoSatiVoznje = UkupnoSatiVoznje + 5
            WHERE OIB = NEW.PolaznikOIB;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ProvjeriIspiteTrigger
BEFORE INSERT ON Ispit
FOR EACH ROW
EXECUTE FUNCTION ProvjeriIspite();

CREATE TRIGGER UpdejtPolaznikaTrigger
BEFORE INSERT ON Voznja
FOR EACH ROW
EXECUTE FUNCTION UpdejtajPolaznika();

CREATE OR REPLACE FUNCTION PoredakInstruktora(godina INT) RETURNS TABLE (ImeInstruktora VARCHAR(50), PrezimeInstruktora VARCHAR(50), BrojOdradenihSati BIGINT, OdstupanjeOdProsjeka NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT
        Ime,
        Prezime,
        (SELECT SUM(BrojSati) FROM Voznja WHERE InstruktorOIB = I.OIB AND EXTRACT(YEAR FROM Datum) = godina) AS OdrzaniSati,
        (SELECT SUM(BrojSati) FROM Voznja WHERE InstruktorOIB = I.OIB AND EXTRACT(YEAR FROM Datum) = godina) - (SELECT AVG(OdrzaniSati) FROM (SELECT SUM(BrojSati) AS OdrzaniSati FROM Voznja WHERE EXTRACT(YEAR FROM Datum) = godina GROUP BY InstruktorOIB) AS AvgOdrzaniSati) AS Razlika
    FROM
        Instruktor I;
END;
$$ LANGUAGE plpgsql;

INSERT INTO Automobili (Model, Marka, GodinaProizvodnje) VALUES ('Camry', 'Toyota', 2019),
                                                                ('Civic', 'Honda', 2018);

INSERT INTO Instruktor (Oib, Ime, Prezime, Automobil) VALUES ('11111111111', 'Marko', 'Marković', 1),
                                                             ('22222222222', 'Ana', 'Anić', 2);

INSERT INTO Polaznik (Oib, Ime, Prezime, UkupnaSkolarina, UplacenoIznos) VALUES ('12345678911', 'ime', 'prezime', 1000, 200);

INSERT INTO Polaznik (Oib, Ime, Prezime, UkupnaSkolarina, UplacenoIznos) VALUES ('33333333333', 'Ivan', 'Ivanić', 1000, 350),
                                                                                ('44444444444', 'Petra', 'Perić', 1200, 1200);

SELECT DodajUplatu('44444444444', 100);
SELECT DodajUplatu('33333333333', 100);

SELECT * FROM StanjePolaznika;
SELECT * FROM PoredakInstruktora(2024);
--
INSERT INTO Ispit (PolaznikOIB, Tip, Polozen, Datum, Vrijeme) VALUES ('33333333333', 'teorija', true,'2024-02-01', '10:00:00');
INSERT INTO Ispit (PolaznikOIB, Tip, Polozen, Datum, Vrijeme) VALUES ('44444444444', 'prva_pomoc', true, '2024-02-08', '09:00:00');
INSERT INTO Ispit (PolaznikOIB, Tip, Polozen, Datum, Vrijeme) VALUES ('44444444444', 'voznja', true,'2024-02-09', '10:00:00');
INSERT INTO Ispit (PolaznikOIB, Tip, Polozen, Datum, Vrijeme) VALUES ('44444444444', 'teorija', true,'2024-02-10', '10:00:00');

SELECT * FROM StanjePolaznika;

INSERT INTO Ispit (PolaznikOIB, Tip, Polozen, Datum, Vrijeme) VALUES ('44444444444', 'voznja', false,'2024-02-11', '10:00:00');
INSERT INTO Voznja (PolaznikOIB, InstruktorOIB, Datum, Vrijeme, BrojSati) VALUES ('44444444444', '11111111111', '2024-03-01', '10:00:00', 35),
                                                                                 ('33333333333', '22222222222', '2024-03-08', '09:00:00', 1);
INSERT INTO Ispit (PolaznikOIB, Tip, Polozen, Datum, Vrijeme) VALUES ('44444444444', 'voznja', false,'2024-02-12', '10:00:00');
INSERT INTO Voznja (PolaznikOIB, InstruktorOIB, Datum, Vrijeme, BrojSati) VALUES ('44444444444', '11111111111', '2024-03-01', '10:00:00', 5);
INSERT INTO Ispit (PolaznikOIB, Tip, Polozen, Datum, Vrijeme) VALUES ('44444444444', 'voznja', true,'2024-02-12', '10:00:00');

SELECT * FROM StanjePolaznika;
SELECT * FROM PoredakInstruktora(2024);
