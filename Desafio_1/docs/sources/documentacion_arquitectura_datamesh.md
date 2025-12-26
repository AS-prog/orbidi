# Arquitectura Data Mesh - Documento de Diseño

**Cliente:** Orbidi  
**Fecha:** Diciembre 2024  
**Autor:** Andrés R. Sotelo
**Versión:** 2.0

---

## 1. Resumen Ejecutivo

Este documento presenta el diseño de una plataforma de datos moderna basada en el paradigma **Data Mesh** con **arquitectura Medallion** (Bronze/Silver/Gold) para un cliente de Orbidi. La solución integra múltiples fuentes de datos heterogéneas y habilita capacidades de Business Intelligence y Machine Learning, cumpliendo con los requisitos de:

- Hosting en **Google Cloud Platform**
- Priorización de tecnologías **open-source**
- Enfoque fuerte en **GitOps y DataOps**
- Arquitectura **Data Mesh** con gobernanza federada
- **Dominio Maisons** como proyecto principal con datasets por capas

---

## 2. Contexto y Problemática

### 2.1 Situación Actual del Cliente

El cliente opera con múltiples sistemas desconectados:

| Tipo | Sistemas |
|------|----------|
| Bases de datos transaccionales | PostgreSQL, MySQL, MongoDB |
| Aplicaciones SaaS | SAP, Salesforce, SurveyMonkey |

### 2.2 Objetivos del Proyecto

1. **Consolidar** todas las fuentes de datos en una plataforma unificada
2. **Habilitar** tableros de BI para diversos departamentos
3. **Desarrollar** modelos de ML para recomendaciones y predicciones
4. **Establecer** gobernanza de datos federada
5. **Garantizar** extensibilidad para futuros productos de datos

---

## 3. Arquitectura Propuesta

### 3.1 Visión General

La arquitectura se organiza en **6 capas** que siguen el flujo de datos desde las fuentes hasta el consumo:

```
┌─────────────────────────────────────────────────────────────────┐
│                    CAPA 6: CONSUMO                              │
│         (Superset, Vertex AI, Cloud Run APIs)                   │
├─────────────────────────────────────────────────────────────────┤
│                 CAPA 5: GOBERNANZA FEDERADA                     │
│    (IAM, DataHub, Great Expectations, Cloud Monitoring)         │
├─────────────────────────────────────────────────────────────────┤
│              CAPA 4: DOMINIO MAISONS (BigQuery)                 │
│     🥉 Bronze → 🥈 Silver → 🥇 Gold (por entidad)                │
├─────────────────────────────────────────────────────────────────┤
│               CAPA 3: PLATAFORMA CENTRAL                        │
│          (Airbyte, Cloud Composer, GCS Data Lake)               │
├─────────────────────────────────────────────────────────────────┤
│                 CAPA 2: GitOps & DataOps                        │
│           (GitHub, Cloud Build, Terraform)                      │
├─────────────────────────────────────────────────────────────────┤
│                 CAPA 1: FUENTES DE DATOS                        │
│    (PostgreSQL, MySQL, MongoDB, SAP, Salesforce, SurveyMonkey)  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Descripción de Capas

#### Capa 1: Fuentes de Datos

Sistemas origen que alimentan la plataforma:

| Fuente | Tipo | Protocolo de Extracción |
|--------|------|------------------------|
| PostgreSQL | RDBMS | CDC (Change Data Capture) / Bulk |
| MySQL | RDBMS | CDC / Bulk |
| MongoDB | NoSQL Document | Change Streams / Bulk |
| SAP | ERP | API / RFC |
| Salesforce | CRM SaaS | REST API |
| SurveyMonkey | Survey SaaS | REST API |

#### Capa 2: GitOps & DataOps

| Componente | Herramienta | Función |
|------------|-------------|---------|
| Control de versiones | GitHub / GitLab | Versionado de código, dbt projects, IaC |
| CI/CD | Cloud Build / GitHub Actions | Testing, validación, despliegue automático |
| Infraestructura como Código | Terraform | Provisión de todos los recursos GCP |

**Flujo GitOps:**
```
Developer → PR → Code Review → Merge → CI/CD Pipeline → Deploy
```

#### Capa 3: Plataforma Central (GCP)

| Componente | Tecnología | Justificación |
|------------|------------|---------------|
| **Ingesta** | Airbyte (en GKE) | Open-source, +300 conectores, extensible |
| **Orquestación** | Cloud Composer (Airflow) | Servicio gestionado, integración nativa GCP |
| **Data Lake** | GCS Buckets | Almacenamiento escalable, formato Parquet/Delta |

#### Capa 4: Dominio Maisons (Arquitectura Medallion)

El dominio **Maisons** es el proyecto GCP principal que contiene todos los datos organizados en la arquitectura Medallion:

```
📁 Proyecto GCP: maisons-data-platform
│
├── 🥉 Dataset: bronze (Raw Data)
│   ├── raw_clientes          ← Datos crudos de Salesforce
│   ├── raw_productos         ← Datos crudos de SAP
│   ├── raw_ventas            ← Datos crudos de PostgreSQL
│   ├── raw_surveys           ← Datos crudos de SurveyMonkey
│   └── raw_[nuevas_fuentes]  ← Extensible
│
├── 🥈 Dataset: silver (Cleaned & Conformed)
│   ├── stg_clientes          ← Limpieza, tipado, deduplicación
│   ├── stg_productos         ← Normalización, validaciones
│   ├── stg_ventas            ← Joins básicos, filtros
│   ├── stg_surveys           ← Parsing de respuestas
│   └── int_[intermedios]     ← Modelos intermedios compartidos
│
└── 🥇 Datasets Gold (Marts por Entidad)
    │
    ├── 📊 Dataset: gold_clientes
    │   ├── dim_clientes          ← Dimensión cliente
    │   ├── mart_clientes_360     ← Vista 360 del cliente
    │   └── fct_interacciones     ← Hechos de interacciones
    │
    ├── 📊 Dataset: gold_productos
    │   ├── dim_productos         ← Dimensión producto
    │   ├── mart_catalogo         ← Catálogo enriquecido
    │   └── fct_inventario        ← Hechos de inventario
    │
    ├── 📊 Dataset: gold_ventas
    │   ├── fct_transacciones     ← Hechos de ventas
    │   ├── agg_ventas_diarias    ← Agregaciones diarias
    │   └── mart_performance      ← KPIs de ventas
    │
    └── 📊 Dataset: gold_[extensible]
        └── mart_[nuevo]          ← Futuros marts
```

##### Arquitectura Medallion (Bronze → Silver → Gold)

| Capa | Dataset | Propósito | Transformaciones | Acceso |
|------|---------|-----------|------------------|--------|
| **🥉 Bronze** | `bronze` | Datos crudos, inmutables | Ninguna (1:1 con fuente) | Solo ingesta |
| **🥈 Silver** | `silver` | Datos limpios, conformados | Tipado, dedup, validación | Equipo Data |
| **🥇 Gold** | `gold_*` | Marts de negocio | Joins, agregaciones, KPIs | BI, ML, APIs |

##### Estructura dbt

```
dbt_project_maisons/
├── dbt_project.yml
├── models/
│   ├── staging/                    → Dataset: bronze
│   │   ├── _staging__sources.yml
│   │   ├── stg_clientes.sql
│   │   ├── stg_productos.sql
│   │   ├── stg_ventas.sql
│   │   └── stg_surveys.sql
│   │
│   ├── intermediate/               → Dataset: silver
│   │   ├── int_clientes_enriched.sql
│   │   ├── int_productos_inventory.sql
│   │   └── int_ventas_joined.sql
│   │
│   └── marts/                      → Datasets: gold_*
│       ├── clientes/               → gold_clientes
│       │   ├── dim_clientes.sql
│       │   ├── mart_clientes_360.sql
│       │   └── fct_interacciones.sql
│       │
│       ├── productos/              → gold_productos
│       │   ├── dim_productos.sql
│       │   ├── mart_catalogo.sql
│       │   └── fct_inventario.sql
│       │
│       └── ventas/                 → gold_ventas
│           ├── fct_transacciones.sql
│           ├── agg_ventas_diarias.sql
│           └── mart_performance.sql
│
├── tests/
│   ├── generic/
│   └── singular/
│
└── macros/
```

#### Capa 5: Gobernanza Federada

| Pilar | Componente | Función |
|-------|------------|---------|
| **Control de Acceso** | Cloud IAM | Roles y políticas a nivel proyecto/dataset |
| | Column-Level Security | Restricción de columnas sensibles (PII) en Gold |
| **Catalogación** | DataHub | Catálogo central, linaje automático desde dbt |
| **Calidad de Datos** | Great Expectations | Validaciones de schema y datos en Gold |
| | dbt Tests | Tests integrados en cada capa |
| **Observabilidad** | Cloud Monitoring | Métricas de pipelines, logs centralizados |
| | Cloud Alerting + Slack/PagerDuty | Notificaciones proactivas |

#### Capa 6: Consumo

| Caso de Uso | Herramienta | Datasets Accesibles |
|-------------|-------------|---------------------|
| **BI / Dashboards** | Apache Superset | `gold_*` únicamente |
| **ML / Predicciones** | Vertex AI | `gold_*` + `silver` (features) |
| **APIs de Datos** | Cloud Run / Cloud Functions | `gold_*` únicamente |

---

## 4. Decisiones de Arquitectura (ADRs)

### ADR-001: Airbyte sobre Fivetran para Ingesta

**Contexto:** Se requiere una herramienta de EL (Extract-Load) con múltiples conectores.

**Decisión:** Airbyte desplegado en GKE.

**Justificación:**
- ✅ Open-source (requisito del cliente)
- ✅ +300 conectores pre-construidos
- ✅ Extensible mediante Connector Builder
- ✅ Desplegable en Kubernetes (control total)
- ❌ Fivetran: SaaS propietario, costos por volumen

**Consecuencias:**
- Mayor control y personalización
- Requiere gestión del cluster GKE
- Posibilidad de contribuir conectores custom

---

### ADR-002: Cloud Composer sobre Airflow self-managed

**Contexto:** Se necesita orquestación de pipelines de datos.

**Decisión:** Cloud Composer (Airflow gestionado).

**Justificación:**
- ✅ Airflow es open-source (satisface requisito)
- ✅ Servicio gestionado reduce overhead operacional
- ✅ Integración nativa con GCS, BigQuery, Dataflow
- ✅ Auto-scaling, alta disponibilidad incluida

**Consecuencias:**
- Menor control que self-managed
- Costo fijo del servicio gestionado
- Actualizaciones gestionadas por Google

---

### ADR-003: Arquitectura Medallion (Bronze/Silver/Gold)

**Contexto:** Se necesita una estructura de datos que permita trazabilidad, reprocesamiento y separación de concerns.

**Decisión:** Implementar arquitectura Medallion con datasets separados por capa.

**Justificación:**
- ✅ **Bronze:** Preserva datos crudos para auditoría y reprocesamiento
- ✅ **Silver:** Centraliza lógica de limpieza, evita duplicación
- ✅ **Gold:** Marts optimizados para consumo, separados por entidad
- ✅ Control de acceso granular por capa
- ✅ Patrón probado en la industria (Databricks, Delta Lake)

**Consecuencias:**
- Mayor almacenamiento (datos en múltiples capas)
- Latencia adicional por transformaciones en capas
- Claridad en ownership y responsabilidades

---

### ADR-004: Datasets Gold Separados por Entidad

**Contexto:** Los marts de negocio deben servir a diferentes equipos y casos de uso.

**Decisión:** Crear un dataset `gold_*` por cada entidad de negocio (clientes, productos, ventas, etc.).

**Justificación:**
- ✅ **Control de acceso granular:** Equipo de ventas solo accede a `gold_ventas`
- ✅ **Escalabilidad:** Nuevas entidades = nuevos datasets sin afectar existentes
- ✅ **Ownership claro:** Cada dataset tiene un owner definido
- ✅ **Costos controlados:** Queries solo escanean datasets necesarios

**Consecuencias:**
- Más datasets que administrar
- Requiere convención de nombres estricta
- Cross-domain queries requieren permisos explícitos

---

### ADR-005: DataHub sobre Google Data Catalog

**Contexto:** Se requiere catalogación de datos con linaje.

**Decisión:** DataHub open-source.

**Justificación:**
- ✅ Open-source (requisito del cliente)
- ✅ Linaje automático desde dbt (manifest.json)
- ✅ API extensible para integraciones custom
- ✅ UI moderna para discovery
- ❌ Data Catalog: Menos features, no open-source

**Consecuencias:**
- Requiere despliegue y mantenimiento
- Comunidad activa (LinkedIn backed)

---

### ADR-006: Apache Superset sobre Looker/Tableau

**Contexto:** Se necesitan dashboards de BI self-service.

**Decisión:** Apache Superset.

**Justificación:**
- ✅ Open-source (requisito del cliente)
- ✅ SQL Lab para exploración ad-hoc
- ✅ Conector nativo BigQuery
- ✅ Role-based access control
- ❌ Looker: Propietario, costo elevado

**Consecuencias:**
- Menor polish que herramientas enterprise
- Requiere capacitación de usuarios

---

## 5. Data Mesh: Principios Aplicados

### 5.1 Los 4 Principios de Data Mesh

| Principio | Implementación |
|-----------|----------------|
| **Domain Ownership** | Dominio Maisons es owner del proyecto GCP completo. Cada dataset Gold tiene un equipo responsable. |
| **Data as a Product** | Los `mart_*` en Gold son productos de datos con SLAs, documentación en dbt, y ownership claro |
| **Self-serve Platform** | Plataforma central (Airbyte, Composer, GCS) provee ingesta y orquestación como servicio |
| **Federated Governance** | Políticas centrales (IAM, calidad) aplicadas consistentemente en todas las capas |

### 5.2 Estructura de un Data Product (Gold)

Cada mart en Gold se expone como producto de datos con:

```yaml
# Ejemplo: Data Product "mart_clientes_360"
name: mart_clientes_360
domain: maisons
dataset: gold_clientes
owner: equipo-clientes@empresa.com
description: Vista unificada del cliente con todas sus interacciones
sla:
  freshness: "< 4 horas"
  availability: "99.9%"
schema:
  - cliente_id (PK)
  - nombre
  - email (PII - restricted)
  - ltv_score
  - segmento
  - ultima_compra_fecha
  - total_compras
quality_checks:
  - not_null: [cliente_id, nombre]
  - unique: [cliente_id]
  - accepted_values: [segmento, ['premium', 'standard', 'basic']]
  - relationships: [cliente_id → dim_clientes.cliente_id]
```

---

## 6. Seguridad y Gobernanza

### 6.1 Modelo de Acceso (IAM) por Capa

```
┌─────────────────────────────────────────────────────────────────┐
│              Proyecto GCP: maisons-data-platform                │
├─────────────────────────────────────────────────────────────────┤
│  Dataset: bronze                                                │
│  └── Acceso: Solo Service Account de Airbyte (escritura)        │
│              Solo equipo Data Engineering (lectura)             │
├─────────────────────────────────────────────────────────────────┤
│  Dataset: silver                                                │
│  └── Acceso: Equipo Data Engineering (lectura/escritura)        │
│              Data Scientists (lectura para features)            │
├─────────────────────────────────────────────────────────────────┤
│  Datasets: gold_*                                               │
│  ├── gold_clientes → Equipo Clientes + Analistas BI             │
│  ├── gold_productos → Equipo Productos + Analistas BI           │
│  ├── gold_ventas → Equipo Ventas + Analistas BI                 │
│  └── Column-Level Security en columnas PII                      │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Clasificación de Datos por Capa

| Capa | Clasificación | Ejemplos | Acceso |
|------|---------------|----------|--------|
| **Bronze** | Interno | Datos crudos de todas las fuentes | Solo ingesta y data eng |
| **Silver** | Interno | Datos limpios y conformados | Data team |
| **Gold** | Variable | Marts de negocio | Por dataset y columna |

### 6.3 Column-Level Security (Solo en Gold)

```sql
-- Crear taxonomy para PII
CREATE SCHEMA IF NOT EXISTS `maisons-data-platform.taxonomy`;

-- Crear policy tag
CREATE POLICY TAG `maisons-data-platform.taxonomy.pii`
  DESCRIPTION 'Información Personal Identificable';

-- Aplicar a columnas sensibles en gold_clientes
ALTER TABLE `gold_clientes.mart_clientes_360`
ALTER COLUMN email SET POLICY TAG `maisons-data-platform.taxonomy.pii`;

ALTER TABLE `gold_clientes.dim_clientes`
ALTER COLUMN telefono SET POLICY TAG `maisons-data-platform.taxonomy.pii`;

-- Solo usuarios con rol específico pueden ver PII
GRANT `roles/datacatalog.fineGrainedReader`
ON POLICY TAG `maisons-data-platform.taxonomy.pii`
TO 'grupo-acceso-pii@empresa.com';
```

---

## 7. Calidad de Datos por Capa

### 7.1 Estrategia de Testing

| Capa | Herramienta | Tipos de Tests | Ejemplo |
|------|-------------|----------------|---------|
| **Bronze** | dbt tests | Schema, freshness | `source_freshness`, tipos correctos |
| **Silver** | dbt tests | Uniqueness, not null, relationships | PK unique, FK válidas |
| **Gold** | dbt + Great Expectations | Reglas de negocio, distribuciones | `ltv_score BETWEEN 0 AND 100` |

### 7.2 Ejemplos de Tests dbt

```yaml
# models/staging/_staging__sources.yml
sources:
  - name: bronze
    database: maisons-data-platform
    schema: bronze
    freshness:
      warn_after: {count: 12, period: hour}
      error_after: {count: 24, period: hour}
    tables:
      - name: raw_clientes
        columns:
          - name: id
            tests:
              - not_null
              - unique

# models/marts/clientes/_clientes__models.yml
models:
  - name: mart_clientes_360
    description: "Vista 360 del cliente"
    columns:
      - name: cliente_id
        tests:
          - not_null
          - unique
      - name: segmento
        tests:
          - accepted_values:
              values: ['premium', 'standard', 'basic']
      - name: ltv_score
        tests:
          - dbt_utils.accepted_range:
              min_value: 0
              max_value: 100
```

---

## 8. Observabilidad y Monitoreo

### 8.1 Métricas Clave por Capa

| Capa | Métrica | Alerta |
|------|---------|--------|
| **Ingesta** | Registros cargados en Bronze/hora | < umbral esperado |
| **Ingesta** | Latencia de replicación | > 1 hora |
| **Bronze → Silver** | Duración de jobs dbt staging | > 2x promedio |
| **Silver → Gold** | Duración de jobs dbt marts | > 2x promedio |
| **Calidad** | Tests fallidos (cualquier capa) | Cualquier fallo |
| **Consumo** | Queries lentas en Gold | > 60 segundos |

### 8.2 Stack de Observabilidad

```
Airbyte/Airflow → Cloud Monitoring → Cloud Alerting → Slack/PagerDuty
       ↓
   Cloud Logging → Log-based Metrics → Dashboards
       ↓
   DataHub → Linaje visual → Impact Analysis
```

---

## 9. Plan de Extensibilidad

### 9.1 Agregar Nueva Entidad en Gold

1. **dbt:** Crear carpeta `models/marts/[nueva_entidad]/`
2. **Terraform:** Crear dataset `gold_[nueva_entidad]`
3. **IAM:** Definir roles y permisos para el nuevo dataset
4. **DataHub:** Se actualiza automáticamente desde dbt manifest
5. **Tests:** Agregar tests de calidad específicos

**Tiempo estimado:** 1-2 días

### 9.2 Agregar Nueva Fuente de Datos

1. **Airbyte:** Configurar conector
2. **GCS:** Se usa bucket existente (particionado por fuente)
3. **dbt Bronze:** Crear modelo `stg_[nueva_fuente].sql`
4. **dbt Silver:** Agregar a modelos intermedios si aplica
5. **Tests:** Agregar freshness y schema tests

**Tiempo estimado:** 1-2 días para conector existente

### 9.3 Agregar Nuevo Proyecto (Multi-dominio futuro)

Si en el futuro se requieren dominios adicionales fuera de Maisons:

1. **Terraform:** Crear nuevo proyecto GCP
2. **Replicar:** Estructura Bronze/Silver/Gold
3. **Cross-project:** Configurar authorized views si se requiere compartir datos
4. **DataHub:** Registrar nuevo dominio

**Tiempo estimado:** 1-2 semanas

---

## 10. Estimación de Costos (Referencial)

| Componente | Servicio GCP | Costo Mensual Estimado |
|------------|--------------|------------------------|
| Ingesta | GKE (Airbyte) | $200 - $500 |
| Orquestación | Cloud Composer | $300 - $800 |
| Almacenamiento Bronze | BigQuery Storage | $50 - $150 |
| Almacenamiento Silver | BigQuery Storage | $30 - $100 |
| Almacenamiento Gold | BigQuery Storage | $20 - $80 |
| Procesamiento | BigQuery Compute | $200 - $1,000 |
| Data Lake | GCS | $20 - $50 |
| ML | Vertex AI | $100 - $500 |
| Monitoreo | Cloud Monitoring | $50 - $100 |
| **Total Estimado** | | **$970 - $3,280/mes** |

*Nota: Costos varían según volumen de datos y frecuencia de procesamiento.*

---

## 11. Riesgos y Mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Complejidad de Airbyte self-managed | Media | Alto | Runbooks, capacitación, considerar Airbyte Cloud |
| Datos duplicados entre capas | Media | Medio | Lifecycle policies, partitioning por fecha |
| Costos BigQuery no controlados | Media | Alto | Quotas, slot reservations, monitoreo |
| Calidad de datos en fuentes | Alta | Alto | Validaciones en Bronze, alertas tempranas |
| Latencia Bronze→Gold elevada | Baja | Medio | Incremental models, paralelización |

---

## 12. Próximos Pasos

1. **Fase 1 (Semanas 1-4):** Infraestructura base con Terraform
   - Proyecto GCP Maisons
   - Datasets bronze, silver, gold_clientes
   - Cloud Composer, GKE para Airbyte

2. **Fase 2 (Semanas 5-8):** Ingesta de primeras fuentes
   - Configurar Airbyte (PostgreSQL, Salesforce)
   - Modelos dbt Bronze y Silver

3. **Fase 3 (Semanas 9-12):** Primer dataset Gold completo
   - `gold_clientes` con mart_clientes_360
   - Tests de calidad, documentación
   - Conexión con Superset

4. **Fase 4 (Semanas 13-16):** Datasets Gold adicionales
   - `gold_productos`, `gold_ventas`
   - DataHub para catalogación

5. **Fase 5 (Semanas 17-20):** ML y optimización
   - Vertex AI Feature Store
   - Optimización de costos y performance

---

## Anexo A: Tecnologías Utilizadas

| Categoría | Tecnología | Licencia | Versión Recomendada |
|-----------|------------|----------|---------------------|
| Ingesta | Airbyte | Open Source (MIT) | 0.50+ |
| Orquestación | Apache Airflow | Apache 2.0 | 2.7+ |
| Transformación | dbt Core | Apache 2.0 | 1.7+ |
| Data Warehouse | BigQuery | Propietario (GCP) | N/A |
| Catálogo | DataHub | Apache 2.0 | 0.12+ |
| Calidad | Great Expectations | Apache 2.0 | 0.18+ |
| BI | Apache Superset | Apache 2.0 | 3.0+ |
| ML Platform | Vertex AI | Propietario (GCP) | N/A |
| IaC | Terraform | MPL 2.0 | 1.6+ |

---

## Anexo B: Convenciones de Nomenclatura

### Datasets BigQuery

| Capa | Patrón | Ejemplo |
|------|--------|---------|
| Bronze | `bronze` | `bronze` |
| Silver | `silver` | `silver` |
| Gold | `gold_[entidad]` | `gold_clientes`, `gold_productos` |

### Tablas/Vistas

| Capa | Prefijo | Ejemplo |
|------|---------|---------|
| Bronze | `raw_` | `raw_clientes`, `raw_ventas` |
| Silver | `stg_` / `int_` | `stg_clientes`, `int_ventas_enriched` |
| Gold | `dim_` / `fct_` / `mart_` / `agg_` | `dim_clientes`, `fct_ventas`, `mart_clientes_360` |

---

## Anexo C: Referencias

- [Data Mesh Principles - Zhamak Dehghani](https://martinfowler.com/articles/data-mesh-principles.html)
- [Medallion Architecture - Databricks](https://www.databricks.com/glossary/medallion-architecture)
- [Airbyte Documentation](https://docs.airbyte.com/)
- [dbt Best Practices](https://docs.getdbt.com/guides/best-practices)
- [DataHub Architecture](https://datahubproject.io/docs/architecture/architecture)
- [BigQuery Best Practices](https://cloud.google.com/bigquery/docs/best-practices-performance-overview)
