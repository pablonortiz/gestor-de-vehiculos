# 🚗 Gestor de Vehículos

Aplicación multiplataforma para la gestión integral de flotas de vehículos. Desarrollada con Flutter, funciona en Android, iOS, Web, macOS, Linux y Windows.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)

## ✨ Características

### Gestión de Vehículos
- **CRUD completo** de vehículos con información detallada
- **Tipos soportados:** Auto, Camioneta, Camión, Moto
- **Datos del vehículo:** Patente, marca, modelo, año, color, kilometraje
- **VTV y Seguro:** Fechas de vencimiento con alertas visuales
- **Ubicación:** Provincia y ciudad
- **Estado:** Disponible, En uso, En mantenimiento, Fuera de servicio

### 📸 Galería de Fotos
- Múltiples fotos por vehículo
- Selección de foto principal
- Subida desde cámara o galería
- Selección múltiple de fotos
- Almacenamiento en Cloudinary

### 🔧 Mantenimientos
- Registro ilimitado de mantenimientos por vehículo
- Fecha obligatoria con selector de calendario
- Campo de detalle extenso
- **Adjuntos:** PDFs y/o fotos de facturas
- Visualización de adjuntos en pantalla completa

### 📝 Notas
- Sistema de notas múltiples por vehículo
- Campo de detalle extenso
- Fotos adjuntas opcionales
- Visualización de fotos en pantalla completa

### 📄 Documentación
- Sección para Cédula Verde, Cédula Azul y Título
- Múltiples fotos por documento
- Visualización en pantalla completa

### 👤 Responsable
- Nombre y teléfono del responsable del vehículo
- **Importar desde contactos** (solo móvil)
- Llamada directa con un toque
- Mensaje de WhatsApp con un toque

### 📊 Historial de Cambios
- Registro automático de todos los cambios
- Visualización cronológica
- Detalle de campo modificado, valor anterior y nuevo

### 🔄 Sincronización
- **Modo offline:** Trabaja sin conexión
- **Cache local:** Base de datos SQLite en móvil
- **Pull-to-refresh:** Sincronización manual
- **Sync automático:** Al recuperar conexión

### 📤 Exportar/Importar
- Exportar todos los datos en formato JSON
- Importar datos desde archivo JSON
- Compartir archivo de backup

## 🛠️ Tecnologías

| Tecnología | Uso |
|------------|-----|
| **Flutter** | Framework UI multiplataforma |
| **Riverpod** | Gestión de estado |
| **GoRouter** | Navegación declarativa |
| **Supabase** | Backend (PostgreSQL + Auth + Storage) |
| **SQLite** | Cache local (móvil) |
| **Cloudinary** | Almacenamiento de imágenes |

## 📦 Instalación

### Prerrequisitos

- Flutter SDK 3.x
- Cuenta en [Supabase](https://supabase.com)
- Cuenta en [Cloudinary](https://cloudinary.com)

### 1. Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/gestor-de-vehiculos.git
cd gestor-de-vehiculos
```

### 2. Instalar dependencias

```bash
flutter pub get
```

### 3. Configurar variables de entorno

Crear archivo `.env` en la raíz del proyecto:

```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu-anon-key-aqui
CLOUDINARY_CLOUD_NAME=tu-cloud-name
CLOUDINARY_UPLOAD_PRESET=tu-upload-preset
```

> ⚠️ **Importante:** El archivo `.env` está en `.gitignore` y NO se sube al repositorio.

### 4. Configurar Supabase

Ejecutar el script SQL en tu proyecto de Supabase:

```bash
# El archivo está en la raíz del proyecto
supabase_schema.sql
```

O copiar el contenido y ejecutarlo en el SQL Editor de Supabase.

### 5. Configurar Cloudinary

1. Crear cuenta en [Cloudinary](https://cloudinary.com)
2. Ir a Settings > Upload
3. Crear un **Upload Preset** con modo "Unsigned"
4. Copiar el nombre del preset a `.env`

## 🚀 Ejecutar

### Android
```bash
flutter run -d android
```

### iOS
```bash
flutter run -d ios
```

### Web
```bash
flutter run -d chrome
```

### Desktop (macOS/Linux/Windows)
```bash
flutter run -d macos
flutter run -d linux
flutter run -d windows
```

## 📱 Compilar

### Android APK
```bash
flutter build apk
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle
```bash
flutter build appbundle
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS
```bash
flutter build ios
```

### Web
```bash
flutter build web
# Output: build/web/
```

## 🗄️ Estructura del Proyecto

```
lib/
├── core/
│   ├── config/          # Configuración (Supabase, Cloudinary)
│   ├── constants/       # Constantes (tipos de vehículo, provincias)
│   ├── theme/           # Tema de la aplicación
│   └── utils/           # Utilidades
├── data/
│   ├── database/        # SQLite helper
│   ├── repositories/    # Repositorios de datos
│   └── services/        # Servicios (sync, cloudinary)
├── domain/
│   └── models/          # Modelos de dominio
├── presentation/
│   ├── providers/       # Providers de Riverpod
│   ├── screens/         # Pantallas
│   └── widgets/         # Widgets reutilizables
└── main.dart
```

## 🎨 Tema

La aplicación usa un tema oscuro inspirado en la estética de **Radio Nacional Argentina**, con:

- Fondo oscuro (`#121212`)
- Acentos en azul (`#1E88E5`)
- Tipografía clara y legible
- Íconos Material Design

## 📋 Esquema de Base de Datos

### Tablas principales

| Tabla | Descripción |
|-------|-------------|
| `vehicles` | Datos de vehículos |
| `vehicle_history` | Historial de cambios |
| `vehicle_photos` | Galería de fotos |
| `maintenances` | Registros de mantenimiento |
| `maintenance_invoices` | Facturas adjuntas |
| `vehicle_notes` | Notas del vehículo |
| `note_photos` | Fotos de notas |
| `document_photos` | Fotos de documentación |

## 🔐 Seguridad

- Las credenciales se almacenan en `.env` (no se commitean)
- Row Level Security (RLS) habilitado en Supabase
- Validación de datos en cliente y servidor

## 🌐 Diferencias Web vs Móvil

| Característica | Móvil | Web |
|----------------|-------|-----|
| Cache local | ✅ SQLite | ❌ Solo Supabase |
| Importar contacto | ✅ | ❌ |
| Cámara | ✅ | ⚠️ Depende del navegador |
| Galería | ✅ | ✅ File picker |
| Modo offline | ✅ | ❌ |

## 📄 Licencia

Este proyecto es privado y de uso interno.

## 🤝 Contribuir

1. Fork el repositorio
2. Crear rama feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit cambios (`git commit -m 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abrir Pull Request

---

Desarrollado con ❤️ usando Flutter
