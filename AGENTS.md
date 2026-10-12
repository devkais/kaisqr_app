# Instrucciones para agentes

## Restricción del usuario
- **No hacer testing**: no crear, modificar ni ejecutar tests; tampoco agregar infraestructura de testing, salvo petición explícita posterior. La presencia de `test/` y `flutter_test` no cambia esta instrucción. Usar formato y análisis estático para verificar cambios de Dart.

## Comandos y plataforma
- Ejecutar desde la raíz. `pubspec.yaml` requiere Dart `^3.13.0`; el lockfile actual requiere Flutter `>=3.44.0`.
- Dependencias: `flutter pub get`. Desarrollo: `flutter run -d <device-id>`.
- Verificación sin tests: `dart format <archivos.dart modificados>` y luego `flutter analyze`; análisis acotado: `flutter analyze lib/features/<feature>`.
- APK ARM64 release: `./build_arm64_release.ps1` en PowerShell; ejecuta `flutter build apk --release --target-platform android-arm64 --split-per-abi`.
- **Release Android usa el keystore configurado en `android/key.properties`** mediante `android/app/build.gradle.kts`; mantener ese archivo y el keystore fuera de Git.
- Los runners existentes son Android/iOS; captura y uploads usan `dart:io` y archivos locales. No asumir compatibilidad web.
- `analysis_options.yaml` excluye los directorios nativos: `flutter analyze` no verifica cambios de Android/iOS.

## Configuración del backend
- `main()` espera `AppConfig.load()` antes de construir clientes y arrancar `AppRoot`. No reemplazarlo por `AppConfig.fromEnvironment()`: esa factory no lee el asset.
- Claves: `KAISQR_API_URL`, `KAISQR_WS_URL`, `KAISQR_API_KEY`. Precedencia de valores no vacíos: `--dart-define` > `assets/config/app.env` > defaults de `lib/core/config/app_config.dart`. No se leen variables del shell como configuración runtime.
- `assets/config/app.env` está versionado y empaquetado en la app: no colocar secretos de producción allí. Para cambiar endpoints localmente, preferir `flutter run -d <device-id> --dart-define=KAISQR_API_URL=<url> --dart-define=KAISQR_WS_URL=<url>`.
- Los defaults apuntan a una IP LAN, no a un backend incluido en este repo. API y WebSocket tienen bases distintas (`/api/v1` y `/api/v1/ws/v1`); revisar ambas al cambiar de servidor.
- HTTP/WS sin TLS está habilitado mediante `android:usesCleartextTraffic` en el manifest y `NSAllowsArbitraryLoads` en iOS. No retirar estas excepciones sin coordinar el cambio de endpoints.

## Flujo y contratos que conviene preservar
- `lib/main.dart` construye `ApiClient`, `WebSocketClient` y `SalaService` y los inyecta por constructores. `HomeView` crea y dispone `SalaController`; captura reutiliza ese controlador de sala. El estado usa `ChangeNotifier`, sin contenedor global de DI.
- `SalaController` reconecta al volver a primer plano; `CaptureController` también reconecta tras la galería y recupera archivos con `retrieveLostData()`. Preservar estos caminos al tocar cámara, navegación o lifecycle.
- Salir de una sala llama al cierre remoto además de cerrar el socket; un evento terminal del servidor hace solo cierre local. No confundir `salirSala()`, `finalizarSala()` y `SalaService.cerrarSala()`.
- El envío es secuencial, omite documentos ya enviados y finaliza la sala solo después de subir todos. Conservar esa lógica para evitar duplicados al reintentar.
- La captura PDF produce **imágenes por página**, no un PDF local. Se suben con `tipo_archivo=pdf`, `lote_pdf_id` y `nombre_pdf`; mantener estos metadatos a través de controller → service → `ApiClient`.
- Las páginas PDF se recortan localmente y conservan `archivoOriginal` para reedición; el archivo enviado usa un polígono completo para no repetir el recorte. Los puntos de recorte son normalizados, no píxeles (`ImageCropService`).
- Autenticación en `ApiClient`: unión por código usa `X-API-Key`; uploads y operaciones de sala usan `X-Session-Token`. Mantener los nombres de campos multipart del backend, no derivarlos de los nombres Dart.
