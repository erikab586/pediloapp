# pedilo — Registro de conversación (UX, producto y avance)

Documento generado a partir de los últimos prompts de la sesión de trabajo.  
Contiene las preguntas del cliente/equipo y las respuestas del asistente, en formato legible para compartir o archivar.

**Proyecto:** `pedidosApp` (Flutter) + API NestJS  
**Fecha de referencia:** 7 de agosto de 2026

---

## Índice

1. [Mejoras UI/UX profesionales para marketplace](#1-mejoras-uiux-profesionales-para-marketplace)
2. [Maquetas, paleta y flujo “cliente primero → comerciante después”](#2-maquetas-paleta-y-flujo-cliente-primero--comerciante-después)
3. [Porcentaje de avance del proyecto](#3-porcentaje-de-avance-del-proyecto)
4. [Generación de APK para testing](#4-generación-de-apk-para-testing)
5. [Error 500 en GET /api/comercios/show](#5-error-500-en-get-apicomerciosshow)

---

## 1. Mejoras UI/UX profesionales para marketplace

### Prompt (usuario)

> Actuando con profesional frontend y profesional ui/ux que mejoras le puedo aplicar a esta app, sabiendo que quiero presentar una marketplace de diferentes rubros y quiero que sirva de enganche de cliente para generar la mayor cantidad de ventas, es pregunta leo tu propúesta quiero lo mas profeional posible que se facil uso pero sin perder los detalles de procesos

### Respuesta (asistente)

Propuesta profesional de **UI/UX + frontend** para **pedilo**, pensada como marketplace multi-rubro orientado a **conversión**, pero sin simplificar de más los procesos (pedido, pago, entrega, seguimiento).

La base actual ya está bien encaminada: design system (`AppColors`), home con categorías, detalle de comercio, carrito, checkout y tracking en vivo. Lo que falta es **profundidad comercial**, **confianza** y **personalización por rubro**.

---

#### 1. Principio rector: “Descubrir rápido, decidir con confianza, completar sin fricción”

Para un marketplace multi-rubro, el usuario pasa por 4 momentos:

```
Descubrir → Evaluar confianza → Agregar al carrito → Completar pedido → Repetir compra
```

Hoy la app cubre A→D, pero **B y E están débiles** (pocas señales de confianza, poco enganche post-compra).

---

#### 2. Home: de “lista de locales” a “centro de decisión”

**Lo que tenés hoy**
- Categorías horizontales, carrusel de `StoreCard`, banner promo estático (`PEDILO20`), ubicación fija “Montevideo”.

**Mejoras clave**

**A. Barra de ubicación real y editable**  
Hoy es decorativa. Debe abrir selector de dirección/zona. Impacto: en farmacia, ferretería y super, la disponibilidad por zona define la compra.

**B. Buscador sticky arriba (siempre visible al scroll)**  
Placeholder dinámico por rubro: *“Buscar hamburguesas”*, *“Buscar taladro”*, *“Buscar ibuprofeno”*.

**C. Secciones por intención, no solo “Locales destacados”**

| Bloque | Objetivo comercial |
|--------|--------------------|
| **Seguí tu pedido** (si hay activo) | Retención + reduce ansiedad |
| **Rubros** | Navegación multi-categoría |
| **Abiertos ahora** | Urgencia real |
| **Con promo hoy** | Conversión |
| **Más pedidos cerca tuyo** | Prueba social |
| **Nuevos en pedilo** | Descubrimiento |
| **Volver a pedir** | Repetición = ventas |

**D. `StoreCard` más “vendedor”**  
Hoy muestra nombre, rubro y `30-40 min` hardcodeado. Sumar: rating, distancia, badges promo, estado cerrado con CTA alternativo.

**E. Banner promo conectado al backend**  
El banner `20% OFF / PEDILO20` debería venir de cupones reales.

---

#### 3. Multi-rubro: misma app, experiencias distintas

| Rubro | Qué priorizar en UI |
|-------|---------------------|
| **Restaurante / comida** | Fotos grandes, combos, “pedir de nuevo”, tiempo estimado |
| **Super / farmacia** | Búsqueda por producto, categorías internas, stock |
| **Ferretería / inmobiliaria** | Ficha técnica, consulta, menos impulso visual |
| **Heladería / cafetería** | Upsell rápido, productos destacados arriba |

---

#### 4. Detalle de comercio: convertir sin perder información

**Fortalezas actuales:** Hero con portada, tabs Menú / Promos / Opiniones, agrupación por categoría, FAB carrito.

**Mejoras de alto impacto:**
- Sticky summary bar (Abierto · ⭐ · tiempo · mínimo · envío)
- Bottom sheet de producto (foto, cantidad, notas) en vez de solo “+”
- Opiniones y promos reales (hoy placeholder)
- Barra inferior fija: `2 items · $850 · Ver pedido`
- Comercio cerrado: permitir explorar menú + favoritos

---

#### 5. Checkout: simple por fuera, completo por dentro

- Stepper visual: Entrega → Pago → Confirmar
- Resumen sticky con total + botón Confirmar
- Microcopy de confianza (“Pagás al recibir”, etc.)
- Validaciones inline
- Pantalla post-checkout con número de pedido y “Seguir pedido”

---

#### 6. Tracking: convertir ansiedad en confianza

- Timeline visual con iconos
- Mensajes humanos por estado
- Acciones: llamar al comercio, cancelar, volver a pedir
- Push notifications al cambiar estado

---

#### 7. Navegación: menos tabs, más inteligencia

Propuesta: Inicio · Buscar · Pedidos · Perfil. **Carrito como FAB global** con badge.

---

#### 8. Confianza y conversión transversal

1. Skeleton loaders  
2. Empty states accionables  
3. Errores útiles (no solo mock fallback)  
4. Prueba social (“+120 pedidos este mes”)  
5. Favoritos con sección en home  
6. **Repetir pedido** (mayor driver de ventas)

---

#### 9. Design system

Paleta actual (amarillo `#FFC83D` + navy `#0D1B2A`) funciona. Estandarizar tokens y componentes: `ProductRow`, `OrderStatusChip`, `PriceSummary`, `TrustBadge`, `PromoPill`, `StickyCheckoutBar`.

---

#### 10. Onboarding

Quitar textos de “Prototipos UI/UX”. Mensaje: **“Pedí de todos los rubros, en un solo lugar”**. Cliente como camino principal.

---

#### 11. Roadmap

**Quick wins (1–2 semanas):** datos reales, StoreCard mejorada, sticky cart, skeleton, stepper checkout.

**Medio plazo (3–6 semanas):** bottom sheet producto, home por secciones, opiniones/promos, repetir pedido, push.

**Largo plazo:** recomendaciones, pedidos programados, chat comercio.

---

#### Conclusión UX

**pedilo** tiene el esqueleto correcto. El salto es: más confianza, menos pasos percibidos, contexto por rubro, más retención — manteniendo los detalles del proceso.

---

## 2. Maquetas, paleta y flujo “cliente primero → comerciante después”

### Prompt (usuario)

> la imagen 1 es la maqueta y paleta de colores que envio el cliente y la imagen 2y 3 una propuesta. Como seria el caso que todos los usuarios comerciantes entren por primera vez como cliente y luego si quieren ser comerciantes en boton dan click y se terminan de registrar

**Referencias visuales:**
- **Imagen 1:** Maqueta oficial pedilo — paleta amarillo `#FFC83D` + navy `#0D1B2A`, Poppins, flujo cliente (home, detalle Burger House, carrito, footer de valor).
- **Imagen 2:** Propuesta “App Pedido” — flujo cliente 9 pantallas, paleta roja (no usar como identidad final).
- **Imagen 3:** Propuesta marketplace — splash “Comenzar”, mapa tracking, paneles desktop comerciante/admin.

### Respuesta (asistente)

Excelente decisión de producto. Encaja mejor con un **marketplace multi-rubro** que obligar a elegir “Cliente” o “Comerciante” al abrir la app.

**Estado actual del código:**
- `RoleSelectionScreen` muestra 3 roles al inicio.
- Login valida `expectedRole` y bloquea si no coincide.
- Backend registra por defecto como **cliente** (`RegisterDto.role ?? RolTipo.CLIENTE`).
- Cada usuario tiene **un solo rol** (`role_id` en BD).

---

#### Modelo recomendado: “Una cuenta, dos modos”

```
Splash → Registro/Login Cliente → Home Cliente
         ↓
Perfil: "Vender en pedilo" → Wizard comercio → Admin aprueba
         ↓
Switcher Modo Comprador / Modo Comercio
```

**Idea central:** todos entran como compradores. Si quieren vender, completan un segundo paso desde Perfil.

---

#### 1. Pantalla de entrada (reemplaza selector de 3 roles)

| Elemento | Contenido |
|----------|-----------|
| Logo pedilo | Amarillo + navy |
| Claim | *“Lo que querés, cuando querés”* |
| CTA principal | **Comenzar** → registro cliente |
| CTA secundario | **Ya tengo cuenta** → login |
| Administrador | Acceso separado (no en app pública) |

---

#### 2. Registro inicial = solo Cliente

- Nombre, email, teléfono, contraseña  
- Backend: siempre `role: cliente`  
- Destino: Home Cliente (maqueta 1)

---

#### 3. Login único

| Rol en BD | Destino |
|-----------|---------|
| `cliente` | `/cliente/home` |
| `comerciante` | último modo usado o selector |
| `administrador` | `/admin/home` |

Quitar validación estricta `expectedRole` para usuarios normales.

---

#### 4. CTA en Perfil

```
🏪 Vender en pedilo
Publicá tu comercio y recibí pedidos en vivo
[ Registrar mi comercio ]
```

---

#### 5. Wizard “Convertirme en comerciante”

| Paso | Datos |
|------|-------|
| 1. Tu negocio | Nombre, rubro, descripción |
| 2. Ubicación | Dirección, teléfono local |
| 3. Operación | Horarios, retiro/delivery, pagos |
| 4. Identidad visual | Logo, portada |
| 5. Confirmación | Solicitud → estatus **pendiente** |

Pantalla final: “Solicitud enviada — podés seguir comprando mientras revisamos.”

---

#### 6. Backend necesario

**Opción A (MVP recomendada):**
1. `POST /comercios/register` → comercio `pendiente`
2. `PATCH /users/me/promote-comerciante` → rol `cliente` → `comerciante`
3. Admin aprueba → `aprobado`

**Opción B (futuro):** roles múltiples por usuario.

---

#### 7. Switcher de modo

```
[ 🛒 Modo comprador ]  |  [ 🏪 Modo comercio ]
```

Un comerciante **también compra**. Guardar último modo en `SharedPreferences`.

---

#### 8. Estados del comerciante

| Estado | Qué ve el usuario |
|--------|-------------------|
| Sin solicitud | Card “Registrar mi comercio” |
| Pendiente | “Tu solicitud está en revisión” |
| Aprobado | Switcher + panel comerciante |
| Rechazado | Motivo + reenviar |

---

#### 9. Qué usar de cada imagen

| Imagen | Uso |
|--------|-----|
| **Maqueta 1** | Paleta, home, detalle, carrito — **base principal** |
| **Propuesta 2** | Flujo 9 pantallas cliente — **referencia de procesos** |
| **Propuesta 3** | Splash, mapa tracking, favoritos — **inspiración** |

**No usar:** selector 3 roles al inicio, paleta roja, enfoque 100% comida.

---

#### 10. Cambios vs app actual

| Área | Hoy | Propuesto |
|------|-----|-----------|
| `RoleSelectionScreen` | 3 roles | Splash + login/registro cliente |
| `RegisterScreen` | Rol por URL | Siempre cliente |
| `LoginScreen` | Valida rol esperado | Login único + redirect JWT |
| `ClientePerfilTab` | Básico | + “Vender en pedilo” |
| Nueva pantalla | — | `ComercianteOnboardingWizard` |
| Backend | Rol fijo | Endpoint promote comerciante |

---

## 3. Porcentaje de avance del proyecto

### Prompt (usuario)

> Entonces en funcion de lo que tenermos y queremos mejorar cuanto seria el porcentaje de avance

### Respuesta (asistente)

#### Resumen ejecutivo

| Métrica | Avance estimado |
|--------|------------------|
| **MVP funcional técnico** (3 roles, flujos conectados a API) | **~68–72%** |
| **Visión comercial completa** (marketplace + UX maqueta + onboarding unificado) | **~55–58%** |
| **Fidelidad a maqueta cliente (imagen 1)** | **~62%** |
| **Listo para producción real** | **~50%** |

**Número único recomendado para presentar al cliente:**  
> **~60% de avance global** hacia el producto final deseado.

---

#### Desglose por módulo

**App Cliente (~58%)**

| Área | % aprox. |
|------|----------|
| Home | 65% |
| Buscar | 60% |
| Detalle comercio | 55% |
| Carrito | 70% |
| Checkout | 65% |
| Pedidos + tracking | 60% |
| Perfil / direcciones / favoritos | 65% |
| Detalle producto (bottom sheet) | 0% |
| Rating / repetir pedido / push | 0–10% |
| Señales de confianza | 30% |

**App Comerciante (~68%)**

| Área | % aprox. |
|------|----------|
| Dashboard | 75% |
| Pedidos | 80% |
| Productos | 75% |
| Ventas | 70% |
| Mi local | 70% |
| Combos | 70% |
| Promociones UI | ~20% |
| Horarios / notificaciones | ~35% |

**App Admin (~79%)**

| Área | % aprox. |
|------|----------|
| Dashboard | 80% |
| Comercios | 85% |
| Usuarios | 80% |
| Reportes | 75% |
| Config | 75% |

**Auth y modelo de entrada (~25% hacia objetivo)**

| Hoy | Objetivo |
|-----|----------|
| Selector 3 roles | Splash + solo cliente |
| Login por rol | Login único |
| Registro comerciante aparte | Upgrade desde Perfil |
| Sin switcher | Modo dual |

**UX vs maqueta 1 (~55%)**

**Backend (~70% código / ~50% producción)** — bloqueante: migración BD columna `estatus`.

---

#### Cálculo ponderado

```
Cliente      58% × 40% = 23.2
Comerciante  68% × 25% = 17.0
Admin        79% × 15% = 11.9
Auth modelo  25% × 10% =  2.5
UX maqueta   55% × 10% =  5.5
─────────────────────────────
Total aproximado      = 60.1%
```

---

#### Cómo comunicarlo (3 niveles)

1. **“¿Está hecha la app?”** → **~70%** (tres perfiles, circuito pedido en dev)
2. **“¿Lista para vender como marketplace profesional?”** → **~55–60%**
3. **“¿Cuánto falta para Play Store?”** → **~40% restante**

| Bloque restante | Esfuerzo |
|-----------------|----------|
| Fix producción + datos reales | ~5% |
| UX cliente (maqueta 1) | ~15% |
| Modelo cliente primero → comerciante | ~8% |
| Promos, opiniones, push | ~7% |
| QA, firma, AAB Play Store | ~5% |

---

#### Gráfico de avance

```
[████████████████████░░░░░░░░░░] 60%  Visión completa pedilo
[██████████████████████░░░░░░░░] 70%  MVP funcional técnico
[███████████████████░░░░░░░░░░░] 62%  Maqueta cliente (img. 1)
[██████████░░░░░░░░░░░░░░░░░░░░] 25%  Nuevo modelo de entrada
[████████████████████████░░░░░░] 79%  Panel admin
```

---

#### Prioridades para subir el porcentaje

1. Backend producción (migración `estatus`)  
2. Pulido home + detalle comercio (confianza + carrito sticky)  
3. Onboarding unificado (cliente primero)  
4. Promos + opiniones reales  

---

## 4. Generación de APK para testing

### Prompt (usuario)

> como hago para generar una apk, de modo que la podamos testear antes de subir a play store este es el logo de la apk

### Respuesta (asistente) — resumen de acciones realizadas

**Requisitos:** Flutter + Android SDK (verificado con `flutter doctor`).

**Configurar ícono:**
```yaml
# pubspec.yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.3

flutter_launcher_icons:
  android: true
  ios: false
  image_path: assets/images/app_icon.png
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: assets/images/app_icon.png
```

```powershell
dart run flutter_launcher_icons
```

**Generar APK release:**
```powershell
cd pedidosApp
flutter pub get
flutter build apk --release
```

**Salida:** `build\app\outputs\flutter-apk\app-release.apk` (~54.6 MB)

**Instalación:** copiar al celular o `adb install build\app\outputs\flutter-apk\app-release.apk`

**Play Store:** usar `flutter build appbundle --release` (AAB) con keystore propio (hoy release usa firma debug para testing interno).

---

## 5. Error 500 en GET /api/comercios/show

### Prompt (usuario)

> curl GET http://187.127.44.110:3000/api/comercios/show?page=1&limit=20 → 500 Internal Server Error

### Respuesta (asistente)

**Causa probable:** desfase entre código y base de datos en producción.

- El backend espera columna **`estatus`** (enum PostgreSQL).
- La BD del servidor aún tiene esquema viejo con **`aprobado boolean`**.
- Query falla: `column c.estatus does not exist` → NestJS devuelve 500.

**Verificación hecha:**
- `/api/categorias/show` → 200 OK  
- `/api/comercios/show` → 500  
- `/api/comercios/show/1` → 500  
- `/api/productos/show?comercioId=5` → 500 (join con comercios)

**Solución:**
```bash
psql -U pedilo_user -d pedilo -h 127.0.0.1 -f database/migrations/004_comercios_estatus.sql
```
Reiniciar API y probar de nuevo.

**Después de migrar:** solo listará comercios con `estatus` `aprobado` o `activo`.

---

## Notas técnicas del repo (contexto)

- **App Flutter:** `pedidosApp/`
- **API NestJS:** `../apis/`
- **API base:** `http://187.127.44.110:3000/api`
- **Design system:** `lib/core/theme/app_colors.dart`
- **Roles actuales:** cliente, comerciante, administrador (`lib/features/auth/domain/user_role.dart`)

---

*Este archivo es un registro de conversación para documentación interna. No reemplaza la documentación técnica de instalación ni despliegue.*
