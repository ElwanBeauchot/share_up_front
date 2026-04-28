import 'package:flutter/material.dart';
import 'package:share_up_front/feature/scan/scan_controller.dart';
import 'package:share_up_front/feature/scan/scan_state.dart';
import 'package:share_up_front/feature/select_files/select_files_page.dart';
import 'package:share_up_front/feature/scan/widgetsScanPage/scan_device_card.dart';
import 'package:share_up_front/feature/scan/widgetsScanPage/scan_header.dart';
import 'package:share_up_front/feature/scan/widgetsScanPage/scan_rescan_button.dart';
import 'package:share_up_front/theme/app_theme.dart';
import 'package:share_up_front/widgets/slide_fade_in.dart';

import '../../models/device_model.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  late final ScanController _controller;

// Creation de la page  
  @override
  void initState() {
    super.initState();
    _controller = ScanController();
    _controller.loadDevices();
  }

// Destruction de la page
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openSelectFiles(DeviceScanModel device) async { // Fonction pour ouvrir la page de sélection de fichiers
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SelectFilesPage( // Ouvre la page de sélection de fichiers en passant le nom de l'appareil sélectionné
          deviceName: device.name,
        ),
      ),
    );

    if (!mounted) return; // Vérifie que le widget est toujours vivant.
  
    await _controller.loadDevices(); // fonction qui relance le scan pour rafraichir la liste des appareils 
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
                              return SlideFadeIn( // Animation d'apparition
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
