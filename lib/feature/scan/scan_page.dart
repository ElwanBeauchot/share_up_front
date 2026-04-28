import 'package:flutter/material.dart';
import 'package:share_up_front/feature/scan/scan_controller.dart';
import 'package:share_up_front/feature/scan/scan_state.dart';
import 'package:share_up_front/feature/select_files/select_files_page.dart';
import 'package:share_up_front/feature/scan/widgetsScanPage/scan_device_card.dart';
import 'package:share_up_front/feature/scan/widgetsScanPage/scan_header.dart';
import 'package:share_up_front/feature/scan/widgetsScanPage/scan_rescan_button.dart';
import 'package:share_up_front/theme/app_theme.dart';
import 'package:share_up_front/widgets/slide_fade_in.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  late final ScanController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScanController();
    _controller.loadDevices();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openSelectFiles(DeviceModel device) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SelectFilesPage(
          deviceName: device.name,
          deviceUuid: device.uuid,
        ),
      ),
    );

    if (!mounted) return;
    // TODO: au retour, relancer ici un vrai scan si on veut rafraichir
    // les appareils disponibles depuis l'API ou le service reseau.
    await _controller.loadDevices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FA),
      body: SafeArea(
        child: ValueListenableBuilder<ScanState>(
          valueListenable: _controller,
          builder: (context, state, _) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ScanHeader(),

                  const SizedBox(height: 14),

                  Text(
                    state.isLoading
                        ? 'Recherche en cours...'
                        : '${state.devices.length} appareil(s) détecté(s)',
                    style: const TextStyle(
                      fontSize: AppTextSizes.headerTitleM,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4B5563),
                    ),
                  ),

                  const SizedBox(height: 26),

                  Expanded(
                    child: state.isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 34,
                              height: 34,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          )
                        : ListView.separated(
                            key: ValueKey(
                              'devices_list_${state.animationSeed}',
                            ),
                            itemCount: state.devices.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 18),
                            itemBuilder: (context, index) {
                              final device = state.devices[index];
                              return SlideFadeIn(
                                key: ValueKey(
                                  'device_${device.name}_${state.animationSeed}',
                                ),
                                delay: Duration(milliseconds: 70 * index),
                                child: DeviceCard(
                                  device: device,
                                  onTap: () => _openSelectFiles(device),
                                ),
                              );
                            },
                          ),
                  ),

                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  RescanButton(
                    onPressed: _controller.loadDevices,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
