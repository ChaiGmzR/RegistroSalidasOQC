# OQC - Sistema de Registro de Salidas
## Ilsan Electronics

Sistema de escritorio para el registro de salidas de materiales del departamento OQC (Outgoing Quality Control) para la manufactura de PCB de refrigeradores LG.

---

## 📋 Características

- ✅ Registro de salidas de PCBs aprobadas por QC
- ✅ Gestión de números de parte con standard pack
- ✅ Control de cajas ESD (10, 20, 40, 80, 100 piezas)
- ✅ Gestión de operadores
- ✅ Dashboard con estadísticas en tiempo real
- ✅ Filtrado y búsqueda de registros
- ✅ Cambio de estados (Pendiente → Liberado → Enviado)
- ✅ Reportes y gráficos

---

## 🏗️ Estructura del Proyecto

```
RegistroSalidasOQC/
├── backend/                 # API Node.js + Express
│   ├── src/
│   │   ├── config/         # Configuración de BD
│   │   ├── models/         # Modelos de datos
│   │   ├── routes/         # Rutas API REST
│   │   └── server.js       # Servidor principal
│   ├── .env                # Variables de entorno
│   └── package.json
│
└── frontend/               # Aplicación Flutter Desktop
    ├── lib/
    │   ├── config/         # Configuración API
    │   ├── models/         # Modelos de datos
    │   ├── providers/      # Estado de la aplicación
    │   ├── screens/        # Pantallas UI
    │   ├── services/       # Servicios API
    │   ├── theme/          # Tema visual
    │   └── main.dart       # Entrada de la app
    └── pubspec.yaml
```

---

## 🗄️ Modelo de Datos (MySQL)

### Tablas

1. **part_numbers** - Números de parte de PCB
   - part_number, description, standard_pack, model, customer

2. **esd_boxes** - Tipos de cajas ESD
   - box_code, capacity (10, 20, 40, 80, 100)

3. **operators** - Operadores del departamento
   - employee_id, name, department

4. **exit_records** - Registros de salida principales
   - folio, quantity, lot_number, serial_start/end, inspection_date, status

5. **inspection_details** - Detalles de inspección
   - inspection_type, result, notes

---

## 🚀 Instalación y Ejecución

### Prerrequisitos
- Node.js 18+ 
- Flutter 3.0+
- Git

### 1. Backend (Node.js)

```bash
# Navegar al directorio backend
cd backend

# Instalar dependencias
npm install

# Iniciar servidor (crea las tablas automáticamente)
npm start
```

El servidor estará disponible en: `http://localhost:3000`

### 2. Frontend (Flutter)

```bash
# Navegar al directorio frontend
cd frontend

# Obtener dependencias
flutter pub get

# Ejecutar en modo escritorio (Windows)
flutter run -d windows
```

---

## 📡 API Endpoints

### Part Numbers
- `GET /api/part-numbers` - Listar todos
- `POST /api/part-numbers` - Crear nuevo
- `PUT /api/part-numbers/:id` - Actualizar
- `DELETE /api/part-numbers/:id` - Eliminar

### ESD Boxes
- `GET /api/esd-boxes` - Listar cajas ESD

### Operators
- `GET /api/operators` - Listar operadores
- `POST /api/operators` - Crear operador

### Exit Records
- `GET /api/exit-records` - Listar registros (con filtros)
- `POST /api/exit-records` - Crear registro
- `GET /api/exit-records/:id` - Obtener por ID
- `PATCH /api/exit-records/:id/status` - Cambiar estado
- `GET /api/exit-records/stats` - Estadísticas

---

## 🔧 Configuración

### Variables de Entorno (backend/.env)

```env
DB_HOST=192.168.1.10
DB_PORT=3306
DB_USER=<usuario_mysql>
DB_PASSWORD=<password_mysql>
DB_NAME=<base_de_datos>
PORT=3000
```

### Configuración API (frontend/lib/config/api_config.dart)

```dart
static const String baseUrl = 'http://localhost:3000/api';
```

---

## 📱 Pantallas de la Aplicación

1. **Dashboard** - Vista general con estadísticas y últimos registros
2. **Nuevo Registro** - Formulario para registrar salidas
3. **Registros** - Lista completa con filtros y búsqueda
4. **Números de Parte** - CRUD de números de parte
5. **Operadores** - Gestión de operadores
6. **Reportes** - Estadísticas y gráficos

---

## 🔄 Flujo de Estados

```
[Nuevo Registro] → PENDIENTE → LIBERADO → ENVIADO
                        ↓
                   CANCELADO
```

---

## 📊 Standard Pack Disponibles

| Código ESD | Capacidad |
|------------|-----------|
| ESD-10     | 10 pzas   |
| ESD-20     | 20 pzas   |
| ESD-40     | 40 pzas   |
| ESD-80     | 80 pzas   |
| ESD-100    | 100 pzas  |

---

## 👥 Desarrollo

**Empresa:** Ilsan Electronics  
**Departamento:** OQC (Outgoing Quality Control)  
**Cliente:** LG

---

## 📄 Licencia

Uso interno - Ilsan Electronics © 2026
