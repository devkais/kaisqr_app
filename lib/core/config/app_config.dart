import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppConfig {
  const AppConfig({
    required this.apiUrl,
    required this.webSocketUrl,
    required this.apiKey,
  });

  final String apiUrl;
  final String webSocketUrl;
  final String apiKey;

  static const String _assetPath = 'assets/config/app.env';
  static const String _defaultApiUrl = 'http://192.168.88.85:8000/api/v1';
  static const String _defaultWebSocketUrl =
      'ws://192.168.88.85:8000/api/v1/ws/v1';
  static const String _defaultApiKey = 'development-key';

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      apiUrl: String.fromEnvironment(
        'KAISQR_API_URL',
        defaultValue: _defaultApiUrl,
      ),
      webSocketUrl: String.fromEnvironment(
        'KAISQR_WS_URL',
        defaultValue: _defaultWebSocketUrl,
      ),
      apiKey: String.fromEnvironment(
        'KAISQR_API_KEY',
        defaultValue: _defaultApiKey,
      ),
    );
  }

  static Future<AppConfig> load() async {
    Map<String, String> valores = <String, String>{};
    try {
      final contenido = await rootBundle.loadString(_assetPath);
      valores = _parsearArchivo(contenido);
    } on FlutterError {
      // Se mantienen los valores por defecto si el asset no está disponible.
    }

    return AppConfig(
      apiUrl: _obtenerValor(
        'KAISQR_API_URL',
        valores,
        _defaultApiUrl,
        String.fromEnvironment('KAISQR_API_URL'),
      ),
      webSocketUrl: _obtenerValor(
        'KAISQR_WS_URL',
        valores,
        _defaultWebSocketUrl,
        String.fromEnvironment('KAISQR_WS_URL'),
      ),
      apiKey: _obtenerValor(
        'KAISQR_API_KEY',
        valores,
        _defaultApiKey,
        String.fromEnvironment('KAISQR_API_KEY'),
      ),
    );
  }

  static Map<String, String> _parsearArchivo(String contenido) {
    final valores = <String, String>{};
    for (final linea in contenido.split('\n')) {
      final texto = linea.trim();
      if (texto.isEmpty || texto.startsWith('#')) continue;

      final separador = texto.indexOf('=');
      if (separador <= 0) continue;

      final clave = texto.substring(0, separador).trim();
      var valor = texto.substring(separador + 1).trim();
      if (valor.length >= 2 &&
          ((valor.startsWith('"') && valor.endsWith('"')) ||
              (valor.startsWith("'") && valor.endsWith("'")))) {
        valor = valor.substring(1, valor.length - 1);
      }
      valores[clave] = valor;
    }
    return valores;
  }

  static String _obtenerValor(
    String clave,
    Map<String, String> valores,
    String valorPorDefecto,
    String valorCompilacion,
  ) {
    if (valorCompilacion.trim().isNotEmpty) return valorCompilacion.trim();
    final valorArchivo = valores[clave]?.trim();
    return valorArchivo == null || valorArchivo.isEmpty
        ? valorPorDefecto
        : valorArchivo;
  }
}
