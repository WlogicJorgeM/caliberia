# 🔫 CaliberIA v2.0

Sistema de análisis balístico forense asistido por inteligencia artificial. Identifica calibre, tipo de munición, armas compatibles y fabricantes a partir de imágenes de evidencia.

## Arquitectura de IA Dual

CaliberIA utiliza un sistema inteligente de doble motor:

| Motor | Tipo | Visión Real | Velocidad | Requisito |
|-------|------|-------------|-----------|-----------|
| **Gemini Flash** | Cloud (Google) | ✅ Sí | ~3-5s | API Key gratuita |
| **Ollama** | Local | ❌ No | ~5-10s | Ollama instalado |

**Modo automático**: Intenta Gemini primero (visión real de la imagen). Si falla, usa Ollama como fallback local.

---

## Requisitos

| Herramienta | Versión | Uso |
|-------------|---------|-----|
| Flutter SDK | 3.x+ | Framework UI |
| Node.js / npm | 18+ | Scripts de ejecución |
| Google AI Studio | - | API Key gratuita (recomendado) |
| Ollama | latest | Motor local (opcional) |

---

## Instalación

```bash
cd caliberia_flutter
npm install
```

### Configurar IA (elegir una o ambas):

**Opción A — Gemini (recomendado, gratis con visión real):**
1. Ve a [aistudio.google.com/apikey](https://aistudio.google.com/app/apikey)
2. Crea una API Key gratuita
3. Edita `.env`:
```env
GEMINI_API_KEY=tu_api_key_aqui
AI_PROVIDER=auto
```

**Opción B — Ollama (100% local, sin internet):**
```bash
npm run ollama:pull
```

---

## Comandos

| Comando | Descripción |
|---------|-------------|
| `npm install` | Instala dependencias Flutter |
| `npm start` | Abre en Chrome (localhost:8080) |
| `npm run start:edge` | Abre en Edge |
| `npm run build` | Build de producción |
| `npm run analyze` | Verifica errores |
| `npm run test` | Ejecuta tests |
| `npm run clean` | Limpia cache |

---

## Uso

### 1. Iniciar
```bash
npm start
```

### 2. Login
```
Email: admin@admin.com
Contraseña: 123
```

### 3. Analizar
1. Pulsa **Cámara** o **Galería**
2. Selecciona imagen de munición
3. La IA analiza y muestra:
   - Calibre estimado
   - Tipo de munición
   - Arma compatible
   - Fabricantes probables
   - Nivel de confianza
   - Descripción técnica forense
4. Indicador muestra qué motor se usó y tiempo de respuesta

---

## Arquitectura del Proyecto

```
lib/
├── main.dart                          # Entry point + Provider setup
├── app.dart                           # MaterialApp + routing
├── theme.dart                         # Design system (zinc/emerald)
├── core/
│   ├── constants.dart                 # Configuración centralizada
│   ├── exceptions.dart                # Excepciones tipadas
│   └── app_logger.dart                # Logging estructurado
├── models/
│   └── ballistic_analysis.dart        # Modelos de datos
├── providers/
│   └── analysis_provider.dart         # Estado global (ChangeNotifier)
├── services/
│   ├── ai_service.dart                # IA dual (Gemini + Ollama)
│   └── storage_service.dart           # Persistencia + auth
├── screens/
│   ├── login_screen.dart              # Autenticación
│   └── home_screen.dart               # Pantalla principal
└── widgets/
    ├── analysis_result_widget.dart    # Resultado del análisis
    └── history_list_widget.dart       # Lista de historial
```

---

## Mejoras v2.0 vs v1.0

| Aspecto | v1.0 | v2.0 |
|---------|------|------|
| IA | Ollama solo (sin visión) | Gemini + Ollama (dual) |
| Visión real | ❌ | ✅ (Gemini) |
| State management | setState | Provider |
| Seguridad | Plaintext | Hash SHA-256 + Secure Storage |
| Sesión | Sin expiración | Timeout 60min |
| Errores | Genéricos | Tipados + reintentos |
| Logging | Ninguno | Estructurado |
| Fallback | Ninguno | Auto (Gemini → Ollama) |
| Métricas | Ninguna | Tiempo de respuesta + provider |

---

## Configuración (.env)

```env
# API Key de Google AI Studio (gratis)
GEMINI_API_KEY=tu_key

# Ollama local (fallback)
OLLAMA_URL=http://localhost:11434
OLLAMA_MODEL=qwen2.5-coder:1.5b

# Proveedor: auto | gemini | ollama
AI_PROVIDER=auto
```

---

## Tecnologías

- **Flutter 3.x** — Framework multiplataforma
- **Dart** — Lenguaje tipado
- **Google Generative AI** — Gemini 2.0 Flash (visión)
- **Ollama** — Modelos locales
- **Provider** — State management
- **Flutter Secure Storage** — Datos sensibles
- **SHA-256** — Hash de credenciales
- **Logger** — Logging estructurado

---

## Para la Tesis

Este proyecto demuestra:
- Integración de IA generativa con visión por computadora
- Arquitectura limpia con separación de responsabilidades
- Sistema de fallback entre servicios cloud y locales
- Manejo robusto de errores con reintentos
- Seguridad básica (hash, secure storage, sesiones)
- Prompt engineering para análisis forense

---

*CaliberIA v2.0 — Investigación Académica — 2026*
