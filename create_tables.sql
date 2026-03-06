-- ================================================
-- BiblioGest 2.0 -- Creación de tablas (Oracle)
-- ================================================

CREATE TABLE SOCIOS (
    DNI      VARCHAR2(9)   PRIMARY KEY,
    Nombre   VARCHAR2(100) NOT NULL,
    Email    VARCHAR2(150) UNIQUE,
    Telefono VARCHAR2(15)
);

CREATE TABLE LIBROS (
    ISBN    VARCHAR2(13)  PRIMARY KEY,
    Titulo  VARCHAR2(200) NOT NULL,
    Autor   VARCHAR2(100),
    Paginas NUMBER(5)
);

CREATE TABLE EJEMPLARES (
    ID_Ejemplar NUMBER        PRIMARY KEY,
    ISBN        VARCHAR2(13)  NOT NULL,
    Estado      VARCHAR2(20)  DEFAULT 'Bueno',
    CONSTRAINT fk_ejemplar_libro
        FOREIGN KEY (ISBN) REFERENCES LIBROS(ISBN)
        ON DELETE CASCADE
);

CREATE TABLE PRESTAMOS (
    Socio            VARCHAR2(9) NOT NULL,
    Ejemplar         NUMBER      NOT NULL,
    Fecha            DATE        DEFAULT SYSDATE,
    Fecha_devolucion DATE,
    CONSTRAINT pk_prestamo PRIMARY KEY (Socio, Ejemplar, Fecha),
    CONSTRAINT fk_prestamo_socio
        FOREIGN KEY (Socio)    REFERENCES SOCIOS(DNI)
        ON DELETE SET NULL,
    CONSTRAINT fk_prestamo_ejemplar
        FOREIGN KEY (Ejemplar) REFERENCES EJEMPLARES(ID_Ejemplar)
        ON DELETE CASCADE
);

-- ================================================
-- Modificaciones posteriores
-- ================================================

-- Añadir columnas de auditoría a SOCIOS
ALTER TABLE SOCIOS
ADD (
    Fecha_registro    DATE      DEFAULT SYSDATE NOT NULL,
    Fecha_modificacion TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Restricción CHECK sobre el campo Estado
ALTER TABLE EJEMPLARES
ADD CONSTRAINT chk_estado
    CHECK (Estado IN ('Nuevo', 'Bueno', 'Deteriorado'));

-- Índices para optimizar búsquedas frecuentes
CREATE INDEX idx_libros_autor  ON LIBROS (Autor);
CREATE INDEX idx_libros_titulo ON LIBROS (Titulo);
