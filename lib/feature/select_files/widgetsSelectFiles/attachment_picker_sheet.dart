import 'dart:typed_data'; // Rajout d'un nouveau type pour la minature des images

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart'; 

class AttachmentPickerSheet extends StatefulWidget {
  final Future<void> Function(List<AssetEntity> assets) onMediaSelected; 
  final Future<void> Function() onFilesPressed;
  final Future<void> Function() onAlbumPressed;

  const AttachmentPickerSheet({
    super.key,
    required this.onMediaSelected,
    required this.onFilesPressed,
    required this.onAlbumPressed,
  });

  @override
  State<AttachmentPickerSheet> createState() => _AttachmentPickerSheetState();
}

class _AttachmentPickerSheetState extends State<AttachmentPickerSheet> {
  bool _isLoading = true;
  PermissionState? _permissionState;
  List<AssetEntity> _recentAssets = const [];
  final Set<String> _selectedAssetIds = {};

  @override
  void initState() {
    super.initState();
    _loadRecentMedia();
  }

  Future<void> _loadRecentMedia() async {
    final permissionState = await PhotoManager.requestPermissionExtend();

    if (!mounted) return; 

    if (!permissionState.hasAccess) {
      setState(() {
        _permissionState = permissionState;
        _isLoading = false;
      });
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.common,
    );

    final recentAssets = albums.isEmpty
        ? <AssetEntity>[]
        : await albums.first.getAssetListPaged(page: 0, size: 24);

    if (!mounted) return;

    setState(() {
      _permissionState = permissionState;
      _recentAssets = recentAssets;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.66,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _SheetActionButton(
                      icon: Icons.folder_outlined,
                      label: 'Fichiers',
                      onPressed: widget.onFilesPressed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SheetActionButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Tout l\'album',
                      onPressed: widget.onAlbumPressed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(child: _buildMediaContent()),
              if (_selectedAssetIds.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitSelectedMedia,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text('Ajouter ${_selectedAssetIds.length} media(s)'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaContent() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    if (_permissionState?.hasAccess != true) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 42,
            color: Color(0xFF6B7280),
          ),
          const SizedBox(height: 12),
          const Text(
            'Acces aux photos requis',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Autorise l\'acces pour afficher tes photos et videos recentes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: PhotoManager.openSetting,
            child: const Text('Ouvrir les reglages'),
          ),
        ],
      );
    }

    if (_recentAssets.isEmpty) {
      return const Center(
        child: Text(
          'Aucune photo ou video recente',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: _recentAssets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
      ),
      itemBuilder: (context, index) {
        final asset = _recentAssets[index];
        return _RecentMediaTile(
          asset: asset,
          isSelected: _selectedAssetIds.contains(asset.id),
          selectionIndex: _selectionIndexFor(asset),
          onTap: () => _toggleAssetSelection(asset),
        );
      },
    );
  }

  void _toggleAssetSelection(AssetEntity asset) {
    setState(() {
      if (_selectedAssetIds.contains(asset.id)) {
        _selectedAssetIds.remove(asset.id);
      } else {
        _selectedAssetIds.add(asset.id);
      }
    });
  }

  int? _selectionIndexFor(AssetEntity asset) { // Permet d'afficher l'ordre de selection des medias
    final index = _selectedAssetIds.toList().indexOf(asset.id);
    if (index == -1) return null;

    return index + 1;
  }

  Future<void> _submitSelectedMedia() async { 
    final selectedAssets = _recentAssets
        .where((asset) => _selectedAssetIds.contains(asset.id))
        .toList();

    await widget.onMediaSelected(selectedAssets);
  }
}

class _SheetActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function() onPressed;

  const _SheetActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEDEEF2),
          foregroundColor: const Color(0xFF374151),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
    );
  }
}

class _RecentMediaTile extends StatelessWidget {
  final AssetEntity asset;
  final bool isSelected;
  final int? selectionIndex;
  final VoidCallback onTap;

  const _RecentMediaTile({
    required this.asset,
    required this.isSelected,
    required this.selectionIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: const Color(0xFFE5E7EB),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List?>( // Permet d'afficher la minature de l'image ou de la video
                future: asset.thumbnailDataWithSize(
                  const ThumbnailSize.square(280),
                  quality: 78,
                ),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  if (data == null) {
                    return const Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: Color(0xFF9CA3AF),
                      ),
                    );
                  }

                  return Image.memory(
                    data,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  );
                },
              ),
              if (asset.type == AssetType.video)
                Positioned(
                  right: 7,
                  bottom: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4F46E5).withValues(alpha: 0.24)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF4F46E5)
                        : Colors.transparent,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Positioned(
                top: 7,
                right: 7,
                child: _SelectionBadge(
                  isSelected: isSelected,
                  index: selectionIndex,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBadge extends StatelessWidget { // badge qui affiche si le media est selectionne et son numéro 
  final bool isSelected;
  final int? index;

  const _SelectionBadge({required this.isSelected, required this.index});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? const Color(0xFF4F46E5) : Colors.black38,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: isSelected
          ? Center(
              child: Text(
                '${index ?? ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
    );
  }
}
