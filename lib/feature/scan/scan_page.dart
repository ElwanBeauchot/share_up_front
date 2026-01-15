import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'scan_controller.dart';
import 'scan_state.dart';
import '../../services/p2p_service.dart';
import '../select_files/select_files_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  late final ScanController controller;
  final P2PService _p2pService = P2PService();

  // ✅ Sert à forcer la reconstruction de la liste pour rejouer l'animation
  int _animationSeed = 0;

  @override
  void initState() {
    super.initState();

    controller = ScanController();
    controller.startScan();

    _p2pService.onMessageReceived = (msg) {
      if (mounted) _showMessageDialog(msg);
    };

    _startListeningForConnections();
  }

  @override
  void dispose() {
    _p2pService.disconnect();
    controller.dispose();
    super.dispose();
  }

  void _startListeningForConnections() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _p2pService.startListening();
    });
  }

  Future<void> _handleDeviceTap(ScanDevice device) async {
    if (!mounted) return;

    // ✅ On attend le retour de SelectFilesPage
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SelectFilesPage(
          targetDeviceName: device.deviceName,
        ),
      ),
    );

    // ✅ Au retour : on force la liste à se reconstruire => animation rejoue
    if (!mounted) return;
    setState(() {
      _animationSeed++;
    });

    // (Optionnel) si tu veux aussi relancer un scan en revenant :
    // controller.startScan();
  }

  void _showMessageDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text('Message reçu: $message'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _p2pService.disconnect();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) => _p2pService.disconnect());
  }

  @override
  Widget build(BuildContext context) {
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
        child: ValueListenableBuilder<ScanState>(
          valueListenable: controller,
          builder: (context, state, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appareils à proximité',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    state.scanning
                        ? 'Recherche en cours...'
                        : '${state.devices.length} appareil(s) détecté(s)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: state.scanning
                        ? const Center(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    )
                        : ListView.separated(
                      // ✅ La clé change au retour => Flutter recrée la liste => animations rejouent
                      key: ValueKey('devices_list_$_animationSeed'),
                      itemCount: state.devices.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final d = state.devices[index];

                        return _SlideFadeIn(
                          // ✅ key aussi sur l'item (encore plus robuste)
                          key: ValueKey(
                              'device_${d.deviceName}_$_animationSeed'),
                          delay: Duration(milliseconds: 70 * index),
                          child: _DeviceCard(
                            device: d,
                            onTap: () => _handleDeviceTap(d),
                          ),
                        );
                      },
                    ),
                  ),
                  if (!state.scanning) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: controller.startScan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.indigo,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Rechercher à nouveau',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SlideFadeIn extends StatefulWidget {
  const _SlideFadeIn({
    super.key,
    required this.child,
    required this.delay,
  });

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

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.onTap,
  });

  final ScanDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
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
            const _LeftIcon(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.deviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    device.os,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeftIcon extends StatelessWidget {
  const _LeftIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.brandGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.phone_iphone_rounded,
        color: Colors.white,
        size: 19,
      ),
    );
  }
}
