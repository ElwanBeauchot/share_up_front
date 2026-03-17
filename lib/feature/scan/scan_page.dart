import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'scan_controller.dart';
import 'scan_state.dart';
import '../../services/p2p_service.dart';
import '../select_files/select_files_page.dart';

// Ecran de scan des appareils a proximite.
// On utilise un StatefulWidget car cette page change pendant son cycle de vie:
// le scan se lance, la liste se met a jour et certaines animations rejouent.

class ScanPage extends StatefulWidget {
  // Constructeur simple du widget.
  // "super.key" permet a Flutter d'identifier proprement ce widget si besoin.
  const ScanPage({super.key});

  @override
  // ScanPage = la coque du widget.
  // _ScanPageState = l'objet qui contient son etat vivant.
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // Controleur metier du scan.
  // "late final" veut dire:
  // - la variable sera initialisee plus tard
  // - mais une seule fois
  late final ScanController controller;

  // Service utilise pour l'ecoute des messages P2P.
  final P2PService _p2pService = P2PService();

  // ✅ Sert à forcer la reconstruction de la liste pour rejouer l'animation
  int _animationSeed = 0;

  @override
  void initState() {
    // initState est appelee une seule fois a la creation de la page.
    // C'est le bon endroit pour initialiser le controller et les listeners.
    super.initState();

    controller = ScanController();
    // Lance le premier scan des l'ouverture de l'ecran.
    controller.startScan();

    _p2pService.onMessageReceived = (msg) {
      // "mounted" verifie que la page est encore presente a l'ecran.
      if (mounted) _showMessageDialog(msg);
    };

    _startListeningForConnections();
  }

  @override
  void dispose() {
    // Nettoyage quand la page est detruite.
    _p2pService.disconnect();
    controller.dispose();
    super.dispose();
  }

  // Lance l'ecoute des connexions apres un petit delai.
  void _startListeningForConnections() {
    // Future.delayed execute le code un peu plus tard.
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _p2pService.startListening();
    });
  }

  // Ouvre la page de selection des fichiers pour l'appareil choisi.
  Future<void> _handleDeviceTap(ScanDevice device) async {
    if (!mounted) return;

    // ✅ On attend le retour de SelectFilesPage
    // push ouvre une nouvelle page.
    // Le await permet d'attendre le retour de l'utilisateur.
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
      // setState dit a Flutter de relancer build() apres ce changement local.
      _animationSeed++;
    });

    // (Optionnel) si tu veux aussi relancer un scan en revenant :
    // controller.startScan();
  }

  // Affiche une boite de dialogue quand un message P2P est recu.
  void _showMessageDialog(String message) {
    // showDialog affiche une popup Material au-dessus de la page.
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
    // build decrit visuellement l'ecran en fonction de l'etat actuel.
    return Scaffold(
      backgroundColor: AppColors.scanBg,
      appBar: AppBar(
        backgroundColor: AppColors.scanBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 100,
        leading: InkWell(
          // Bouton retour.
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
        // ValueListenableBuilder ecoute le controller.
        // Quand le ScanState change, ce bloc d'UI est reconstruit.
        child: ValueListenableBuilder<ScanState>(
          valueListenable: controller,
          builder: (context, state, _) {
            // "state" contient ici les donnees du scan a afficher.
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre de la page.
                  const Text(
                    'Appareils à proximité',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Sous-texte: etat du scan ou nombre d'appareils trouves.
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
                    // Loader pendant le scan, sinon liste des appareils detectes.
                    child: state.scanning
                        ? const Center(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    )
                        : ListView.separated(
                      // Cette key depend de _animationSeed.
                      // Quand elle change, Flutter recree la liste.
                      // ✅ La clé change au retour => Flutter recrée la liste => animations rejouent
                      key: ValueKey('devices_list_$_animationSeed'),
                      itemCount: state.devices.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final d = state.devices[index];

                        return _SlideFadeIn(
                          // Une key unique aide Flutter a bien distinguer chaque carte.
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
                      // Bouton pour relancer un scan.
                      child: ElevatedButton(
                        // On relance simplement la methode du controller.
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

// Animation d'apparition progressive des cartes appareils.
class _SlideFadeIn extends StatefulWidget {
  const _SlideFadeIn({
    super.key,
    // "child" = le widget qu'on veut afficher avec l'animation.
    required this.child,
    // "delay" = temps d'attente avant de lancer l'animation.
    required this.delay,
  });

  // Widget enfant a animer.
  final Widget child;

  // Delai avant affichage.
  final Duration delay;

  @override
  State<_SlideFadeIn> createState() => _SlideFadeInState();
}

class _SlideFadeInState extends State<_SlideFadeIn> {
  // false au debut = invisible.
  // true ensuite = visible.
  bool _show = false;

  @override
  void initState() {
    super.initState();

    // Active l'animation apres un leger delai.
    // "widget.delay" signifie qu'on utilise la valeur recue par le widget parent.
    Future.delayed(widget.delay, () {
      if (!mounted) return;
      setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      // Opacite 0 = invisible, opacite 1 = visible.
      opacity: _show ? 1 : 0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        // Petit decalage horizontal tant que l'animation n'est pas finie.
        offset: _show ? Offset.zero : const Offset(-0.06, 0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// Carte d'affichage d'un appareil detecte.
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    // Donnees de l'appareil a afficher.
    required this.device,
    // Action declenchee quand on clique sur la carte.
    required this.onTap,
  });

  final ScanDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Ouvre la page suivante quand on selectionne un appareil.
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
              // Expanded prend l'espace restant dans la ligne.
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

// Petite icone ronde affichee a gauche de chaque appareil.
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
