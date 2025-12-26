# Propuesta de Arquitectura de Datos
## Solución Data Mesh para Plataforma Analítica Unificada

**Preparado para:** Cliente Orbidi  
**Fecha:** Diciembre 2024  
**Versión:** 1.0

---

## 1. Resumen Ejecutivo

Esta propuesta presenta una **plataforma de datos moderna** diseñada para transformar la capacidad analítica de su organización. La solución integra sus 6 fuentes de datos actuales en una arquitectura unificada que permite:

- ✅ **Dashboards de BI** para todos los departamentos
- ✅ **Modelos de Machine Learning** para predicciones y recomendaciones
- ✅ **Gobernanza centralizada** con control de acceso granular
- ✅ **Escalabilidad** para agregar nuevas fuentes y dominios en el futuro

### Cumplimiento de Requisitos

| Requisito | Solución | Estado |
|-----------|----------|--------|
| Google Cloud Platform | Toda la infraestructura en GCP | ✅ |
| Tecnologías Open-Source | Airbyte, dbt, Apache Superset, DataHub | ✅ |
| GitOps & DataOps | GitHub + Terraform + CI/CD automatizado | ✅ |
| Paradigma Data Mesh | Dominio Maisons con arquitectura extensible | ✅ |
| Gobernanza Federada | IAM, Column-Level Security, DataHub | ✅ |

---

## 2. Visión General de la Arquitectura

La arquitectura se organiza en **6 capas** que procesan los datos desde su origen hasta su consumo final:

```Text
┌───────────────────────────────────────────────────────────────────┐
│                    CAPA 6: CONSUMO                                │
│         Dashboards BI • Machine Learning • APIs                   │
├───────────────────────────────────────────────────────────────────┤
│                 CAPA 5: GOBERNANZA FEDERADA                       │
│         Control de Acceso • Catálogo • Calidad • Monitoreo        │
├───────────────────────────────────────────────────────────────────┤
│              CAPA 4: DOMINIO MAISONS (Data Warehouse)             │
│         🥉 Bronze (Raw) → 🥈 Silver (Clean) → 🥇 Gold (Business)   │
├───────────────────────────────────────────────────────────────────┤
│               CAPA 3: PLATAFORMA CENTRAL (GCP)                    │
│              Ingesta de Datos • Orquestación • Data Lake          │
├───────────────────────────────────────────────────────────────────┤
│                 CAPA 2: GitOps & DataOps                          │
│           Control de Versiones • CI/CD • Infraestructura          │
├───────────────────────────────────────────────────────────────────┤
│                 CAPA 1: FUENTES DE DATOS                          │
│    PostgreSQL • MySQL • MongoDB • SAP • Salesforce • SurveyMonkey │
└───────────────────────────────────────────────────────────────────┘
```

---

## 3. Diagrama de Arquitectura

![Diagrama de Arquitectura Completo](docs/diagrams/arquitectura_general.png)

---

## 4. Arquitectura Medallion: El Flujo de Datos

Los datos fluyen a través de **3 capas de calidad progresiva**, lo que garantiza trazabilidad, reprocesamiento y separación de responsabilidades:

### 🥉 Capa Bronze (Datos Crudos)
- **Propósito:** Almacenar datos exactamente como llegan de las fuentes
- **Beneficio:** Permite reprocesar desde el origen si hay errores
- **Acceso:** Solo equipo técnico

### 🥈 Capa Silver (Datos Limpios)
- **Propósito:** Limpiar, validar y estandarizar datos
- **Transformaciones:** Eliminación de duplicados, tipado correcto, validaciones
- **Acceso:** Equipo de datos y científicos de datos

### 🥇 Capa Gold (Datos de Negocio)
- **Propósito:** Datos listos para consumo por usuarios de negocio
- **Estructura:** Un dataset por entidad (clientes, productos, ventas)
- **Acceso:** Por departamento según permisos

| Capa | Ejemplo de Tabla | Usuarios | Actualización |
|------|------------------|----------|---------------|
| Bronze | `raw_clientes` | Ingenieros | Cada sync |
| Silver | `stg_clientes` | Data Team | Diaria |
| Gold | `mart_clientes_360` | Analistas, BI | Diaria |

---

## 5. Stack Tecnológico

### Tecnologías Open-Source Seleccionadas

| Componente | Tecnología | Justificación |
|------------|------------|---------------|
| **Ingesta** | Airbyte | +300 conectores, extensible, sin costo por volumen |
| **Transformación** | dbt | Estándar de industria, SQL-based, versionable |
| **Orquestación** | Apache Airflow | Robusto, flexible, amplia comunidad |
| **Catálogo** | DataHub | Linaje automático, búsqueda avanzada |
| **BI** | Apache Superset | Self-service analytics, SQL Lab |

### Servicios Google Cloud

| Componente | Servicio GCP | Beneficio |
|------------|--------------|-----------|
| **Data Warehouse** | BigQuery | Escalable, serverless, económico |
| **Orquestación** | Cloud Composer | Airflow gestionado, alta disponibilidad |
| **Infraestructura** | GKE | Kubernetes para Airbyte |
| **ML Platform** | Vertex AI | MLOps completo, Feature Store |
| **Almacenamiento** | Cloud Storage | Data Lake escalable |

---

## 6. Data Mesh: Principios Aplicados

La arquitectura implementa los **4 principios fundamentales de Data Mesh**:

### 1️⃣ Propiedad por Dominio
Cada área de negocio es responsable de sus datos:
- **Dominio Clientes:** Gestiona `gold_clientes`
- **Dominio Productos:** Gestiona `gold_productos`
- **Dominio Ventas:** Gestiona `gold_ventas`

### 2️⃣ Datos como Producto
Cada dataset Gold es un **producto de datos** con:
- Documentación clara
- SLAs definidos (frescura, disponibilidad)
- Owner identificado
- Tests de calidad automatizados

### 3️⃣ Plataforma Self-Service
Los equipos de dominio pueden:
- Consumir datos sin conocer la infraestructura
- Crear sus propios análisis y dashboards
- Acceder solo a los datos que necesitan

### 4️⃣ Gobernanza Federada
Reglas centrales aplicadas uniformemente:
- Estándares de nomenclatura
- Clasificación de datos sensibles (PII)
- Políticas de acceso consistentes

---

## 7. Gobernanza y Seguridad

### Control de Acceso por Capa

```
┌─────────────────────────────────────────────────────────────┐
│                    Proyecto GCP: Maisons                    │
├─────────────────────────────────────────────────────────────┤
│  Bronze: Solo Airbyte (escritura) + Data Engineering        │
├─────────────────────────────────────────────────────────────┤
│  Silver: Data Engineering + Data Scientists                 │
├─────────────────────────────────────────────────────────────┤
│  Gold:                                                      │
│    ├── gold_clientes → Equipo Clientes + Analistas         │
│    ├── gold_productos → Equipo Productos + Analistas       │
│    └── gold_ventas → Equipo Ventas + Analistas             │
│                                                             │
│  + Column-Level Security en columnas PII (email, teléfono)  │
└─────────────────────────────────────────────────────────────┘
```

### Protección de Datos Sensibles

Los campos con información personal identificable (PII) están protegidos mediante **Column-Level Security**:

- Solo usuarios autorizados pueden ver columnas sensibles
- El resto ve valores enmascarados o NULL
- Auditoría completa de accesos

---

## 8. GitOps & Automatización

### Todo como Código

| Componente | Herramienta | Repositorio |
|------------|-------------|-------------|
| Infraestructura | Terraform | `infra/` |
| Transformaciones | dbt | `dbt/` |
| Pipelines | Airflow DAGs | `dags/` |
| Configuración | YAML/JSON | `config/` |

### Flujo de Despliegue Automatizado

```
Developer → Pull Request → Code Review → Merge → CI/CD → Producción
                              ↓
                     Tests automáticos
                     Validación de calidad
                     Revisión de cambios
```

**Beneficios:**
- ✅ Todos los cambios son revisados antes de producción
- ✅ Historial completo de modificaciones
- ✅ Rollback instantáneo si hay problemas
- ✅ Ambientes consistentes (dev, staging, prod)

---

## 9. Observabilidad y Monitoreo

### Métricas Monitoreadas

| Capa | Métrica | Alerta |
|------|---------|--------|
| Ingesta | Registros cargados/hora | Por debajo del umbral |
| Bronze→Silver | Duración de transformación | Superior a 2x promedio |
| Silver→Gold | Duración de marts | Superior a 2x promedio |
| Calidad | Tests fallidos | Cualquier fallo |
| Consumo | Queries lentas | Superior a 60 segundos |

### Stack de Observabilidad

- **Cloud Monitoring:** Métricas de todos los servicios
- **Cloud Alerting:** Notificaciones a Slack/PagerDuty
- **DataHub:** Linaje visual para análisis de impacto

---

## 10. Extensibilidad

### Agregar Nueva Fuente de Datos
**Tiempo estimado:** 1-2 días

1. Configurar conector en Airbyte
2. Crear modelo dbt de staging
3. Agregar tests de calidad

### Agregar Nueva Entidad en Gold
**Tiempo estimado:** 1-2 días

1. Crear dataset `gold_[nueva_entidad]`
2. Desarrollar modelos dbt correspondientes
3. Configurar permisos IAM

### Agregar Nuevo Dominio (futuro)
**Tiempo estimado:** 1-2 semanas

1. Crear nuevo proyecto GCP
2. Replicar estructura Bronze/Silver/Gold
3. Configurar gobernanza federada

---

## 11. Estimación de Costos

### Costo Mensual Estimado

| Componente | Rango Mensual |
|------------|---------------|
| Ingesta (GKE + Airbyte) | $200 - $500 |
| Orquestación (Cloud Composer) | $300 - $800 |
| Almacenamiento (BigQuery) | $100 - $330 |
| Procesamiento (BigQuery) | $200 - $1,000 |
| Data Lake (GCS) | $20 - $50 |
| ML Platform (Vertex AI) | $100 - $500 |
| Monitoreo | $50 - $100 |
| **Total Estimado** | **$970 - $3,280** |

*Los costos varían según volumen de datos y frecuencia de procesamiento.*

### Optimización de Costos
- Particionamiento de tablas por fecha
- Slot reservations para cargas predecibles
- Lifecycle policies para datos antiguos

---

## 12. Plan de Implementación

### Fase 1: Fundamentos (Semanas 1-4)
- [ ] Provisionar infraestructura con Terraform
- [ ] Configurar proyecto GCP y datasets
- [ ] Desplegar Airbyte y Cloud Composer

### Fase 2: Primeras Fuentes (Semanas 5-8)
- [ ] Conectar PostgreSQL y Salesforce
- [ ] Implementar modelos dbt Bronze y Silver
- [ ] Configurar pipelines diarios

### Fase 3: Primer Dominio Gold (Semanas 9-12)
- [ ] Desarrollar `gold_clientes`
- [ ] Implementar tests de calidad
- [ ] Conectar con Apache Superset

### Fase 4: Dominios Adicionales (Semanas 13-16)
- [ ] Desarrollar `gold_productos` y `gold_ventas`
- [ ] Configurar DataHub para catalogación
- [ ] Implementar Column-Level Security

### Fase 5: ML y Optimización (Semanas 17-20)
- [ ] Integrar Vertex AI Feature Store
- [ ] Optimizar costos y performance
- [ ] Documentación y capacitación

---

## 13. Beneficios de la Solución

### Para el Negocio
- **Decisiones basadas en datos:** Dashboards actualizados diariamente
- **Predicciones precisas:** Modelos ML con datos de calidad
- **Autonomía de equipos:** Self-service analytics

### Para TI
- **Reducción de deuda técnica:** Arquitectura moderna y mantenible
- **Escalabilidad:** Crece con las necesidades del negocio
- **Seguridad:** Control granular de acceso

### Para Cumplimiento
- **Trazabilidad completa:** De origen a consumo
- **Auditoría:** Historial de cambios y accesos
- **Gobernanza:** Políticas uniformes

---

## 14. Próximos Pasos

1. **Revisión de la propuesta** con stakeholders técnicos y de negocio
2. **Definición de prioridades** para las primeras fuentes de datos
3. **Kick-off del proyecto** y asignación de equipos
4. **Inicio de Fase 1** con provisión de infraestructura

---
