import 'dart:convert';
import 'dart:io';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/web_socket_client.dart';
import '../models/evento_sala.dart';
import '../models/sala.dart';

class SalaService {
  SalaService({
    required this.apiClient,
    required this.webSocketClient,
    required this.config,
  });

  final ApiClient apiClient;
  final WebSocketClient webSocketClient;
  final AppConfig config;

  Future<Sala> unirsePorCodigo(String codigo) async {
    final respuesta = await apiClient.postJson(
      'salas/unirse',
      body: <String, dynamic>{'codigo': codigo},
      includeApiKey: true,
    );
    return Sala.desdeRespuestaServidor(respuesta, config.webSocketUrl);
  }

  Sala unirsePorQr(String contenidoQr) {
    final dynamic payload = jsonDecode(contenidoQr);
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('El contenido del QR no es válido');
    }
    return Sala.desdePayloadQr(payload, config.webSocketUrl);
  }

  Future<Stream<EventoSala>> conectarSala(Sala sala) async {
    final eventos = webSocketClient
        .connect(sala.websocketUrl)
        .map(EventoSala.desdeJson);
    await webSocketClient.waitUntilReady();
    return eventos;
  }

  Future<Map<String, dynamic>> registrarDocumento({
    required Sala sala,
    required File archivo,
    String tipoArchivo = 'imagen',
    List<Map<String, double>>? poligono,
    String? nombrePersonalizado,
    String? lotePdfId,
    String? nombrePdf,
  }) {
    return apiClient.uploadFile(
      path: 'salas/${sala.salaId}/documentos',
      file: archivo,
      sessionToken: sala.token,
      tipoArchivo: tipoArchivo,
      poligono: poligono,
      personalizedName: nombrePersonalizado,
      lotePdfId: lotePdfId,
      nombrePdf: nombrePdf,
    );
  }

  Future<Map<String, dynamic>> finalizarSala(Sala sala) {
    return apiClient.postJson(
      'salas/${sala.salaId}/finalizar',
      body: <String, dynamic>{},
      sessionToken: sala.token,
    );
  }

  Future<Map<String, dynamic>> cerrarSalaRemotamente(Sala sala) {
    return apiClient.postJson(
      'salas/${sala.salaId}/cerrar',
      body: <String, dynamic>{},
      sessionToken: sala.token,
    );
  }

  Future<void> cerrarSala() => webSocketClient.close();
}
