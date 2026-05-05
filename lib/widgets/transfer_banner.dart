// Notification persistante affichée en haut d'écran pendant toute la session
// P2P (demande, attente, transfert, succès/refus/échec). Branchée via
// MaterialApp.builder pour rester au-dessus de toutes les routes.

import 'package:flutter/material.dart';
import '../services/p2p_service.dart';
import '../theme/app_theme.dart';
class TransferBanner extends StatelessWidget {
  const TransferBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TransferState>(
      valueListenable: P2PService().transferState,
      builder: (context, state, _) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -1),
                  end: Offset.zero,
                ).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: state.phase == P2PPhase.idle
                  ? const SizedBox.shrink()
                  : Padding(
                      key: ValueKey(state.phase),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: AppSizes.sm,
                      ),
                      child: _buildCard(state),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(TransferState state) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                width: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.brandGradient),
                ),
              ),
              Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _icon(state),
                        const SizedBox(width: AppSizes.md),
                        Expanded(child: _texts(state)),
                      ],
                    ),
                    if (state.phase == P2PPhase.transferring) ...[
                      const SizedBox(height: AppSizes.md),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: state.progress,
                          minHeight: 6,
                          color: AppColors.purple,
                          backgroundColor: Colors.black.withOpacity(0.06),
                        ),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        '${(state.progress * 100).toStringAsFixed(0)}%  ·  '
                        '${_formatSize(state.transferredBytes)} / ${_formatSize(state.totalBytes)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSizes.sm),
                    _actions(state),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _icon(TransferState state) {
    final phase = state.phase;
    final solid = _solidColorFor(phase);
    final useGradient = solid == null;
    final spinner = phase == P2PPhase.awaitingResponse ||
        phase == P2PPhase.connecting ||
        phase == P2PPhase.transferring;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: useGradient ? AppColors.iconGradient : null,
        color: solid,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: spinner
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Icon(_iconFor(phase), color: Colors.white, size: 20),
    );
  }

  Widget _texts(TransferState state) {
    final subtitle = _subtitleFor(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _titleFor(state),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _actions(TransferState state) {
    final p2p = P2PService();
    switch (state.phase) {
      case P2PPhase.incomingRequest:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: p2p.rejectIncoming,
              child: const Text('Refuser'),
            ),
            const SizedBox(width: AppSizes.sm),
            FilledButton(
              onPressed: p2p.acceptIncoming,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Accepter'),
            ),
          ],
        );
      case P2PPhase.awaitingResponse:
      case P2PPhase.connecting:
      case P2PPhase.transferring:
        return Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: p2p.cancel,
            child: const Text('Annuler'),
          ),
        );
      case P2PPhase.failed:
        return Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: p2p.cancel,
            child: const Text('Fermer'),
          ),
        );
      case P2PPhase.success:
      case P2PPhase.rejected:
      case P2PPhase.idle:
        return const SizedBox.shrink();
    }
  }
}

// -------- helpers --------

IconData _iconFor(P2PPhase phase) {
  switch (phase) {
    case P2PPhase.incomingRequest:
      return Icons.download_rounded;
    case P2PPhase.awaitingResponse:
    case P2PPhase.connecting:
      return Icons.wifi_tethering;
    case P2PPhase.transferring:
      return Icons.swap_vert_rounded;
    case P2PPhase.success:
      return Icons.check_rounded;
    case P2PPhase.rejected:
      return Icons.block_rounded;
    case P2PPhase.failed:
      return Icons.error_outline_rounded;
    case P2PPhase.idle:
      return Icons.bolt;
  }
}

// null = on utilise le gradient de marque.
Color? _solidColorFor(P2PPhase phase) {
  switch (phase) {
    case P2PPhase.success:
      return const Color(0xFF22C55E);
    case P2PPhase.rejected:
      return const Color(0xFF94A3B8);
    case P2PPhase.failed:
      return const Color(0xFFEF4444);
    default:
      return null;
  }
}

String _titleFor(TransferState s) {
  switch (s.phase) {
    case P2PPhase.incomingRequest:
      return 'Fichier entrant';
    case P2PPhase.awaitingResponse:
      return 'En attente du destinataire…';
    case P2PPhase.connecting:
      return 'Connexion P2P…';
    case P2PPhase.transferring:
      return s.isSender
          ? 'Envoi de ${s.fileName ?? "fichier"}'
          : 'Réception de ${s.fileName ?? "fichier"}';
    case P2PPhase.success:
      return 'Transfert terminé';
    case P2PPhase.rejected:
      return 'Transfert refusé';
    case P2PPhase.failed:
      return 'Échec du transfert';
    case P2PPhase.idle:
      return '';
  }
}

String? _subtitleFor(TransferState s) {
  final name = s.fileName;
  switch (s.phase) {
    case P2PPhase.incomingRequest:
      if (name == null) return null;
      return s.totalBytes > 0
          ? '$name  ·  ${_formatSize(s.totalBytes)}'
          : name;
    case P2PPhase.awaitingResponse:
    case P2PPhase.connecting:
      return name;
    case P2PPhase.transferring:
      return null;
    case P2PPhase.success:
    case P2PPhase.rejected:
    case P2PPhase.failed:
      return name;
    case P2PPhase.idle:
      return null;
  }
}

String _formatSize(int bytes) {
  if (bytes <= 0) return '0 o';
  if (bytes < 1024) return '$bytes o';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
}
