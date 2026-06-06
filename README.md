# Plataforma Inteligente de Emergencias Vehiculares — App Móvil

Bienvenido al repositorio de la aplicación móvil del sistema de atención de emergencias vehiculares, desarrollada como parte del proyecto integrador de la materia Sistemas de Información 2 en la Universidad Autónoma Gabriel René Moreno (UAGRM - FICCT), Grupo 30 segundo parcial, Gestión 2026.

Esta aplicación permite a los clientes reportar emergencias vehiculares en tiempo real, adjuntando audio, imágenes y ubicación GPS, y hacer seguimiento del servicio hasta su cierre y pago.

---

## Tecnologías utilizadas

- Flutter 3.x — Framework de desarrollo móvil multiplataforma
- Dart 3.x — Lenguaje de programación
- FastAPI — Backend REST consumido por la app
- PostgreSQL (Supabase) — Base de datos del sistema
- Groq API (Whisper + Llama 3.2 Vision) — Procesamiento de audio e imágenes con IA
- flutter_local_notifications — Notificaciones locales en dispositivo
- SharedPreferences / SQLite — Persistencia de datos para funcionamiento Offline

---

## Requisitos previos

- Flutter SDK instalado y configurado
- Android Studio o VS Code con la extensión de Flutter y Dart
- Dispositivo físico Android o emulador configurado
- Acceso al backend del proyecto levantado localmente o en Render

---

## Funcionalidades implementadas (Ciclo 1 al 3)

- CU1 — Autenticación: login y registro con tokens JWT
- CU5 — Administrar vehículos asociados al perfil del cliente
- CU7 — Registro de emergencia multimodal: audio, imagen y GPS
- CU9 — Monitoreo del auxilio en tiempo real
- CU13 — Gestión de pagos del servicio
- CU15 — Notificaciones push locales

---

## Funcionalidades implementadas (Ciclo 4 y Ciclo 5)

Durante el Ciclo 4 y 5 se incluyeron mejoras críticas orientadas a la experiencia del usuario, sincronización offline y analítica:

- **CU17: Canal de Comunicación en Tiempo Real**  
  Integración de WebSocket (`ws://`) en la pantalla de Monitoreo para escuchar el evento de `ubicacion` e inyectar las coordenadas del técnico directamente en el mapa interactivo en vivo.
- **CU18: Cotización y Selección de Taller**  
  Flujo interactivo donde el cliente puede visualizar ofertas (precio, nombre del taller, distancia) enviadas por los mecánicos y decidir si aceptarlas o rechazarlas desde la app.
- **CU19: Operación Offline y Sincronización (PWA/Móvil)**  
  Implementación de un sistema de caché local (`OfflineService`) y un interceptor de conectividad (`ConnectivityService`). Permite encolar emergencias cuando no hay internet y sincronizarlas automáticamente en background al reconectar, mostrando banners de advertencia y éxito.
- **CU21: Bitácora de Trazabilidad del Incidente**  
  Visualización de un timeline interactivo (`BitacoraService`) con el registro de eventos inmutables clave durante el ciclo de vida de la emergencia.
- **CU23: Calificación y Reputación Post-Servicio**  
  Pantalla interactiva de evaluación en estrellas que aparece tras finalizar el servicio, permitiendo al cliente valorar el desempeño del técnico mediante `CalificacionService`.
- **CU25: Asistente IA de Seguridad Vial en Espera**  
  Carrusel interactivo (`ConsejosSeguridadScreen`) mostrado al cliente mientras espera la llegada del técnico, con tips sugeridos dinámicamente según la criticidad de su emergencia evaluada por IA.

---

## Equipo de desarrollo

| Nombre | Registro |
|---|---|
| Lopez Velazquez Marco Alejandro | 222008891 |
| Matienzo Flores Juan Manuel | 222008970 |

Materia: Sistemas de Informacion 2  
Docente: Ing. Angelica Garzon Cuellar  
Grupo: 30 segundo parcial — Semestre 1, 2026
