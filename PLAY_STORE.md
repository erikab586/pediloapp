# Play Store / release — pedilo

Checklist Sprint 4. Completar antes de publicar.

## 4.1 QA E2E (manual)

- [ ] Registro cliente → home
- [ ] Abrir comercio → bottom sheet → carrito
- [ ] Checkout (entrega → pago → confirmar) → éxito → tracking
- [ ] Pedir de nuevo desde home/tracking
- [ ] Perfil → Vender en pedilo → wizard
- [ ] Comerciante: promo + combo + horarios + abrir/cerrar

## 4.2 Parseo JSON

`parseJsonStringList` / `parseJsonMap` ya toleran string JSON vs array/objeto
para `metodosPago`, `tiposEntrega`, `horarios`.

## 4.3 Keystore release

1. Generar keystore (una sola vez):

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Copiar `android/key.properties.example` → `android/key.properties` y completar.
3. **No** commitear `*.jks` ni `key.properties`.
4. `build.gradle.kts` ya usa release signing si existe `key.properties`; si no, sigue en debug.

## 4.4 AAB

```bash
flutter build appbundle --release
```

Salida: `build/app/outputs/bundle/release/app-release.aab`

## 4.5 Ícono

Reemplazar launcher icons con un **logo cuadrado 1024×1024** (no el wordmark horizontal).
Herramienta sugerida: `flutter_launcher_icons`.

## 4.6 Políticas

Rutas in-app:

- `/legal/privacidad`
- `/legal/terminos`

Publicar las mismas URLs en Play Console (o hosting). Actualizar email de contacto.

## 4.7 Métricas

`AppAnalytics` loguea en debug: `home_open_comercio`, `add_to_cart`, `checkout_confirmed`.
Conectar a Firebase Analytics / Mixpanel cuando haya proyecto.

## FCM (post-Sprint)

Push real en background requiere Firebase + `google-services.json`. Hoy el “push” foreground usa Socket.IO + SnackBar.
