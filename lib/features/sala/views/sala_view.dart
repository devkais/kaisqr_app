import 'dart:async';

import 'package:flutter/material.dart';

import '../../captura/views/capture_view.dart';
import '../controllers/sala_controller.dart';

class SalaView extends StatefulWidget {
  const SalaView({required this.salaController, super.key});

  final SalaController salaController;

  @override
  State<SalaView> createState() => _SalaViewState();
}

class _SalaViewState extends State<SalaView> {
  bool _cerrandoVista = false;

  @override
  void initState() {
    super.initState();
    widget.salaController.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    widget.salaController.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    if (!mounted || _cerrandoVista || widget.salaController.salaActual != null) {
      return;
    }

    _cerrandoVista = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sala = widget.salaController.salaActual;
    if (sala == null) {
      return const SizedBox.shrink();
    }

    return PopScope<void>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !_cerrandoVista) {
          _cerrandoVista = true;
          unawaited(widget.salaController.salirSala());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Sala ${sala.codigo}'),
          leading: IconButton(
            onPressed: () async {
              _cerrandoVista = true;
              try {
                await widget.salaController.salirSala();
              } finally {
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: ListenableBuilder(
          listenable: widget.salaController,
          builder: (context, child) {
            return Column(
              children: <Widget>[
                _buildStatusCard(context),
                Expanded(
                  child: CaptureView(
                    salaController: widget.salaController,
                    onCompleted: () async {
                      await widget.salaController.salirSala();
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.cloud_done_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.salaController.mensajeEstado,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (widget.salaController.cantidadDocumentos > 0)
            Badge(label: Text('${widget.salaController.cantidadDocumentos}')),
        ],
      ),
    );
  }
}
