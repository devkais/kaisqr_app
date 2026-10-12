import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../sala/controllers/sala_controller.dart';
import '../controllers/capture_controller.dart';
import '../models/documento_capturado.dart';
import 'camera_capture_view.dart';
import 'pdf_capture_view.dart';

class CaptureView extends StatefulWidget {
  const CaptureView({
    required this.salaController,
    required this.onCompleted,
    super.key,
  });

  final SalaController salaController;
  final Future<void> Function() onCompleted;

  @override
  State<CaptureView> createState() => _CaptureViewState();
}

class _CaptureViewState extends State<CaptureView> {
  late final CaptureController _captureController;

  @override
  void initState() {
    super.initState();
    _captureController = CaptureController(
      salaController: widget.salaController,
    );
    _captureController.addListener(_actualizarVista);
    unawaited(_captureController.recuperarCapturaPendiente());
  }

  @override
  void dispose() {
    _captureController.removeListener(_actualizarVista);
    _captureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final documentos = _captureController.documentos;
    final cantidadArchivos =
        documentos
            .where((documento) => documento.tipoArchivo == TipoArchivo.imagen)
            .length +
        _agruparPaginasPdf(documentos).length;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Documentos para enviar · $cantidadArchivos',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildDocumentos(context),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_captureController.mensajeError != null) ...<Widget>[
                    _buildError(_captureController.mensajeError!),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _captureController.enviando
                              ? null
                              : _captureController.seleccionarImagen,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Galería'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _captureController.enviando
                              ? null
                              : _abrirSelectorTipo,
                          icon: const Icon(Icons.create_new_folder_outlined),
                          label: const Text('Crear archivo'),
                        ),
                      ),
                    ],
                  ),
                  if (documentos.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed:
                          _captureController.enviando ||
                              _captureController.documentos.isEmpty
                          ? null
                          : _enviarDocumentos,
                      icon: _captureController.enviando
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _captureController.enviando
                            ? 'Enviando...'
                            : 'Enviar y finalizar · $cantidadArchivos',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentos(BuildContext context) {
    final documentos = _captureController.documentos;
    if (documentos.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.document_scanner_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Todavía no hay archivos',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Elige una imagen de tu galería o crea un archivo para comenzar.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final documentosImagen = documentos
        .where((documento) => documento.tipoArchivo == TipoArchivo.imagen)
        .toList();
    final lotesPdf = _agruparPaginasPdf(documentos);
    if (lotesPdf.isEmpty) {
      return _buildListaDocumentos(documentos);
    }

    final entradasPdf = lotesPdf.entries.toList();
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
        if (documentosImagen.isNotEmpty) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
            child: Text(
              'Imágenes: ${documentosImagen.length}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          _buildListaDocumentos(documentosImagen, shrinkWrap: true),
          const SizedBox(height: 18),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
          child: Text(
            'PDFs: ${entradasPdf.length}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        for (var index = 0; index < entradasPdf.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildPdfMultipagina(
              context,
              lotePdfId: entradasPdf[index].key,
              documentos: entradasPdf[index].value,
              numeroPdf: index + 1,
            ),
          ),
      ],
    );
  }

  Widget _buildListaDocumentos(
    List<DocumentoCapturado> documentos, {
    bool shrinkWrap = false,
  }) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemCount: documentos.length,
      itemBuilder: (context, index) =>
          _buildDocumentoCard(context, documentos[index]),
    );
  }

  Map<String, List<DocumentoCapturado>> _agruparPaginasPdf(
    List<DocumentoCapturado> documentos,
  ) {
    final lotes = <String, List<DocumentoCapturado>>{};
    for (final documento in documentos) {
      if (documento.tipoArchivo != TipoArchivo.pdf) continue;
      final lotePdfId = documento.lotePdfId ?? 'lote_principal';
      (lotes[lotePdfId] ??= <DocumentoCapturado>[]).add(documento);
    }
    return lotes;
  }

  Widget _buildPdfMultipagina(
    BuildContext context, {
    required String lotePdfId,
    required List<DocumentoCapturado> documentos,
    required int numeroPdf,
  }) {
    final hayErrores = documentos.any(
      (documento) => documento.estado == EstadoDocumento.error,
    );
    final todosEnviados = documentos.every(
      (documento) => documento.estado == EstadoDocumento.enviado,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_outlined,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        documentos.first.nombrePdf ?? 'PDF multipágina',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${documentos.length} páginas · PDF $numeroPdf',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _captureController.enviando
                      ? null
                      : () => _captureController.eliminarLotePdf(lotePdfId),
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Eliminar PDF',
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 142,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: documentos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) =>
                    _buildPdfMiniatura(context, documentos[index], index),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hayErrores
                  ? 'Hay páginas con errores de envío.'
                  : todosEnviados
                  ? 'PDF enviado correctamente.'
                  : 'Listo para enviar.',
              style: TextStyle(
                color: hayErrores
                    ? colorScheme.error
                    : todosEnviados
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfMiniatura(
    BuildContext context,
    DocumentoCapturado documento,
    int indice,
  ) {
    return SizedBox(
      width: 94,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(documento.archivo, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Eliminar página ${indice + 1}',
                      onPressed: _captureController.enviando
                          ? null
                          : () =>
                                _captureController.eliminarDocumento(documento),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Página ${indice + 1}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentoCard(
    BuildContext context,
    DocumentoCapturado documento,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                documento.archivo,
                width: 64,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    documento.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDocumentStatus(documento),
                ],
              ),
            ),
            IconButton(
              onPressed: _captureController.enviando
                  ? null
                  : () => _captureController.eliminarDocumento(documento),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: 'Eliminar imagen',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentStatus(DocumentoCapturado documento) {
    final colors = Theme.of(context).colorScheme;
    final (Color color, String label) = switch (documento.estado) {
      EstadoDocumento.pendiente => (colors.onSurfaceVariant, 'Pendiente'),
      EstadoDocumento.enviando => (colors.primary, 'Enviando'),
      EstadoDocumento.enviado => (colors.primary, 'Enviado'),
      EstadoDocumento.error => (colors.error, 'Error'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: documento.estado == EstadoDocumento.error
            ? colors.errorContainer
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
    );
  }

  Future<void> _enviarDocumentos() async {
    final completado = await _captureController.enviarDocumentos();
    if (completado && mounted) await widget.onCompleted();
  }

  void _actualizarVista() {
    if (mounted) setState(() {});
  }

  Future<void> _abrirCamara() async {
    final imagen = await Navigator.of(context).push<XFile>(
      MaterialPageRoute<XFile>(
        builder: (_) => const CameraCaptureView(titulo: 'Capturar imagen'),
      ),
    );

    if (!mounted || imagen == null) return;
    _captureController.agregarImagen(imagen);
  }

  Future<void> _abrirSelectorTipo() async {
    final tipoArchivo = await showModalBottomSheet<TipoArchivo>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '¿Qué archivo quieres crear?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Imagen'),
                subtitle: const Text('Capturar y enviar una imagen'),
                onTap: () => Navigator.of(context).pop(TipoArchivo.imagen),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('PDF'),
                subtitle: const Text('Capturar varias páginas y unirlas'),
                onTap: () => Navigator.of(context).pop(TipoArchivo.pdf),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || tipoArchivo == null) return;
    if (!_captureController.puedeAgregarTipo(tipoArchivo)) return;

    if (tipoArchivo == TipoArchivo.imagen) {
      await _abrirCamara();
    } else {
      await _abrirConstructorPdf();
    }
  }

  Future<void> _abrirConstructorPdf() async {
    final paginas = await Navigator.of(context).push<List<DocumentoCapturado>>(
      MaterialPageRoute<List<DocumentoCapturado>>(
        builder: (_) => const PdfCaptureView(),
      ),
    );

    if (!mounted || paginas == null) return;
    _captureController.agregarDocumentos(paginas);
  }
}
