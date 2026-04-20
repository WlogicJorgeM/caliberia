# 🔫 CaliberIA

Asistente de investigación balística basado en inteligencia artificial local. Analiza imágenes de municiones, balas y cartuchos para identificar calibre, tipo de munición, armas compatibles y fabricantes probables.

**100% local** — usa [Ollama](https://ollama.com) como motor de IA. No requiere internet ni API keys externas.

---

## Requisitos

| Herramienta | Versión | Instalación |
|-------------|---------|-------------|
| Flutter SDK | 3.x+ | `C:\flutter\bin` (ya instalado) |
| Node.js / npm | 18+ | Para ejecutar scripts rápidos |
| Ollama | latest | [ollama.com/download](https://ollama.com/download) |
| Chrome o Edge | cualquiera | Navegador para la app web |

---

## Instalación rápida

```bash
# 1. Entrar al proyecto
cd caliberia_flutter

# 2. Instalar dependencias de Flutter
npm install

# 3. Descargar el modelo de IA (solo la primera vez, ~1GB)
npm run ollama:pull
```

---

## Comandos disponibles

| Comando | Descripción |
|---------|-------------|
| `npm install` | Instala dependencias de Flutter (`flutter pub get`) |
| `npm start` | Abre la app en **Chrome** en `localhost:8080` |
| `npm run start:edge` | Abre la app en **Edge** en `localhost:8080` |
| `npm run build` | Genera build de producción web |
| `npm run analyze` | Verifica errores en el código |
| `npm run clean` | Limpia cache y archivos temporales |
| `npm run devices` | Lista dispositivos disponibles |
| `npm run ollama:status` | Verifica que Ollama esté corriendo |
| `npm run ollama:pull` | Descarga el modelo de IA necesario |

---

## Uso

### 1. Asegúrate de que Ollama esté corriendo

Ollama debe estar ejecutándose en segundo plano. Si no lo está, ábrelo desde el menú de inicio o ejecuta:

```bash
npm run ollama:status
```

Si responde con una lista de modelos, está listo.

### 2. Inicia la app

```bash
npm start
```

Se abrirá Chrome automáticamente en `http://localhost:8080`.

### 3. Inicia sesión

```
Email: admin@admin.com
Contraseña: 123
```

### 4. Analiza una imagen

1. En la pantalla principal, pulsa **Cámara** o **Galería**
2. Selecciona o toma una foto de una bala, cartucho o munición
3. Espera ~5-10 segundos mientras la IA procesa
4. El reporte aparecerá con:
   - Calibre estimado
   - Tipo de munición
   - Arma compatible
   - Longitud estimada
   - Fabricantes probables
   - Nivel de confianza
   - Descripción técnica

### 5. Historial

- Todos los análisis se guardan automáticamente
- Accede desde el ícono 🕐 en la barra superior
- Puedes agregar notas a cada análisis
- Puedes eliminar registros individuales

---

## Configuración

El archivo `.env` controla la conexión con Ollama:

```env
OLLAMA_URL=http://localhost:11434
OLLAMA_MODEL=qwen2.5-coder:1.5b
```

Puedes cambiar `OLLAMA_MODEL` por cualquier modelo compatible instalado en Ollama.

---

## Estructura del proyecto

```
caliberia_flutter/
├── lib/
│   ├── main.dart                 # Entry point
│   ├── app.dart                  # MaterialApp config
│   ├── theme.dart                # Tema zinc/emerald
│   ├── models/
│   │   └── ballistic_analysis.dart  # Modelos de datos
│   ├── screens/
│   │   ├── login_screen.dart     # Pantalla de login
│   │   └── home_screen.dart      # Pantalla principal
│   ├── services/
│   │   ├── ollama_service.dart   # Integración con Ollama
│   │   └── storage_service.dart  # Persistencia local
│   └── widgets/
│       ├── analysis_result_widget.dart
│       └── history_list_widget.dart
├── .env                          # Config de Ollama
├── package.json                  # Scripts npm
├── pubspec.yaml                  # Dependencias Flutter
└── README.md
```

---

## Solución de problemas

| Problema | Solución |
|----------|----------|
| Puerto 8080 ocupado | Cierra la pestaña anterior o cambia el puerto en `package.json` |
| Ollama no responde | Verifica que esté corriendo con `npm run ollama:status` |
| Análisis muy lento | Usa un modelo más pequeño en `.env` |
| Error al cargar imagen | Usa imágenes JPG/PNG de menos de 5MB |

---

## Tecnologías

- **Flutter** — Framework UI multiplataforma
- **Ollama** — Motor de IA local (modelo `qwen2.5-coder:1.5b`)
- **Dart** — Lenguaje de programación
- **SharedPreferences** — Persistencia local del historial

---

*CaliberIA v1.0.0 — Investigación Académica — 2026*
