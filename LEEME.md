# 🔬 BioLab Suite v7.0 — LABSYNC Enterprise

BioLab v7.0 es el sistema operativo digital del laboratorio bajo la arquitectura LABSYNC Enterprise. Diseñado para trabajo offline-first de alta seguridad, auditoría completa y sincronización distribuida.

## 🚀 Inicio Rápido

1.  Ejecuta **`Iniciar BioLab.bat`**.
2.  El sistema abrirá tu navegador automáticamente y correrá de forma **oculta** en segundo plano.
3.  **Administración**: `admin` / PIN: `1234` / Contraseña: `admin`.

---

## ✨ Novedades de la v7.0 (LABSYNC Enterprise)

### 1. 📤 Módulo Global de Reportes
- **Formatos Profesionales**: Exporta todos tus registros o módulos específicos a **CSV** (para Excel/análisis) y **HTML** (listo para imprimir/PDF).
- **Auto-guardado en PC**: Si tienes el servidor local activo, los reportes se guardan de forma automática y silenciosa en tu disco local bajo la carpeta configurada (organizados por `Año \ Mes_Nombre`).
- **Resumen Mensual**: Genera un archivo `.txt` con un consolidado de actividades y los datos brutos en JSON para respaldos.

### 2. 🚦 Barra de Estado en Tiempo Real (StatusBar)
- Una barra en la parte superior te muestra el progreso de captura diaria, el estado de los equipos, el usuario activo y el ID de dispositivo único.

### 3. 🔔 Sistema de Notificaciones Toast
- Retroalimentación inmediata con animaciones fluidas ante cada acción de guardado, error, cierre o justificación.

### 4. 🔍 Historial Avanzado
- Búsqueda inteligente por texto en los campos de los formularios.
- Filtros rápidos por rango de fechas y módulo específico.

### 5. 🔄 Cola de Sincronización Integrada (SyncQueue)
- Estructuración de cola de cambios pendientes en segundo plano. Registra todas las transacciones locales (guardados, justificaciones, auditoría, etc.) y muestra en la barra de estado cuántos cambios están listos para subirse a la nube una vez que el backend FastAPI esté activo.
- Permite forzar una sincronización (simulada en esta fase) con animación en tiempo real.

### 6. 🛠️ Robustez y Corrección de Errores
- Corregido el bug que duplicaba el historial de cierres de días.
- Registro automatizado de Service Worker con caché v7.0 para garantizar el funcionamiento offline-first absoluto.

---

## 🛠️ Estructura del Proyecto

- `index.html`: La interfaz y lógica de la SPA.
- `service-worker.js`: Controlador de caché y soporte offline.
- `manifest.json`: Configuración PWA del sistema.
- `server.ps1`: Servidor local seguro y API de archivos en PowerShell.
- `Iniciar BioLab.bat`: Lanzador con apagado automático del servidor anterior.
- `LEEME.md`: Esta guía.
- `AI_CONTEXT_README.md`: Documentación técnica y credenciales por defecto.

---
**Desarrollado por Antigravity AI**
*Actualizado: 20 de Mayo de 2026*
