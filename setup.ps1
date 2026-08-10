# Ejecutar una sola vez para completar android/ios y dependencias.
# Requiere Flutter SDK en PATH: https://docs.flutter.dev/get-started/install

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "Verificando Flutter..." -ForegroundColor Cyan
flutter --version

Write-Host "Completando plataformas (android, ios)..." -ForegroundColor Cyan
flutter create . --project-name pedidos_app --org com.pedilo --platforms=android,ios

Write-Host "Instalando dependencias..." -ForegroundColor Cyan
flutter pub get

Write-Host "Generando splash nativo (#0D1B2A)..." -ForegroundColor Cyan
dart run flutter_native_splash:create

Write-Host ""
Write-Host "Listo. Ejecutar con: flutter run" -ForegroundColor Green
