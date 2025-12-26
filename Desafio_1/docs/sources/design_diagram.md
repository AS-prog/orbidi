```mermaid
---
config:
  layout: elk
---
flowchart LR
 subgraph Sources["🗄️ Fuentes de Datos (Origen)"]
    direction LR
        S1[("PostgreSQL")]
        S2[("MySQL")]
        S3[("MongoDB")]
        S4["SAP"]
        S5["Salesforce"]
        S6["SurveyMonkey"]
  end
 subgraph GitOps["⚙️ GitOps & DataOps"]
    direction LR
        Git["GitHub / GitLab
        (Version Control)"]
        CICD["Cloud Build / 
        GitHub Actions
        (CI/CD Pipelines)"]
        TF["Terraform
        (IaC - Toda Infra)"]
  end
 subgraph Ingestion["Ingesta & Orquestación (Open Source)"]
    direction LR
        Airbyte["Airbyte (En GKE)
        Extract & Load"]
        Airflow["Apache Airflow
        (Cloud Composer)
        Orquestación"]
  end
 subgraph Platform["☁️ Plataforma de Datos (GCP - Infraestructura Central)"]
    direction TB
        Ingestion
        GCS[("Data Lake
    GCS Buckets
    Format: Parquet/Delta")]
  end
 subgraph Bronze["🥉 Capa Bronze (Raw)"]
        BQ_Bronze[("BigQuery Dataset
        bronze
        ─────────────
        raw_clientes
        raw_productos
        raw_ventas
        raw_surveys
        ...")]
        dbt_Bronze["dbt models
        (staging)"]
  end
 subgraph Silver["🥈 Capa Silver (Cleaned)"]
        BQ_Silver[("BigQuery Dataset
        silver
        ─────────────
        stg_clientes
        stg_productos
        stg_ventas
        stg_surveys
        ...")]
        dbt_Silver["dbt models
        (intermediate)"]
  end
 subgraph GoldClientes["Dataset: gold_clientes"]
        BQ_Gold_C[("mart_clientes_360
            dim_clientes
            fct_interacciones")]
  end
 subgraph GoldProductos["Dataset: gold_productos"]
        BQ_Gold_P[("mart_catalogo
            dim_productos
            fct_inventario")]
  end
 subgraph GoldVentas["Dataset: gold_ventas"]
        BQ_Gold_V[("mart_ventas
            fct_transacciones
            agg_ventas_diarias")]
  end
 subgraph GoldFuturo["Dataset: gold_[extensible]"]
        BQ_Gold_F[("mart_[nuevo]
            ...")]
  end
 subgraph Gold["🥇 Capa Gold (Business / Marts)"]
    direction LR
        GoldClientes
        GoldProductos
        GoldVentas
        GoldFuturo
        dbt_Gold["dbt models
        (marts)"]
  end
 subgraph Maisons["🏛️ Dominio: Maisons (Proyecto GCP)"]
    direction TB
        Bronze
        Silver
        Gold
  end
 subgraph Access["Control de Acceso"]
        IAM["Cloud IAM
        (Roles & Policies)"]
        ColSec["Column-Level Security
        (BigQuery Policy Tags)"]
  end
 subgraph Catalog["Catalogación"]
        DataHub["DataHub
        (Catálogo de Datos)
        Linaje & Metadata"]
  end
 subgraph Quality["Calidad de Datos"]
        GreatExp["Great Expectations
        (Data Quality Tests)"]
        dbtTests["dbt Tests
        (Schema & Data Tests)"]
  end
 subgraph Observability["Observabilidad"]
        Monitoring["Cloud Monitoring
        (Métricas & Logs)"]
        Alerting["Cloud Alerting +
        Slack/PagerDuty
        (Notificaciones)"]
  end
 subgraph Governance["🛡️ Plano de Gobernanza Federada"]
    direction TB
        Access
        Catalog
        Quality
        Observability
  end
 subgraph Consumption["📊 Capa de Consumo"]
    direction LR
        BI["Apache Superset
        (BI Dashboards)
        Self-Service Analytics"]
        ML["Vertex AI
        (MLOps Platform)
        Feature Store
        Model Registry"]
        API["Cloud Functions /
        Cloud Run
        (Data APIs)"]
  end
    S1 --> Airbyte
    S2 --> Airbyte
    S3 --> Airbyte
    S4 --> Airbyte
    S5 --> Airbyte
    S6 --> Airbyte
    Airbyte --> GCS
    GCS --> BQ_Bronze
    BQ_Bronze <--> dbt_Bronze
    dbt_Bronze --> BQ_Silver
    BQ_Silver <--> dbt_Silver
    dbt_Silver --> BQ_Gold_C & BQ_Gold_P & BQ_Gold_V
    dbt_Silver -.-> BQ_Gold_F & dbtTests
    BQ_Gold_C <--> dbt_Gold
    BQ_Gold_P <--> dbt_Gold
    BQ_Gold_V <--> dbt_Gold
    Airflow -. trigger .-> Airbyte
    Airflow -. orchestrate .-> dbt_Bronze & dbt_Silver & dbt_Gold
    dbt_Bronze -.-> dbtTests
    dbt_Gold -.-> GreatExp & dbtTests
    dbt_Gold -. metadata .-> DataHub
    BQ_Silver -. metadata .-> DataHub
    IAM -.-> BQ_Gold_C & BQ_Gold_P & BQ_Gold_V
    ColSec -.-> BQ_Gold_C & BQ_Gold_P
    Airflow -.-> Monitoring
    Airbyte -.-> Monitoring
    GreatExp -.-> Alerting
    Monitoring -.-> Alerting
    BQ_Gold_C --> BI & ML & API
    BQ_Gold_P --> BI & ML & API
    BQ_Gold_V --> BI & ML & API
    Git -- PR/Merge --> CICD
    CICD -- deploy --> TF
    TF -- provision --> Platform & Maisons & Governance
    Git -- version --> dbt_Bronze & dbt_Silver & dbt_Gold
    CICD -- test & deploy --> dbt_Bronze & dbt_Silver & dbt_Gold

     S1:::source
     S2:::source
     S3:::source
     S4:::source
     S5:::source
     S6:::source
     Git:::gitops
     CICD:::gitops
     TF:::gitops
     Airbyte:::oss
     Airflow:::gcp
     GCS:::gcp
     BQ_Bronze:::gcp
     dbt_Bronze:::oss
     BQ_Silver:::gcp
     dbt_Silver:::oss
     BQ_Gold_C:::gcp
     BQ_Gold_P:::gcp
     BQ_Gold_V:::gcp
     BQ_Gold_F:::gcp
     dbt_Gold:::oss
     IAM:::gcp
     ColSec:::gcp
     DataHub:::oss
     GreatExp:::oss
     dbtTests:::oss
     Monitoring:::gcp
     Alerting:::gcp
     BI:::oss
     ML:::gcp
     API:::gcp
    classDef gcp fill:#e8f0fe,stroke:#4285f4,stroke-width:2px
    classDef oss fill:#e6f4ea,stroke:#34a853,stroke-width:2px,stroke-dasharray: 5 5
    classDef source fill:#fce8e6,stroke:#ea4335,stroke-width:2px
    classDef gitops fill:#f3e8fd,stroke:#9334e6,stroke-width:2px