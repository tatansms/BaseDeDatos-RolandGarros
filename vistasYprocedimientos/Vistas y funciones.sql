--¿Cuántas noticias tiene el campeonato ROLAND GARROS en cada una de sus temporadas?

CREATE MATERIALIZED VIEW CantidadDeNoticiasPorAño
AS
SELECT COUNT(*) AS NoticiasPorCadaAño,
		EXTRACT(YEAR FROM fechaNoticia)AS Año
FROM Noticias
GROUP BY fechaNoticia;

--2. ¿Cual es el primer nombre, el id del tenista, el peso, la altura,fecha de nacimiento, su puntaje ranking ATP o WTA 
--id categoria en el torneo y el id del torneo, de uno y solo uno de los tenistas más reciente en el torneo? 

CREATE MATERIALIZED VIEW tenistaMasReciente
AS
SELECT p.primerNombre, t.*, tet.*
FROM Tenistas AS t
INNER JOIN Personas AS p ON t.idTenista = p.idPersona
INNER JOIN tenistasEnElTorneo AS tet ON t.idTenista = tet.idTenista
WHERE tet.idTorneo = (
    SELECT idTorneo
    FROM Torneos
    ORDER BY fechaInicioDelTorneo ASC
    LIMIT 1;
)
ORDER BY tet.idTorneo DESC
LIMIT 1;

--3.¿Cuál es el nombre, el id y el numero de participaciones en el RG, de los tenistas con más apariciones en el torneo? Dame el top 3.

CREATE MATERIALIZED VIEW TenistaConMasParticipaciones
AS
SELECT p.primerNombre,t.idTenista,COUNT(*) AS num_participaciones
FROM Tenistas AS t
INNER JOIN Personas AS p ON t.idTenista = p.idPersona
INNER JOIN tenistasEnElTorneo AS tet ON t.idTenista = tet.idTenista
GROUP BY t.idTenista,p.primernombre
ORDER BY num_participaciones DESC
LIMIT 3;

--4.¿Cuál es el nombre, el id y la edad (en años) de todos los Tenistas registrados en el torneo? 1
CREATE OR REPLACE FUNCTION edad(fechaNacimiento DATE)
RETURNS INT
AS
$$
	DECLARE
	edad INT;
	hoy DATE;
	BEGIN
		hoy := NOW();
		edad := EXTRACT (YEAR FROM AGE(hoy, fechaNacimiento));
		return edad;
	END;
$$
language 'plpgsql';

--forma de probar la primera funcion
SELECT p.primerNombre,idTenista, edad(fechaNacimiento)
FROM Tenistas AS t
INNER JOIN Personas AS p ON t.idTenista = p.idPersona;

--5. ¿Como insetar una Arbitro y crear su tipo de categoria? 

create or replace procedure insertarArbitro(idArbitro int , idioma varchar(100), experiencia int , idCategoria int ,nombre varchar(100), 
				descripcion varchar(200))
AS
$$
	BEGIN
		RAISE NOTICE 'insertando categoria del arbitro%',idCategoria;
			INSERT INTO categoriasDeLosArbitros
			VALUES(idCategoria,nombre, descripcion);
		RAISE NOTICE 'tipo o categoria de arbitro % insertado',idCategoria;

		RAISE NOTICE 'insertando arbitro%)',idArbitro;
			INSERT INTO Arbitros
			VALUES(idArbitro, idioma, experiencia, idCategoria);
		RAISE NOTICE 'Arbitro % insertado)',idArbitro;
	END
$$
language 'plpgsql';
--forma de probarlo
CALL insertarArbitro(501,'ingles',8,6,'los insanos','fkasfjasfkaskfasjfjasj');

--6.¿como insertar una transmision por partido y insertar su canal de transmision?
CREATE OR REPLACE PROCEDURE insertarTransmisioness(idMedioDeTransmision INT,nombre VARCHAR(50),idPais INT ,
												  idCanal INT,idRadio INT,idTorneo INT)
AS
$$
	BEGIN 
		RAISE NOTICE 'Insertando medios de transmisiones%', idMedioDeTransmision;
			INSERT INTO mediosDeTransmision
			VALUES (idMedioDeTransmision,nombre,idPais);
		RAISE NOTICE 'medios de transmisiones % insertado',idMedioDeTransmision;
		
		RAISE NOTICE 'Insertando canales de televesion%)',idCanal;
			INSERT INTO canalesDeTelevisiones
			VALUES (idCanal); 
		RAISE NOTICE 'canales de television % insertado',idCanal;

		RAISE NOTICE 'insertando Radios%',idRadio;
			INSERT INTO Radios
			VALUES(idRadio);
		RAISE NOTICE 'Radios de transmision  % insertado',idRadio;

		RAISE NOTICE 'insertando transmisiones del torneo %)',(idTorneo,idMedioDeTransmision);
			INSERT INTO transmisionesDelTorneo
			VALUES(idTorneo, idMedioDeTransmision);
		RAISE NOTICE 'medio de transmision por torneo % insertado)',(idTorneo,idMedioDeTransmision);
	END
$$
language 'plpgsql';
--forma de probar
CALL insertarTransmisioness(15 ,'paracol',87,15 ,15,1);
CALL insertarTransmisioness(16 ,'paracol',87,16 ,16,2);


--¿Qué partidos se han jugado en una determinada fecha y en qué pistas?
CREATE OR REPLACE FUNCTION Partidos_En_Fecha(fechaBuscar DATE) RETURNS TABLE(idPartido INT, Pista VARCHAR, Ganador VARCHAR, Perdedor VARCHAR) AS $$
BEGIN
    RETURN QUERY 
    SELECT PA.idPartido, PI.nombre AS Pista, 
           CONCAT(PG.primerNombre, ' ', PG.primerApellido)::VARCHAR(100) AS Ganador, 
           CONCAT(PP.primerNombre, ' ', PP.primerApellido)::VARCHAR(100) AS Perdedor
    FROM Partidos PA
    JOIN Pistas PI ON PA.idPista = PI.idPista
    JOIN Tenistas TG ON PA.idGanador = TG.idTenista
    JOIN Personas PG ON TG.idTenista = PG.idPersona
    JOIN Tenistas TP ON PA.idPerdedor = TP.idTenista
    JOIN Personas PP ON TP.idTenista = PP.idPersona
    WHERE PA.fecha = fechaBuscar;
END;
$$ LANGUAGE plpgsql;

SELECT * from partidos_en_fecha('2024-05-27');

--8¿Qué tenistas han ganado más de un torneo en diferentes categorías?
CREATE VIEW Tenistas_MultiCategoria_Campeones AS
SELECT P.primerNombre, P.primerApellido, COUNT(DISTINCT C.idCategoria) AS CategoriasGanadas
FROM Ganadores G
JOIN Tenistas T ON G.idTenista = T.idTenista
JOIN Personas P ON T.idTenista = P.idPersona
JOIN categoriasDelTorneo C ON G.idCategoriaModalidad = C.idCategoria
GROUP BY P.primerNombre, P.primerApellido
HAVING COUNT(DISTINCT C.idCategoria) > 1;

select *from tenistas_multicategoria_campeones;

--9. ¿Cuál es el país con más tenistas participantes en el Roland Garros 2023?
CREATE VIEW pais_con_mas_tenistas AS
SELECT P.nombre, COUNT(*) AS cantidad_tenistas
FROM Paises P
JOIN Personas ON P.idPais = Personas.idPais
JOIN tenistasEnElTorneo TET ON Personas.idPersona = TET.idTenista
WHERE TET.idTorneo = 2
GROUP BY P.nombre
ORDER BY cantidad_tenistas DESC
LIMIT 1;

Select *from pais_con_mas_tenistas;

--10.¿Cuál es la trayectoria profesional de los tenistas que han ganado más de 5 títulos en singles?

CREATE VIEW Trayectoria_Profesional_Campeones AS
SELECT CONCAT(P.primerNombre, ' ', P.primerApellido) AS NombreCompleto, TP.*
FROM titulosEFinales TF
JOIN Tenistas T ON TF.idTenista = T.idTenista
JOIN Personas P ON T.idTenista = P.idPersona
JOIN trayectoriasProfesionales TP ON T.idTenista = TP.idTenista
WHERE TF.numeroDeTitulosSiglesGanados > 5;

-- Forma de Probar
SELECT * FROM Trayectoria_Profesional_Campeones;


--11.De todos los tenistas, ¿cuáles son nombres de los tenistas con una altura mayor a 2 metros nacidos antes del año 2000?
CREATE VIEW TenistasMasAltosLongevos AS
SELECT T.altura, T.fechanacimiento, CONCAT(P.primernombre, ' ', P.primerapellido) AS NombreCompleto
FROM Tenistas T
JOIN Personas P ON T.idTenista = P.idpersona
WHERE T.altura > 200 AND T.fechanacimiento < '2000-01-01'
ORDER BY T.altura DESC;

-- Forma de Probar
SELECT * FROM TenistasMasAltosLongevos;

--12. puntaje y el nombre del tenista con menos puntaje del torneo?
CREATE VIEW TenistaMayorYTenistaMenorPuntaje AS
SELECT CONCAT(P.primernombre, ' ', P.primerapellido) AS NombreCompleto, T.puntajeranking
FROM Tenistas T
JOIN Personas P ON T.idTenista = P.idPersona
WHERE T.puntajeranking = (SELECT MAX(puntajeranking) FROM Tenistas)
UNION
SELECT CONCAT(P.primernombre, ' ', P.primerapellido) AS NombreCompleto, T.puntajeranking
FROM Tenistas T
JOIN Personas P ON T.idTenista = P.idPersona
WHERE T.puntajeranking = (SELECT MIN(puntajeranking) FROM Tenistas);

-- Forma de Probar
SELECT * FROM TenistaMayorYTenistaMenorPuntaje;

--13 ¿Cuál es el idTenista, su nombre completo, su peso y su puntaje de un país X?
CREATE OR REPLACE FUNCTION obtener_tenistas_por_pais(pais_nombre VARCHAR(50))
RETURNS TABLE (
    idTenista INT, NombreCompleto VARCHAR(100),
    peso NUMERIC, puntajeranking INT,
    Pais VARCHAR(50)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        T.idTenista, 
        CONCAT(P.primernombre, ' ', P.segundonombre, ' ', P.primerapellido, ' ', P.segundoapellido)::VARCHAR(100) AS NombreCompleto, 
        T.peso, 
        T.puntajeranking, 
        X.nombre::VARCHAR(50) AS Pais
    FROM Tenistas T
    JOIN Personas P ON T.idTenista = P.idPersona
    JOIN Paises X ON P.idPais = X.idPais
    WHERE X.nombre = pais_nombre;
END;
$$ LANGUAGE plpgsql;

--Forma de Probar
SELECT * FROM obtener_tenistas_por_pais('Belgica');
--14 ¿Cuál es la cantidad de Tenistas de un País X?
CREATE OR REPLACE FUNCTION cantidad_tenistas_por_pais(pais_nombre VARCHAR(50))
RETURNS INT AS $$
DECLARE
    cantidad INT;
BEGIN
    SELECT COUNT(T.idTenista)
    INTO cantidad
    FROM Tenistas T
    JOIN Personas P ON T.idTenista = P.idPersona
    JOIN Paises X ON P.idPais = X.idPais
    WHERE X.nombre = pais_nombre;

    RETURN cantidad;
END;
$$ LANGUAGE plpgsql;

-- Forma de Probar
SELECT cantidad_tenistas_por_pais('Belgica');

--15.¿Cuál es el idArbitro, su nombre completo, su sexo y sus años de experiencia de un país X?
CREATE OR REPLACE FUNCTION obtener_arbitros_pais(pais_nombre VARCHAR(50))
RETURNS TABLE (
    idArbitro INT,
	NombreCompleto VARCHAR(100),
    sexo VARCHAR(1), 
	experiencia INT,
    Pais VARCHAR(50)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        A.idArbitro, 
        CONCAT(P.primernombre, ' ', P.segundonombre, ' ', P.primerapellido, ' ', P.segundoapellido)::VARCHAR(100) AS NombreCompleto,
        P.sexo, 
        A.experiencia AS AñosDeExperiencia,
        X.nombre::VARCHAR(50) AS Pais
    FROM Arbitros A
    JOIN Personas P ON A.idArbitro = P.idPersona
    JOIN Paises X ON P.idPais = X.idPais
    WHERE X.nombre = pais_nombre;
END;
$$ LANGUAGE plpgsql;

-- Forma de Probar
SELECT * FROM obtener_arbitros_pais('Taipei Chino');

--16.¿como se pueden ver las noticias publicadas entre dos años?

CREATE OR REPLACE FUNCTION noticias_publicadas_en_un_rango_de_fechas(fecha_inicio DATE, fecha_fin DATE)
RETURNS TABLE (
  fecha_noticia DATE,
  hora_publicacion TIME,
  titulo_noticia VARCHAR(100)
) AS $$
BEGIN
  RETURN QUERY
  SELECT n.fechaNoticia, n.horaDePublicación, n.tituloNoticia
  FROM Noticias n
  WHERE n.fechaNoticia >= fecha_inicio AND n.fechaNoticia <= fecha_fin;
END;
$$ LANGUAGE plpgsql;

select * from noticias_publicadas_en_un_rango_de_fechas('2022-01-01', '2024-01-01');

--17. ¿Qué partidos se han jugado en una determinada fecha y en qué pistas?
CREATE OR REPLACE FUNCTION Partidos_En_Fecha(fechaBuscar DATE) RETURNS TABLE(idPartido INT, Pista VARCHAR, Ganador VARCHAR, Perdedor VARCHAR) AS $$
BEGIN
    RETURN QUERY 
    SELECT PA.idPartido, PI.nombre AS Pista, 
           CONCAT(PG.primerNombre, ' ', PG.primerApellido)::VARCHAR(100) AS Ganador, 
           CONCAT(PP.primerNombre, ' ', PP.primerApellido)::VARCHAR(100) AS Perdedor
    FROM Partidos PA
    JOIN Pistas PI ON PA.idPista = PI.idPista
    JOIN Tenistas TG ON PA.idGanador = TG.idTenista
    JOIN Personas PG ON TG.idTenista = PG.idPersona
    JOIN Tenistas TP ON PA.idPerdedor = TP.idTenista
    JOIN Personas PP ON TP.idTenista = PP.idPersona
    WHERE PA.fecha = fechaBuscar;
END;
$$ LANGUAGE plpgsql;

SELECT * from partidos_en_fecha('2024-05-27');

--18.--¿Cual es el id Y la trayecoria del tenista que mas singles ha ganado?
CREATE OR REPLACE FUNCTION tenista_con_mas_titulos_de_singles()
RETURNS TABLE(idtenista int,
			  manodejuego varchar(10),
			  fechadeiniciodecarrera DATE,
			  dinerodelpremio int,
			  partidosperdidos int,
			  partidosganados int,
			  entrenador varchar(50)
			 )AS $$
BEGIN
	RETURN QUERY
  -- Select only the 'idTenista' column
  SELECT TP.*
  FROM titulosEFinales
  INNER JOIN tenistas T ON T.idtenista = titulosEFinales.idtenista
  JOIN trayectoriasProfesionales TP ON T.idTenista = TP.idTenista
  ORDER BY numeroDeTitulosSiglesGanados DESC;
END;
$$ LANGUAGE plpgsql;

select * from tenista_con_mas_titulos_de_singles();

--19.¿Cuál es la cantidad total de dinero otorgado en premios en el Roland Garros 2024?

CREATE VIEW total_premios AS
SELECT SUM(premioMayor) AS total_premios
FROM categoriasDelTorneo
WHERE idCategoria IN (SELECT idCategoriaModalidad FROM Ganadores WHERE idTorneo = 1);

select * from total_premios;


--20¿Cuántos partidos se han jugado en 2023?

CREATE VIEW cantidad_partidos_jugados AS
SELECT COUNT(*) AS total_partidos
FROM Partidos
WHERE idTorneo = 2;