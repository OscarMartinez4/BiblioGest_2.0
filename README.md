# BiblioGest 2.0 — Diseño Físico e Implementación Oracle

Sistema de gestión del inventario físico de una biblioteca implementado en Oracle. Este repositorio contiene el esquema relacional completo, objetos de base de datos (vistas, índices, tablespaces) y la gestión de usuarios y privilegios.

---

## Esquema relacional

```
SOCIOS    (DNI, Nombre, Email, Telefono)
LIBROS    (ISBN, Titulo, Autor, Paginas)
EJEMPLARES(ID_Ejemplar, ISBN*, Estado)          FK -> LIBROS
PRESTAMOS (Socio*, Ejemplar*, Fecha)            FK -> SOCIOS, EJEMPLARES
```

---

## Archivos SQL

| Archivo | Descripción |
|---|---|
| `create_tables.sql` | Creación de tablas, claves, restricciones, índices y modificaciones ALTER TABLE |

---

## Tarea 1: Definición de estructura y tipos de datos

### 1.1 Creación del esquema relacional

Tablas con claves primarias, foráneas y opciones de borrado:

```sql
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
```

### 1.2 Tipos de datos: DATE vs TIMESTAMP, CHAR vs VARCHAR2

Añadir columnas de auditoría a SOCIOS:

```sql
ALTER TABLE SOCIOS
ADD (
    Fecha_registro     DATE      DEFAULT SYSDATE NOT NULL,
    Fecha_modificacion TIMESTAMP DEFAULT SYSTIMESTAMP
);
```

**Comparativa DATE vs TIMESTAMP:**

| Característica | DATE | TIMESTAMP |
|---|---|---|
| Precisión | Año, mes, día, hora, min, seg | Añade fracciones de segundo (hasta 9 dígitos) |
| Zona horaria | No | `TIMESTAMP WITH TIME ZONE` puede incluirla |
| Uso habitual | Fechas de negocio | Auditoría, logs, eventos técnicos precisos |
| Almacenamiento | 7 bytes | 11 bytes (con zona horaria) |

**Comparativa CHAR vs VARCHAR2:**

| Característica | CHAR(n) | VARCHAR2(n) |
|---|---|---|
| Longitud | Fija: siempre ocupa n bytes (rellena con espacios) | Variable: ocupa solo lo necesario |
| Uso idóneo | DNI, códigos postales (longitud siempre igual) | Nombres, textos de longitud variable |

### 1.3 Restricciones CHECK y clave candidata

```sql
-- CHECK sobre el campo Estado
ALTER TABLE EJEMPLARES
ADD CONSTRAINT chk_estado
    CHECK (Estado IN ('Nuevo', 'Bueno', 'Deteriorado'));

-- Email como clave candidata (UNIQUE)
-- Nota: si Email ya se definió UNIQUE en el CREATE TABLE, esta sentencia
-- dará error ORA-02261 (unique constraint already exists).
ALTER TABLE SOCIOS
ADD CONSTRAINT uq_email UNIQUE (Email);
```

---

## Tarea 2: Objetos de la base de datos y optimización

### 2.1 Vista VISTA_PRESTAMOS_ACTIVOS

Muestra los préstamos sin fecha de devolución (ejemplares todavía prestados):

```sql
CREATE OR REPLACE VIEW VISTA_PRESTAMOS_ACTIVOS AS
SELECT
    l.Titulo      AS titulo_libro,
    e.ID_Ejemplar AS id_ejemplar,
    s.Nombre      AS nombre_socio
FROM PRESTAMOS p
INNER JOIN SOCIOS     s ON p.Socio    = s.DNI
INNER JOIN EJEMPLARES e ON p.Ejemplar = e.ID_Ejemplar
INNER JOIN LIBROS     l ON e.ISBN     = l.ISBN
WHERE p.Fecha_devolucion IS NULL;
```

### 2.2 Índices sobre la tabla LIBROS

```sql
-- Índice para búsquedas frecuentes por Autor
CREATE INDEX idx_libros_autor  ON LIBROS (Autor);

-- Índice para búsquedas por Titulo
CREATE INDEX idx_libros_titulo ON LIBROS (Titulo);
```

Sin índices Oracle realiza un **Full Table Scan** recorriendo todos los bloques. Con un índice B-tree sobre `Autor` o `Titulo`, el motor ejecuta un **Index Range Scan** navegando el árbol en O(log n).

### 2.3 TABLESPACE en Oracle

Un TABLESPACE es la unidad lógica de almacenamiento en Oracle. Agrupa uno o varios datafiles del sistema operativo y determina dónde se almacenan físicamente los objetos de la base de datos.

Ventajas de separar datos e índices en tablespaces distintos: rendimiento de I/O en discos físicos distintos, administración y backup independientes, monitorización del crecimiento por tipo de objeto y aplicación de cuotas diferenciadas.

```sql
-- Crear tablespaces separados
CREATE TABLESPACE tbs_datos
    DATAFILE '/u01/oradata/bibliogest/datos01.dbf' SIZE 100M AUTOEXTEND ON;

CREATE TABLESPACE tbs_indices
    DATAFILE '/u01/oradata/bibliogest/idx01.dbf'   SIZE  50M AUTOEXTEND ON;
```

---

## Tarea 3: Administración y herramientas

### 3.1 Gestión de seguridad y privilegios

```sql
-- 1. Usuario super_admin con todos los privilegios
CREATE USER super_admin IDENTIFIED BY Admin2024#
    DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;
GRANT DBA TO super_admin;  -- incluye todos los privilegios del sistema

-- 2. Usuario tecnico_inventario
CREATE USER tecnico_inventario IDENTIFIED BY Tecnico2024#
    DEFAULT TABLESPACE users QUOTA 20M ON users;
GRANT CREATE SESSION TO tecnico_inventario;

-- 3. Permisos de consulta y actualización sobre EJEMPLARES
GRANT SELECT, UPDATE ON bibliogest.EJEMPLARES TO tecnico_inventario;

-- 4. Revocar el permiso de actualización
REVOKE UPDATE ON bibliogest.EJEMPLARES FROM tecnico_inventario;

-- 5. Eliminar el usuario del sistema
DROP USER tecnico_inventario CASCADE;
-- CASCADE elimina todos los objetos de su schema antes de borrar el usuario
```

### 3.2 Conexión a la consola CLI

**MySQL — cliente `mysql`:**

```bash
# Conexión básica
mysql -u root -p

# Conexión a una base de datos concreta con host y puerto
mysql -h localhost -P 3306 -u super_admin -p bibliogest
```

**Oracle — cliente `sqlplus`:**

```bash
# Conexión como usuario normal
sqlplus super_admin/Admin2024#@localhost:1521/XE

# Conexión como SYSDBA (administración)
sqlplus sys/syspassword@localhost:1521/XE AS SYSDBA

# Conexión local sin red
sqlplus / AS SYSDBA
```

### 3.3 Identificación de herramientas

| Herramienta | CLI | Web | Escritorio (GUI) | Multi-extensión | Nativo MySQL | Nativo Oracle |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| MySQL Workbench | | | ✓ | ✓ | ✓ | |
| phpMyAdmin | | ✓ | | | ✓ | |
| SQL Developer | | | ✓ | | | ✓ |
| Visual Studio Code | | | ✓ | ✓ | | |
| mysql / sqlplus | ✓ | | | | ✓ | ✓ |

---

## Requisitos

- Oracle Database (probado con Oracle XE)
- SQL Developer o sqlplus
