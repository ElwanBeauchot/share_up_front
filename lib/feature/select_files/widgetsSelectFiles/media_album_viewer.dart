import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_up_front/feature/select_files/select_files_state.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

//////////////////////////////
// PAGE ALBUM MEDIA
//////////////////////////////

class MediaAlbumViewer extends StatefulWidget {
  final List<FileItemModel> mediaFiles;
  final int initialIndex;

  const MediaAlbumViewer({
    super.key,
    required this.mediaFiles,
    required this.initialIndex,
  });

  @override
  State<MediaAlbumViewer> createState() => _MediaAlbumViewerState();
}

//////////////////////////////
// ETAT ET NAVIGATION DE L'ALBUM
//////////////////////////////

class _MediaAlbumViewerState extends State<MediaAlbumViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    // On demarre sur l'index du media qui a été tapé dans la galerie
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  // Destruction du controller
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // on récupere le media courant
    final currentFile = widget.mediaFiles[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(currentFile),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.mediaFiles.length,
                onPageChanged: (index) {
                  // on met a jour l'index quand on swipe
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  // On verifie si il s'agit d'une video sinon on traitre l'image
                  return _buildMediaPage(widget.mediaFiles[index]);
                },
              ),
            ),
            _buildThumbRail(), // Thumbnail correspond au miniature du media donc la ligne du bas
          ],
        ),
      ),
    );
  }

  //////////////////////////////
  // HEADER
  //////////////////////////////

  Widget _buildHeader(FileItemModel file) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          // croix pour fermer la visionneuse
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            color: Colors.white,
          ),
          Expanded(
            // affiche le nom du media en haut de la page
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // affiche numero du media
          SizedBox(
            width: 48,
            child: Text(
              '${_currentIndex + 1}/${widget.mediaFiles.length}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //////////////////////////////
  // AFFICHAGE IMAGE / VIDEO
  //////////////////////////////

  Widget _buildMediaPage(FileItemModel file) {
    final path = file.path;
    if (path == null || !File(path).existsSync()) return _missingMedia();

    if (file.type == FileType.video) {
      // si vidéo on delaisse la tache a VideoPLayerPage
      return _VideoPlayerPage(path: path);
    }

    return Center(
      // permet de zoomer
      child: InteractiveViewer(
        minScale: 0.8,
        maxScale: 4,
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _missingMedia(),
        ),
      ),
    );
  }

  //////////////////////////////
  // MINIATURES EN BAS DE PAGE
  //////////////////////////////

  // la barre miniature en bas de la page
  Widget _buildThumbRail() {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        scrollDirection: Axis.horizontal,
        itemCount: widget.mediaFiles.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _buildThumb(widget.mediaFiles[index], index);
        },
      ),
    );
  }

  // Fonction qui construit la miniature qu'on appel dans _buildThumbRail
  Widget _buildThumb(FileItemModel file, int index) {
    final path = file.path;
    final isSelected = index == _currentIndex;

    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _buildThumbContent(file, path),
        ),
      ),
    );
  }

  // Fonction qui verifie si le media existe et peut afficher une miniature
  Widget _buildThumbContent(FileItemModel file, String? path) {
    final canShowImage =
        file.type == FileType.image && path != null && File(path).existsSync();
    final canShowVideo =
        file.type == FileType.video && path != null && File(path).existsSync();

    if (canShowImage) return Image.file(File(path), fit: BoxFit.cover);
    if (canShowVideo) return _VideoThumb(path: path);

    return const ColoredBox(
      color: Color(0xFF1E293B),
      child: Icon(
        Icons.play_circle_fill_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }

  // visuel d'erreur si le fichier n'existe pas
  Widget _missingMedia() {
    return const Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: Color(0xFF94A3B8),
        size: 52,
      ),
    );
  }
}

//////////////////////////////
// MINIATURE VIDEO
//////////////////////////////

class _VideoThumb extends StatelessWidget {
  final String path;

  const _VideoThumb({required this.path});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 180,
        maxHeight: 180,
        timeMs: 500,
        quality: 75,
      ),
      builder: (context, snapshot) {
        final data = snapshot.data;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (data == null)
              const ColoredBox(color: Color(0xFF1E293B))
            else
              Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true),
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ],
        );
      },
    );
  }
}

//////////////////////////////
// LECTEUR VIDEO
//////////////////////////////

class _VideoPlayerPage extends StatefulWidget {
  final String path;

  const _VideoPlayerPage({required this.path});

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  late final VideoPlayerController _controller;
  late final Future<void> _initializeFuture;

  @override
  void initState() {
    super.initState();
    // on creer un controller pour la video a partir du path
    _controller = VideoPlayerController.file(File(widget.path));

    // listener pour refresh la page quand elle change d'état
    _controller.addListener(_refresh);

    // On initialise la video, on dit qu'elle ne boucle pas, et on rafraichier la page
    _initializeFuture = _controller.initialize().then((_) async {
      await _controller.setLooping(false);
      _refresh();
    });
  }

  // Destruction du controller
  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  // a chaque changement d'état on refresh l'ui
  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayback() async {
    if (!_controller.value.isInitialized) return;

    // si video lancer on met en pause
    if (_controller.value.isPlaying) {
      await _controller.pause();
      return;
    }
    // reviens au debut si la video est fini
    if (_controller.value.position >= _controller.value.duration) {
      await _controller.seekTo(Duration.zero);
    }
    await _controller.play();
  }

  //////////////////////////////
  // CONSTRUCTION DU LECTEUR
  //////////////////////////////

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      // on attend que la vidéo soit initailisée
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !_controller.value.isInitialized) {
          return const Center(
            child: Icon(
              Icons.videocam_off_outlined,
              color: Color(0xFF94A3B8),
              size: 52,
            ),
          );
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [VideoPlayer(_controller), _buildVideoOverlay()],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  //////////////////////////////
  // CONTROLES VIDEO
  //////////////////////////////

  // récupere l'état de la vidéo afin d'appeler _togglePlayback
  Widget _buildVideoOverlay() {
    final isPlaying = _controller.value.isPlaying;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlayback,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x66000000)],
              ),
            ),
          ),
          if (!isPlaying)
            Center(
              child: IconButton.filled(
                onPressed: _togglePlayback,
                iconSize: 42,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                  foregroundColor: const Color(0xFF111827),
                  fixedSize: const Size(76, 76),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white.withValues(alpha: 0.38),
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
