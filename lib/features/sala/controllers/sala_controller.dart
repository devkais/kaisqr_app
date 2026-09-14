import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../models/evento_sala.dart';
import '../models/sala.dart';
import '../services/sala_service.dart';

class SalaController extends ChangeNotifier with WidgetsBindingObserver {
  SalaController(this._salaService) {
    WidgetsBinding.instance.addObserver(this);
  }

  final SalaService _salaService;
  StreamSubscription<EventoSala>? _eventSubscription;

  Sala? salaActual;
  bool cargando = false;
  bool enviando = false;
  String mensajeEstado = 'Ingresa un código o escanea un QR para comenzar.';
  String? mensajeError;
  int cantidadDocumentos = 0;
  bool _reconectando = false;
  bool _saliendo = false;

  static const Set<String> _estadosTerminales = <String>{
    'cerrada',
    'completada',
    'expirada',
    'error',
  };

  bool get salaConectada => salaActual != null;

  Future<void> unirsePorCodigo(String codigo) async {
    final codigoNormalizado = codigo.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(codigoNormalizado)) {
      mensajeError = 'El código debe tener exactamente 6 números.';
      notifyListeners();
      return;
    }

    await _ejecutarIngreso(
      () => _salaService.unirsePorCodigo(codigoNormalizado),
    );
  }

  Future<void> unirsePorQr(String contenidoQr) async {
    await _ejecutarIngreso(() async => _salaService.unirsePorQr(contenidoQr));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && salaActual != null) {
      unawaited(reconectarSala());
    }
  }

  Future<void> reconectarSala() async {
    final sala = salaActual;
    if (sala == null || _reconectando || _saliendo) return;

    _reconectando = true;
    try {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      await _salaService.cerrarSala();

      final eventos = await _salaService.conectarSala(sala);
      _eventSubscription = eventos.listen(
        _procesarEvento,
        onError: (Object error) {
          mensajeError = _obtenerMensajeError(error);
          mensajeEstado = 'La conexión de la sala tuvo un problema.';
          notifyListeners();
        },
        onDone: () {
          if (!_saliendo && salaActual != null) {
            mensajeEstado = 'Conexión temporalmente interrumpida.';
            notifyListeners();
          }
        },
      );
      mensajeError = null;
      mensajeEstado = 'Sala reconectada. Puedes continuar capturando.';
    } catch (error) {
      mensajeError = _obtenerMensajeError(error);
      mensajeEstado = 'No fue posible reconectar la sala.';
    } finally {
      _reconectando = false;
      notifyListeners();
    }
  }

  Future<void> enviarDocumento(
    File archivo, {
    String tipoArchivo = 'imagen',
    List<Map<String, double>>? poligono,
    String? nombrePersonalizado,
    String? lotePdfId,
    String? nombrePdf,
  }) async {
    final sala = salaActual;
    if (sala == null) throw StateError('No existe una sala activa');

    await _salaService.registrarDocumento(
      sala: sala,
      archivo: archivo,
      tipoArchivo: tipoArchivo,
      poligono: poligono,
      nombrePersonalizado: nombrePersonalizado,
      lotePdfId: lotePdfId,
      nombrePdf: nombrePdf,
    );
    cantidadDocumentos += 1;
    mensajeEstado = 'Documento enviado ($cantidadDocumentos).';
    notifyListeners();
  }

  Future<void> finalizarSala() async {
    final sala = salaActual;
    if (sala == null) throw StateError('No existe una sala activa');

    enviando = true;
    mensajeError = null;
    mensajeEstado = 'Finalizando la sala...';
    notifyListeners();

    try {
      final respuesta = await _salaService.finalizarSala(sala);
      mensajeEstado =
          respuesta['mensaje']?.toString() ?? 'Sala finalizada correctamente.';
    } catch (error) {
      mensajeError = _obtenerMensajeError(error);
      rethrow;
    } finally {
      enviando = false;
      notifyListeners();
    }
  }

  void limpiarError() {
    mensajeError = null;
    notifyListeners();
  }

  Future<void> salirSala() async {
    if (_saliendo) return;
    if (salaActual == null && _eventSubscription == null) return;
    _saliendo = true;
    final sala = salaActual;
    try {
      if (sala != null) {
        try {
          await _salaService
              .cerrarSalaRemotamente(sala)
              .timeout(const Duration(seconds: 3));
        } catch (_) {
          // La vista debe cerrarse aunque el servidor no responda.
        }
      }
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      await _salaService.cerrarSala();
    } catch (_) {
      // El cierre local de la vista no debe depender de que el socket responda.
    } finally {
      salaActual = null;
      cantidadDocumentos = 0;
      mensajeEstado = 'Sala cerrada.';
      _saliendo = false;
      notifyListeners();
    }
  }

  Future<void> _ejecutarIngreso(Future<Sala> Function() ingresar) async {
    cargando = true;
    mensajeError = null;
    mensajeEstado = 'Conectando con la sala...';
    notifyListeners();

    try {
      await _eventSubscription?.cancel();
      final sala = await ingresar();
      salaActual = sala;
      _saliendo = false;
      final eventos = await _salaService.conectarSala(sala);
      _eventSubscription = eventos.listen(
        _procesarEvento,
        onError: (Object error) {
          mensajeError = _obtenerMensajeError(error);
          notifyListeners();
        },
        onDone: () {
          if (!_saliendo && salaActual != null) {
            mensajeEstado = 'Conexión temporalmente interrumpida.';
            notifyListeners();
          }
        },
      );
      mensajeEstado = 'Conectado. Esperando documentos.';
    } catch (error) {
      salaActual = null;
      mensajeError = _obtenerMensajeError(error);
      mensajeEstado = 'No fue posible conectarse a la sala.';
    } finally {
      cargando = false;
      notifyListeners();
    }
  }

  void _procesarEvento(EventoSala evento) {
    if (evento.tipo == 'sala_conectada') {
      mensajeEstado = 'Sala conectada. Ya puedes capturar documentos.';
    } else if (evento.tipo == 'documento_recibido') {
      cantidadDocumentos = evento.cantidadDocumentos ?? cantidadDocumentos;
      mensajeEstado = 'El servidor recibió un documento.';
    } else if (evento.tipo == 'estado_sala') {
      mensajeEstado = evento.mensaje ?? evento.estado ?? mensajeEstado;
      if (_estadosTerminales.contains(evento.estado)) {
        unawaited(_cerrarPorEventoTerminal(mensajeEstado));
      }
    }
    notifyListeners();
  }

  Future<void> _cerrarPorEventoTerminal(String mensaje) async {
    if (_saliendo) return;
    _saliendo = true;

    try {
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      await _salaService.cerrarSala();
    } catch (_) {
      // El cierre local de la vista no debe depender de que el socket responda.
    } finally {
      salaActual = null;
      cantidadDocumentos = 0;
      mensajeEstado = mensaje;
      _saliendo = false;
      notifyListeners();
    }
  }

  String _obtenerMensajeError(Object error) {
    final texto = error.toString();
    return texto.startsWith('ApiException') ? texto.split(': ').last : texto;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_eventSubscription?.cancel());
    unawaited(_salaService.cerrarSala());
    super.dispose();
  }
}
