# Plataforma Inteligente de Emergencias Vehiculares — App Móvil

Bienvenido al repositorio de la aplicación móvil del sistema de atención de emergencias vehiculares, desarrollada como parte del proyecto integrador de la materia Sistemas de Información 2 en la Universidad Autónoma Gabriel René Moreno (UAGRM - FICCT), Grupo 25, Gestión 2026.

Esta aplicación permite a los clientes reportar emergencias vehiculares en tiempo real, adjuntando audio, imágenes y ubicación GPS, y hacer seguimiento del servicio hasta su cierre y pago.

---

## Tecnologías utilizadas

- Flutter 3.x — Framework de desarrollo móvil multiplataforma
- Dart 3.x — Lenguaje de programación
- FastAPI — Backend REST consumido por la app
- PostgreSQL (Supabase) — Base de datos del sistema
- Groq API (Whisper + Llama 3.2 Vision) — Procesamiento de audio e imágenes con IA
- flutter_local_notifications — Notificaciones locales en dispositivo

---

## Requisitos previos

- Flutter SDK instalado y configurado
- Android Studio o VS Code con la extensión de Flutter y Dart
- Dispositivo físico Android o emulador configurado
- Acceso al backend del proyecto levantado localmente o en Render

---

## Funcionalidades implementadas

- CU1 — Autenticación: login y registro con tokens JWT
- CU5 — Administrar vehículos asociados al perfil del cliente
- CU7 — Registro de emergencia multimodal: audio, imagen y GPS
- CU9 — Monitoreo del auxilio en tiempo real
- CU13 — Gestión de pagos del servicio
- CU15 — Notificaciones push locales

---

## Equipo de desarrollo

| Nombre | Codigo |
|---|---|
| Lopez Velazquez Marco Alejandro | 222008891 |

Materia: Sistemas de Informacion 2
Docente: Ing. Angelica Garzon Cuellar
Grupo: 25 — Semestre 1, 2026
