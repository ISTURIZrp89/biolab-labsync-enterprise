# BioLab — LABSYNC Enterprise v7.0

Sistema operativo digital de laboratorio con arquitectura LABSYNC Enterprise.

## Credenciales por defecto

| Usuario | Rol | PIN | Contraseña |
|---|---|---|---|
| Administrador | ADMIN | 1234 | admin |
| Dr. Alberto Parra Barrera | JEFE | 0000 | biolab |
| Técnicos (demás) | LABORATORIO | 0000 | — |

## Roles del Sistema

| Rol | Permisos |
|---|---|
| ADMIN | Control total, usuarios, auditoría |
| JEFE | Captura, cierre/reapertura de días, auditoría |
| LABORATORIO | Captura de formularios |
| AUDITOR | Solo lectura + auditoría |
| DUEÑO | Dashboard + auditoría |

## Calendario Operativo — Colores

- 🟢 **COMPLETO** — Todos los módulos del día están registrados
- 🟡 **PENDIENTE** — Algunos módulos registrados, día en curso
- 🔴 **VENCIDO** — Día pasado sin registros completos
- ⚫ **NO APLICA** — Día justificado administrativamente
- 🔒 **CERRADO** — Cierre formal del día
- 🔵 **CERRADO CON OBSERVACIÓN** — Cierre con nota

## Módulos

- Incubadoras (🌡️)
- Ultracongeladores (🧊)
- Autoclave (⚗️)
- Ambiental (📡)
- Equipos (🔬)
- Procesamiento (⚙️)
- Bitácora Diaria (📝)

## Arquitectura LABSYNC

- **Offline-first**: localStorage con esquema versionado
- **Device ID**: Identificador único por nodo
- **Auditoría completa**: Cada acción queda registrada con UUID, usuario, device_id y timestamp UTC
- **Cierre diario**: Estados formales con historial de reaperturas
- **Roles**: Control de acceso por función

## Lanzar el sistema

Doble clic en `Iniciar BioLab.bat`

---
*Mantenido por Antigravity AI — LABSYNC Enterprise v7.0*
