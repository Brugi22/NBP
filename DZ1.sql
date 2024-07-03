1. zadatak

SELECT igrac.ime_igrac, igrac.prezime_igrac
FROM igrac
INNER JOIN igrac_klub ON igrac.sif_igrac = igrac_klub.sif_igrac
INNER JOIN klub ON igrac_klub.sif_klub = klub.sif_klub
WHERE klub.naziv_klub = 'OK Kaštela' AND igrac_klub.godina = 2019
ORDER BY igrac.prezime_igrac, igrac.ime_igrac;

Matea,Ćurak
Ema,Kurtović
Marija,Ljulj
Dora,Matas
Jelena,Ninčević
Tonka,Parčina
Ivana,Prkačin
Ana,Rimac
Nika,Stanović
Marija,Sudar
Tea,Vranković
Elena,Vukić
----------------------------------------------------------------------------------------------------------------------------------
2.zadatak

SELECT klub.naziv_klub, igrac_klub.godina
FROM klub, igrac_klub
WHERE klub.sif_klub = igrac_klub.sif_klub
AND igrac_klub.sif_igrac = (SELECT sif_igrac FROM igrac
                            WHERE ime_igrac = 'Jurica' AND prezime_igrac = 'Šućur')
ORDER BY igrac_klub.godina DESC;

OK Split,2022
OK Split,2021
MOK Mursa - Osijek,2020
MOK Mursa - Osijek,2019
MOK Mursa - Osijek,2018
----------------------------------------------------------------------------------------------------------------------------------
3. zadatak

SELECT igrac.ime_igrac, igrac.prezime_igrac, statistika.blokovi, statistika.godina
FROM igrac
INNER JOIN statistika ON igrac.sif_igrac = statistika.sif_igrac
WHERE statistika.blokovi > 90;;

Božana,Butigan,97,2018
Benjamin,Daca,91,2022
----------------------------------------------------------------------------------------------------------------------------------
4. zadatak

SELECT sezona.sezona, MAX(statistika.bodovi) AS bodovi
FROM sezona
INNER JOIN statistika ON sezona.godina = statistika.godina
INNER JOIN igrac ON igrac.sif_igrac = statistika.sif_igrac
WHERE igrac.m_z = 'm'
GROUP BY sezona.sezona;

2018/19,426
2021/22,468
2020/21,509
2019/20,336
2022/23,412
----------------------------------------------------------------------------------------------------------------------------------
5. zadatak

SELECT klub.naziv_klub
FROM klub
INNER JOIN igrac_klub ON klub.sif_klub = igrac_klub.sif_klub
WHERE igrac_klub.godina = 2020 AND klub.m_z = 'z'
GROUP BY klub.naziv_klub;

HAOK Mladost
HAOK Rijeka CO
OK Brda
OK Dinamo
OK Kaštela
OK Marina Kaštela
OK Olimpik
OK Poreč
OK Split
OK Veli Vrh
ŽOK Dubrovnik
ŽOK Enna Vukovar
ŽOK Osijek
