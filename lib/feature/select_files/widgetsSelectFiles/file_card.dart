import 'package:flutter/material.dart';
import 'package:share_up_front/feature/select_files/select_files_state.dart';
import 'package:share_up_front/theme/app_colors.dart';

class FileCard extends StatelessWidget {
  final FileItemModel file;
  final VoidCallback onTap;

  const FileCard({
    super.key,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fileStyle = _getFileStyle(file.type);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: file.isSelected
                ? AppColors.indigo
                : const Color(0xFFE5E7EB),
            width: file.isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: file.isSelected
                  ? AppColors.indigo.withOpacity(0.16)
                  : const Color(0xFF0F172A).withOpacity(0.08),
              blurRadius: file.isSelected ? 16 : 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _FileIconCircle(
              icon: fileStyle.icon,
              color: fileStyle.color,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
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

class _FileIconCircle extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _FileIconCircle({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF3F4F6),
      ),
      child: Icon(
        icon,
        color: color,
        size: 22,
      ),
    );
  }
}

class _SelectCircle extends StatelessWidget {
  final bool isSelected;

  const _SelectCircle({
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: isSelected
              ? AppColors.indigo
              : const Color(0xFFD1D5DB),
          width: 2,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.indigo,
                ),
              ),
            )
          : null,
    );
  }
}

class _FileStyle {
  final IconData icon;
  final Color color;

  const _FileStyle({
    required this.icon,
    required this.color,
  });
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
      return const _FileStyle(
        icon: Icons.music_note,
        color: Color(0xFF22C55E),
      );
    case FileType.video:
      return const _FileStyle(
        icon: Icons.videocam_outlined,
        color: Color(0xFFA855F7),
      );
  }
}
