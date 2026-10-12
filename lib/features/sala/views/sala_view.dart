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
    if (!mounted ||
        _cerrandoVista ||
        widget.salaController.salaActual != null) {
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Sala', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(
                'Código ${sala.codigo}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
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
            tooltip: 'Salir de la sala',
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: ListenableBuilder(
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
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final controller = widget.salaController;
    final colors = Theme.of(context).colorScheme;
    final hayProblema =
        controller.mensajeError != null ||
        controller.mensajeEstado.toLowerCase().contains('interrumpida');
    final color = hayProblema ? colors.error : colors.primary;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hayProblema ? colors.errorContainer : colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            hayProblema ? Icons.cloud_off_outlined : Icons.cloud_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              controller.mensajeError ?? controller.mensajeEstado,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: hayProblema
                    ? colors.onErrorContainer
                    : colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
