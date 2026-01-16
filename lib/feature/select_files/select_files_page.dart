// feature/select_files/select_files_page.dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'select_files_controller.dart';
import 'select_files_state.dart';

class SelectFilesPage extends StatefulWidget {
  final String targetDeviceName;
  final String targetDeviceUuid;

  const SelectFilesPage({
    super.key,
    required this.targetDeviceName,
    required this.targetDeviceUuid,
  });

  @override
  State<SelectFilesPage> createState() => _SelectFilesPageState();
}

class _SelectFilesPageState extends State<SelectFilesPage> {
  late final SelectFilesController controller;

  @override
  void initState() {
    super.initState();

    final mock = <SelectableFile>[
      const SelectableFile(
        id: '1',
        name: 'Photo_vacances.jpg',
        bytes: 2400000,
        kind: FileKind.image,
      ),
      const SelectableFile(
        id: '2',
        name: 'Document.pdf',
        bytes: 1200000,
        kind: FileKind.pdf,
      ),
      const SelectableFile(
        id: '3',
        name: 'Musique.mp3',
        bytes: 4800000,
        kind: FileKind.audio,
      ),
      const SelectableFile(
        id: '4',
        name: 'Vidéo_family.mp4',
        bytes: 12500000,
        kind: FileKind.video,
      ),
      const SelectableFile(
        id: '5',
        name: 'Présentation.pptx',
        bytes: 3100000,
        kind: FileKind.ppt,
      ),
    ];

    controller = SelectFilesController(
      targetDeviceName: widget.targetDeviceName,
      targetDeviceUuid: widget.targetDeviceUuid,
      initialFiles: mock,
    );

    controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_onChanged);
    controller.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final s = controller.state;

    // Fichiers sélectionnés + total
    final selectedFiles =
    s.files.where((f) => s.selectedIds.contains(f.id)).toList();
    final totalBytes =
    selectedFiles.fold<int>(0, (sum, f) => sum + f.bytes);

    return Scaffold(
      backgroundColor: AppColors.scanBg,
      appBar: AppBar(
        backgroundColor: AppColors.scanBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 100,
        leading: InkWell(
          onTap: () => Navigator.of(context).pop(),
          child: Row(
            children: const [
              SizedBox(width: 8),
              Icon(Icons.arrow_back, color: Colors.black87),
              SizedBox(width: 4),
              Text(
                'Retour',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sélectionner des fichiers',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Envoi vers ${s.targetDeviceName}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: SizeTransition(
                      sizeFactor: anim,
                      axisAlignment: -1,
                      child: child,
                    ),
                  );
                },
                child: selectedFiles.isEmpty
                    ? const SizedBox.shrink(key: ValueKey('empty'))
                    : _SelectedSummaryCard(
                  key: const ValueKey('summary'),
                  count: selectedFiles.length,
                  totalBytes: totalBytes,
                  files: selectedFiles,
                  onRemove: (id) => controller.toggleSelection(id),
                ),
              ),

              if (selectedFiles.isNotEmpty) const SizedBox(height: 16),

              Expanded(
                child: ListView.separated(
                  itemCount: s.files.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final file = s.files[index];
                    final selected = s.selectedIds.contains(file.id);

                    return _SlideFadeIn(
                      delay: Duration(milliseconds: 70 * index),
                      child: _FileRow(
                        file: file,
                        selected: selected,
                        onTap: () => controller.toggleSelection(file.id),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: controller.addFilesFromDevice,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Ajouter des fichiers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: Colors.black.withOpacity(0.08)),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: s.canSend ? controller.sendSelected : null,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    s.isSending ? 'Envoi...' : 'Envoyer',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.indigo,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.black.withOpacity(0.08),
                    disabledForegroundColor: Colors.black.withOpacity(0.35),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedSummaryCard extends StatelessWidget {
  final int count;
  final int totalBytes;
  final List<SelectableFile> files;
  final void Function(String id) onRemove;

  const _SelectedSummaryCard({
    super.key,
    required this.count,
    required this.totalBytes,
    required this.files,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne titre + total
          Row(
            children: [
              Expanded(
                child: Text(
                  '$count fichier(s) sélectionné(s)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatBytes(totalBytes),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: files.map((f) {
              return _SelectedChip(
                label: _ellipsizeName(f.name, max: 16),
                onClose: () => onRemove(f.id),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _ellipsizeName(String name, {required int max}) {
    if (name.length <= max) return name;
    return '${name.substring(0, max - 1)}…';
  }
}

class _SelectedChip extends StatelessWidget {
  final String label;
  final VoidCallback onClose;

  const _SelectedChip({
    required this.label,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onClose,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.close,
                size: 16,
                color: Colors.white.withOpacity(0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _SlideFadeIn extends StatefulWidget {
  const _SlideFadeIn({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<_SlideFadeIn> createState() => _SlideFadeInState();
}

class _SlideFadeInState extends State<_SlideFadeIn> {
  bool _show = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(widget.delay, () {
      if (!mounted) return;
      setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _show ? 1 : 0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _show ? Offset.zero : const Offset(-0.06, 0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final SelectableFile file;
  final bool selected;
  final VoidCallback onTap;

  const _FileRow({
    required this.file,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = _iconFor(file.kind);
    final iconColor = _colorFor(file.kind);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? AppColors.indigo.withOpacity(0.65)
                : Colors.black.withOpacity(0.06),
            width: selected ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withOpacity(0.12),
              ),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    _formatBytes(file.bytes),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // Cercle sélection à droite
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: 2,
                  color: selected
                      ? AppColors.indigo
                      : Colors.black.withOpacity(0.18),
                ),
                color: selected ? AppColors.indigo : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(FileKind kind) {
    switch (kind) {
      case FileKind.image:
        return Icons.image_outlined;
      case FileKind.pdf:
        return Icons.description_outlined;
      case FileKind.audio:
        return Icons.music_note_outlined;
      case FileKind.video:
        return Icons.videocam_outlined;
      case FileKind.ppt:
        return Icons.slideshow_outlined;
      case FileKind.other:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _colorFor(FileKind kind) {
    switch (kind) {
      case FileKind.image:
        return AppColors.fileImage;
      case FileKind.pdf:
        return AppColors.filePdf;
      case FileKind.audio:
        return AppColors.fileAudio;
      case FileKind.video:
        return AppColors.fileVideo;
      case FileKind.ppt:
        return AppColors.filePpt;
      case FileKind.other:
        return AppColors.fileOther;
    }
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  double size = bytes.toDouble();
  int unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final v = (size * 10).round() / 10;
  return '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)} ${units[unit]}';
}
