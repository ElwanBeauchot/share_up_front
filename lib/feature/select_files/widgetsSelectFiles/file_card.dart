import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_up_front/feature/select_files/select_files_state.dart';
import 'package:share_up_front/theme/app_colors.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class FileCard extends StatelessWidget {
  final FileItemModel file;
  final VoidCallback onTap;

  const FileCard({super.key, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fileStyle = _getFileStyle(file.type);
    final isMedia = file.type == FileType.image || file.type == FileType.video;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: file.isSelected ? AppColors.indigo : const Color(0xFFE5E7EB),
            width: file.isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: file.isSelected
                  ? AppColors.indigo.withValues(alpha: 0.16)
                  : const Color(0xFF0F172A).withValues(alpha: 0.08),
              blurRadius: file.isSelected ? 16 : 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _FilePreview(
              file: file,
              icon: fileStyle.icon,
              color: fileStyle.color,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMedia ? _compactMediaName(file.name) : file.name,
                    maxLines: isMedia ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    file.size,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),

            _SelectCircle(isSelected: file.isSelected),
          ],
        ),
      ),
    );
  }
}

class _FilePreview extends StatelessWidget {
  final FileItemModel file;
  final IconData icon;
  final Color color;

  const _FilePreview({
    required this.file,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final path = file.path;
    final canPreviewImage =
        file.type == FileType.image && path != null && File(path).existsSync();

    if (canPreviewImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(
          File(path),
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return _IconPreview(icon: icon, color: color);
          },
        ),
      );
    }

    if (file.type == FileType.video) {
      final canPreviewVideo = path != null && File(path).existsSync();
      if (canPreviewVideo) return _VideoPreview(path: path);
    }

    return _IconPreview(icon: icon, color: color);
  }
}

class _VideoPreview extends StatefulWidget {
  final String path;

  const _VideoPreview({required this.path});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late Future<Uint8List?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _loadThumbnail(); // Charge la miniature dès l'initialisation
  }

  @override
  void didUpdateWidget(covariant _VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _thumbnailFuture = _loadThumbnail();
    }
  }

  Future<Uint8List?> _loadThumbnail() {
    return VideoThumbnail.thumbnailData(
      video: widget.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 180,
      maxHeight: 180,
      timeMs: 500,
      quality: 78,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (data == null)
                  const ColoredBox(
                    color: Color(0xFFE5E7EB),
                    child: Icon(
                      Icons.videocam_outlined,
                      color: Color(0xFF6B7280),
                      size: 22,
                    ),
                  )
                else
                  Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IconPreview extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconPreview({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        color: Color(0xFFF3F4F6),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _SelectCircle extends StatelessWidget {
  final bool isSelected;

  const _SelectCircle({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.indigo : Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isSelected ? AppColors.indigo : const Color(0xFFD1D5DB),
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(
              Icons.check_rounded,
              size: 17,
              color: Colors.white,
            )
          : null,
    );
  }
}

class _FileStyle {
  final IconData icon;
  final Color color;

  const _FileStyle({required this.icon, required this.color});
}

_FileStyle _getFileStyle(FileType type) {
  switch (type) {
    case FileType.image:
      return const _FileStyle(
        icon: Icons.image_outlined,
        color: Color(0xFF3B82F6),
      );
    case FileType.document:
      return const _FileStyle(
        icon: Icons.description_outlined,
        color: Color(0xFFF97316),
      );
    case FileType.audio:
      return const _FileStyle(icon: Icons.music_note, color: Color(0xFF22C55E));
    case FileType.video:
      return const _FileStyle(
        icon: Icons.videocam_outlined,
        color: Color(0xFFA855F7),
      );
  }
}

String _compactMediaName(String name) {
  final dotIndex = name.lastIndexOf('.');
  final hasExtension = dotIndex > 0 && dotIndex < name.length - 1;
  final baseName = hasExtension ? name.substring(0, dotIndex) : name;
  final extension = hasExtension ? name.substring(dotIndex) : '';

  if (baseName.length <= 18) return name;

  return '${baseName.substring(0, 18)}...$extension';
}
