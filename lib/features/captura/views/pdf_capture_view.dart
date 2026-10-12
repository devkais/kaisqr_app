import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/documento_capturado.dart';
import '../services/image_crop_service.dart';
import 'camera_capture_view.dart';
import 'polygon_editor_view.dart';

class PdfCaptureView extends StatefulWidget {
  const PdfCaptureView({super.key});

  @override
  State<PdfCaptureView> createState() => _PdfCaptureViewState();
}

class _PdfCaptureViewState extends State<PdfCaptureView> {
  final List<DocumentoCapturado> _paginas = <DocumentoCapturado>[];
  final ImageCropService _imageCropService = ImageCropService();
  late final String _lotePdfId;
  late final TextEditingController _nombrePdfController;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    _lotePdfId = 'lote_$timestamp';
    _nombrePdfController = TextEditingController(text: 'documento_$timestamp');
  }

  @override
  void dispose() {
    _nombrePdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear PDF'),
        actions: <Widget>[
          TextButton(
            onPressed: _paginas.isEmpty ? null : _aceptarPaginas,
            child: const Text('Listo'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_paginas.isNotEmpty) _buildNombrePdf(),
          Expanded(
            child: _paginas.isEmpty ? _buildEstadoVacio() : _buildPaginas(),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ElevatedButton.icon(
            onPressed: _cargando ? null : _agregarPagina,
            icon: _cargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined),
            label: Text(_cargando ? 'Preparando...' : 'Agregar página'),
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoVacio() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.picture_as_pdf_outlined, size: 76),
            SizedBox(height: 16),
            Text(
              'Agrega la primera página',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Cada fotografía se convertirá en una página del PDF. Después podrás ajustar sus esquinas.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginas() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _paginas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final pagina = _paginas[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(8),
            leading: SizedBox(
              width: 76,
              height: 96,
              child: Image.file(pagina.archivo, fit: BoxFit.cover),
            ),
            title: Text('Página ${index + 1}'),
            subtitle: const Text('Recorte editable'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  onPressed: _cargando ? null : () => _editarPagina(index),
                  icon: const Icon(Icons.crop_rounded),
                  tooltip: 'Editar recorte',
                ),
                IconButton(
                  onPressed: _cargando ? null : () => _eliminarPagina(index),
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Eliminar página',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNombrePdf() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        controller: _nombrePdfController,
        enabled: !_cargando,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Nombre del PDF',
          hintText: 'Ejemplo: contrato_cliente',
          suffixText: '.pdf',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.edit_outlined),
        ),
      ),
    );
  }

  Future<void> _agregarPagina() async {
    setState(() => _cargando = true);
    try {
      final imagenes = await Navigator.of(context).push<List<XFile>>(
        MaterialPageRoute<List<XFile>>(
          builder: (_) => const CameraCaptureView(
            titulo: 'Capturar páginas',
            permitirVarias: true,
          ),
        ),
      );
      if (!mounted || imagenes == null || imagenes.isEmpty) return;

      for (final imagen in imagenes) {
        if (!mounted) return;
        final pagina = await _prepararPagina(File(imagen.path));
        if (!mounted || pagina == null) break;
        setState(() => _paginas.add(pagina));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo recortar la página: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<DocumentoCapturado?> _prepararPagina(File archivo) async {
    final poligono = await Navigator.of(context).push<List<PuntoPoligono>>(
      MaterialPageRoute<List<PuntoPoligono>>(
        builder: (_) => PolygonEditorView(archivo: archivo),
      ),
    );
    if (!mounted || poligono == null) return null;

    final archivoRecortado = await _imageCropService.recortarDocumento(
      archivo: archivo,
      poligono: poligono,
    );
    return DocumentoCapturado(
      archivo: archivoRecortado,
      archivoOriginal: archivo,
      nombre: _crearNombrePagina(),
      tipoArchivo: TipoArchivo.pdf,
      lotePdfId: _lotePdfId,
      poligono: _poligonoCompleto(),
    );
  }

  Future<void> _editarPagina(int indice) async {
    final pagina = _paginas[indice];
    final archivoOriginal = pagina.archivoOriginal;
    final poligono = await Navigator.of(context).push<List<PuntoPoligono>>(
      MaterialPageRoute<List<PuntoPoligono>>(
        builder: (_) => PolygonEditorView(archivo: archivoOriginal),
      ),
    );
    if (!mounted || poligono == null) return;

    setState(() => _cargando = true);
    try {
      final archivoRecortado = await _imageCropService.recortarDocumento(
        archivo: archivoOriginal,
        poligono: poligono,
      );
      if (!mounted) return;

      setState(() {
        _paginas[indice] = DocumentoCapturado(
          archivo: archivoRecortado,
          archivoOriginal: archivoOriginal,
          nombre: pagina.nombre,
          tipoArchivo: TipoArchivo.pdf,
          lotePdfId: pagina.lotePdfId ?? _lotePdfId,
          nombrePdf: pagina.nombrePdf,
          poligono: _poligonoCompleto(),
        );
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo recortar la página: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _eliminarPagina(int indice) {
    setState(() => _paginas.removeAt(indice));
  }

  void _aceptarPaginas() {
    final nombrePdf = _obtenerNombrePdf();
    final paginas = _paginas
        .map(
          (pagina) => DocumentoCapturado(
            archivo: pagina.archivo,
            archivoOriginal: pagina.archivoOriginal,
            nombre: pagina.nombre,
            tipoArchivo: TipoArchivo.pdf,
            lotePdfId: pagina.lotePdfId ?? _lotePdfId,
            nombrePdf: nombrePdf,
            poligono: pagina.poligono,
            estado: pagina.estado,
            mensajeError: pagina.mensajeError,
          ),
        )
        .toList();
    Navigator.of(context).pop(paginas);
  }

  String _obtenerNombrePdf() {
    var nombre = _nombrePdfController.text.trim();
    if (nombre.toLowerCase().endsWith('.pdf')) {
      nombre = nombre.substring(0, nombre.length - 4);
    }
    nombre = nombre.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    nombre = nombre.replaceAll(RegExp(r'\s+'), '_');
    nombre = nombre.replaceAll(RegExp(r'^[_\-.]+|[_\-.]+$'), '');
    if (nombre.isEmpty) {
      nombre = 'documento_${DateTime.now().microsecondsSinceEpoch}';
    }
    return '$nombre.pdf';
  }

  String _crearNombrePagina() {
    return 'pagina_${DateTime.now().microsecondsSinceEpoch}.jpg';
  }

  List<PuntoPoligono> _poligonoCompleto() {
    return const <PuntoPoligono>[
      PuntoPoligono(x: 0, y: 0),
      PuntoPoligono(x: 1, y: 0),
      PuntoPoligono(x: 1, y: 1),
      PuntoPoligono(x: 0, y: 1),
    ];
  }
}
