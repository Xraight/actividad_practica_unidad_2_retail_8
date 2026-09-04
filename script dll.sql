-- ==============================================================================
-- PROYECTO: DATA MART DE VENTAS - CASA&ESTILO
-- OBJETIVO: Creación de Esquema Estrella (Tablas de Dimensiones y Tabla de Hechos)
-- GRANO: Una fila = Un producto/variante dentro de una línea de detalle de orden.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. CREACIÓN DE TABLAS DE DIMENSIONES
-- ------------------------------------------------------------------------------

-- Dimensión Tiempo: Fundamental para análisis histórico y cumplimiento de entregas
CREATE TABLE Dim_Tiempo (
    fecha_sk INT PRIMARY KEY, -- Formato YYYYMMDD (ej. 20260903)
    fecha_completa DATE NOT NULL,
    anio INT NOT NULL,
    mes INT NOT NULL,
    dia INT NOT NULL,
    nombre_mes VARCHAR(20) NOT NULL,
    trimestre INT NOT NULL,
    dia_semana VARCHAR(20) NOT NULL
);

-- Dimensión Cliente: Contiene los datos descriptivos de a quién se le vende
CREATE TABLE Dim_Cliente (
    cliente_sk SERIAL PRIMARY KEY,
    cliente_id_bk INT NOT NULL, -- BK: Business Key (ID del sistema origen)
    nombre VARCHAR(150) NOT NULL,
    tipo_cliente VARCHAR(50) NOT NULL, -- Consumidor final, diseñador, etc.
    ciudad VARCHAR(100),
    zona VARCHAR(100)
);

-- Dimensión Producto: Desnormaliza (une) las tablas operacionales PRODUCTOS y VARIANTES
CREATE TABLE Dim_Producto (
    producto_sk SERIAL PRIMARY KEY,
    variante_id_bk INT NOT NULL, -- El grano base operacional
    producto_id_bk INT NOT NULL,
    nombre_producto VARCHAR(150) NOT NULL,
    categoria VARCHAR(100),
    coleccion VARCHAR(100),
    marca VARCHAR(100),
    color VARCHAR(50),
    material VARCHAR(50),
    tamano VARCHAR(50)
);

-- Dimensión Showroom: Información del punto de venta físico
CREATE TABLE Dim_Showroom (
    showroom_sk SERIAL PRIMARY KEY,
    showroom_id_bk INT NOT NULL,
    nombre_showroom VARCHAR(100) NOT NULL,
    ciudad VARCHAR(100),
    zona VARCHAR(100)
);

-- Dimensión Asesor: Permite calcular comisiones y rendimiento del personal
CREATE TABLE Dim_Asesor (
    asesor_sk SERIAL PRIMARY KEY,
    asesor_id_bk INT NOT NULL,
    nombre_asesor VARCHAR(150) NOT NULL,
    porcentaje_comision NUMERIC(5,2) -- Ejemplo: 5.00 para 5%
);

-- Dimensión Canal: Separa si fue e-commerce, showroom, pedido especial, etc.
CREATE TABLE Dim_Canal (
    canal_sk SERIAL PRIMARY KEY,
    nombre_canal VARCHAR(50) NOT NULL
);

-- ------------------------------------------------------------------------------
-- 2. CREACIÓN DE LA TABLA DE HECHOS (FACT TABLE)
-- ------------------------------------------------------------------------------

CREATE TABLE Fact_Ventas (
    fact_venta_id SERIAL PRIMARY KEY,
    
    -- Claves Foráneas a las Dimensiones (Contexto del evento)
    fecha_orden_sk INT NOT NULL REFERENCES Dim_Tiempo(fecha_sk),
    fecha_prometida_sk INT REFERENCES Dim_Tiempo(fecha_sk), -- Maneja logística
    fecha_real_entrega_sk INT REFERENCES Dim_Tiempo(fecha_sk), -- Maneja logística
    cliente_sk INT NOT NULL REFERENCES Dim_Cliente(cliente_sk),
    producto_sk INT NOT NULL REFERENCES Dim_Producto(producto_sk),
    showroom_sk INT NOT NULL REFERENCES Dim_Showroom(showroom_sk),
    asesor_sk INT NOT NULL REFERENCES Dim_Asesor(asesor_sk),
    canal_sk INT NOT NULL REFERENCES Dim_Canal(canal_sk),

    -- Dimensión Degenerada (Datos transaccionales útiles que no requieren dimensión propia)
    orden_id VARCHAR(50) NOT NULL,
    tipo_surtido VARCHAR(50), -- Stock o sobre pedido

    -- MÉTRICAS ADITIVAS BASE (A nivel línea de orden)
    cantidad INT NOT NULL,
    precio_unitario NUMERIC(10,2) NOT NULL,
    costo_unitario NUMERIC(10,2) NOT NULL,
    monto_subtotal NUMERIC(10,2) NOT NULL, -- cantidad * precio_unitario
    monto_costo_total NUMERIC(10,2) NOT NULL, -- cantidad * costo_unitario
    
    -- MÉTRICAS PRORRATEADAS (Calculadas antes de insertar usando la fórmula del documento)
    monto_descuento_prorrateado NUMERIC(10,2) DEFAULT 0,
    monto_envio_prorrateado NUMERIC(10,2) DEFAULT 0,

    -- MÉTRICAS DERIVADAS RECALCULADAS
    monto_venta_neta NUMERIC(10,2) NOT NULL, -- monto_subtotal - descuento_prorrateado
    ganancia_bruta NUMERIC(10,2) NOT NULL,   -- monto_venta_neta - monto_costo_total
    
    -- MÉTRICAS LOGÍSTICAS Y DE CUMPLIMIENTO (Resuelven la restricción del caso)
    dias_para_entrega INT, -- Diferencia entre fecha_real y fecha_orden
    retraso_dias INT -- Diferencia entre fecha_real y fecha_prometida (>0 significa retraso)
);

-- ------------------------------------------------------------------------------
-- 3. CREACIÓN DE ÍNDICES PARA OPTIMIZACIÓN DE CONSULTAS
-- ------------------------------------------------------------------------------
-- Se crean índices en las llaves foráneas de la tabla de hechos para acelerar los JOINs y agrupaciones.
CREATE INDEX idx_fact_fecha ON Fact_Ventas(fecha_orden_sk);
CREATE INDEX idx_fact_cliente ON Fact_Ventas(cliente_sk);
CREATE INDEX idx_fact_producto ON Fact_Ventas(producto_sk);
CREATE INDEX idx_fact_showroom ON Fact_Ventas(showroom_sk);