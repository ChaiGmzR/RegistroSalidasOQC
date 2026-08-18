# Flujo de Rechazo OQC

Este documento describe el proceso de rechazo, aprobacion parcial y liberacion de material rechazado en la aplicacion OQC Registro de Salidas.

## Resumen

El proceso separa dos acciones:

- **Aprobacion**: un supervisor autoriza seriales rechazados para que puedan volver a salir.
- **Liberacion**: los seriales aprobados se registran nuevamente como salida OQC y quedan ligados a un folio OQC nuevo.

Una pieza aprobada no esta liberada hasta que vuelve a pasar por el flujo normal de salida.

## Registro Inicial Del Rechazo

```mermaid
flowchart TD
    A[Inicio: Nuevo Registro OQC] --> B[Escanear PCB]
    B --> C{PN PCB valido?}
    C -- No --> C1[Error: no se pudo extraer PN]
    C -- Si --> D[Escanear etiqueta]

    D --> E{Etiqueta valida?}
    E -- No --> E1[Error: formato no reconocido]
    E -- Si --> F{PN etiqueta = PN PCB?}
    F -- No --> F1[Error de PN]
    F -- Si --> G[Escanear Box ID]

    G --> H[Validar si Box ya existe en salidas OQC]
    H --> I{Box ya liberado a almacen?}
    I -- Si + QC aprobado --> I1[Bloquear: ya fue liberado]
    I -- Si + QC rechazado --> I2[Permitir como rechazo de almacen]
    I -- No --> J[Consultar piezas del Box en LQC box_scans]

    I2 --> J
    J --> K{Box existe en LQC?}
    K -- No --> K1[Error: box no encontrado]
    K -- Si --> L{PN y cantidad cuadran?}

    L -- No + QC aprobado --> L1[Bloquear salida aprobada]
    L -- No + QC rechazado --> M[Permitir rechazo con diferencias]
    L -- Si --> M

    M --> N{Aprobado por QC?}
    N -- Si --> O[Crear salida normal OQC]
    N -- No --> P{Observaciones capturadas?}

    P -- No --> P1[Error: observaciones obligatorias]
    P -- Si --> Q[Crear rechazo OQC]

    Q --> R[Generar folio REJ-YYYYMMDD-XXX]
    R --> S[Insertar encabezado en oqc_rejections]
    S --> T[Buscar seriales del Box en box_scans]
    T --> U[Insertar seriales en oqc_rejection_items como rejected]
    U --> V[Estado rechazo: rejected]
```

## Aprobacion De Rechazo

```mermaid
flowchart TD
    A[Rechazo en pantalla Registros] --> B[Supervisor abre aprobar rechazo]
    B --> C[Cargar detalle: oqc_rejection_items]
    C --> D[Mostrar seriales agrupados por Box original]
    D --> E[Supervisor selecciona seriales]
    E --> F[Captura PIN supervisor]
    F --> G{PIN valido?}

    G -- No --> G1[Error: PIN incorrecto]
    G -- Si --> H{Hay seriales seleccionados?}
    H -- No --> H1[Error: seleccione al menos una pieza]
    H -- Si --> I[Actualizar items seleccionados]

    I --> J[status = approved]
    J --> K[Guardar approved_by y approved_at]
    K --> L[Recalcular estado del encabezado]

    L --> M{Conteo de items}
    M -- Todos rejected --> M1[Encabezado: rejected]
    M -- Algunos approved/released y otros rejected --> M2[Encabezado: partial_approved]
    M -- Todos approved o released --> M3[Encabezado: approved]
    M -- Todos released --> M4[Encabezado: released]
```

## Liberacion De Material Aprobado

La liberacion sucede cuando el material aprobado se registra otra vez como una salida OQC normal. No ocurre en el boton de aprobar.

```mermaid
flowchart TD
    A[Material aprobado vuelve desde LQC] --> B[LQC puede reempacar]
    B --> C[Box nuevo puede contener piezas aprobadas + piezas nuevas]
    C --> D[OQC registra salida normal]
    D --> E[Escanea PCB, etiqueta y Box]
    E --> F[Backend createWithFolio]

    F --> G[validateBoxesForRelease]
    G --> H[Leer seriales actuales del Box en box_scans]
    H --> I[Buscar esos seriales en oqc_rejection_items]

    I --> J{Algun serial ya released?}
    J -- Si --> J1[Bloquear: pieza ya liberada]
    J -- No --> K{Algun serial rejected?}

    K -- Si --> K1[Bloquear: pieza sin aprobar]
    K -- No --> L{Rechazo parcial en mismo Box original?}

    L -- Si --> L1[Bloquear: parcial debe salir en Box diferente]
    L -- No --> M[Permitir salida]

    M --> N[Crear folio OQC en exit_records]
    N --> O[Registrar cajas en oqc_release_boxes]
    O --> P[markReleasedForBoxes]
    P --> Q[Items approved pasan a released]
    Q --> R[Guardar release_folio y released_at]
    R --> S[Recalcular estado del rechazo]
```

## Estados Del Rechazo

```mermaid
stateDiagram-v2
    [*] --> rejected: Se crea rechazo

    rejected --> partial_approved: Supervisor aprueba algunos seriales
    rejected --> approved: Supervisor aprueba todos los seriales

    partial_approved --> partial_approved: Se liberan solo algunos aprobados
    partial_approved --> approved: Se aprueban todos los restantes
    partial_approved --> released: Todos los seriales quedan liberados

    approved --> partial_approved: Se libera una parte
    approved --> released: Se liberan todos

    released --> [*]
```

## Significado De Estados

### Encabezado: `oqc_rejections.status`

| Estado | Significado |
| --- | --- |
| `rejected` | El rechazo existe y sus piezas siguen rechazadas. |
| `partial_approved` | Algunas piezas ya fueron aprobadas o liberadas, pero quedan piezas rechazadas. |
| `approved` | Todas las piezas del rechazo estan aprobadas o liberadas, pero no todas han salido de nuevo. |
| `released` | Todas las piezas del rechazo ya fueron liberadas con folio OQC. |

### Detalle: `oqc_rejection_items.status`

| Estado | Significado |
| --- | --- |
| `rejected` | La pieza no puede salir. |
| `approved` | La pieza puede volver a salir por el flujo normal OQC. |
| `released` | La pieza ya salio nuevamente y tiene `release_folio`. |

## Reglas De Liberacion

La validacion permite:

- Liberar una caja con piezas de rechazo `approved`.
- Incluir piezas nuevas o de reemplazo que no aparecen en `oqc_rejection_items`.
- Liberar parcialmente solo las piezas que ya fueron aprobadas.

La validacion bloquea:

- Piezas del rechazo que siguen en `rejected`.
- Piezas que ya estan en `released`.
- Piezas de otro rechazo que todavia no esta aprobado.
- Un rechazo parcial que intenta salir en el mismo Box ID original.

## Ejemplo Operativo

1. Se rechaza una caja con 70 piezas y se genera `REJ-YYYYMMDD-001`.
2. LQC reinspecciona y determina que 20 piezas son recuperables.
3. Supervisor aprueba solo esos 20 seriales.
4. El rechazo queda `partial_approved`.
5. LQC reemplaza las piezas scrap con piezas nuevas para completar la caja.
6. OQC escanea esa caja como salida aprobada.
7. El backend marca los 20 seriales aprobados como `released`.
8. Las piezas nuevas no cambian estado de rechazo porque no pertenecen al rechazo.
9. El rechazo seguira `partial_approved` hasta que todos sus seriales queden aprobados/liberados o se defina otro cierre operativo.
