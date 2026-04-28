import 'package:flutter/material.dart';
import 'package:share_up_front/theme/app_colors.dart';

enum TransferDirection {
  received,
  sent,
}

class TransferHistoryItem {
  final String deviceName;
  final String detail;
  final String timeLabel;
  final String sizeLabel;
  final TransferDirection direction;

  const TransferHistoryItem({
    required this.deviceName,
    required this.detail,
    required this.timeLabel,
    required this.sizeLabel,
    required this.direction,
  });
}

class TransferHistoryCard extends StatelessWidget {
  final TransferHistoryItem item;

  const TransferHistoryCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final isReceived = item.direction == TransferDirection.received; //determine si le transfert est reçu ou envoyé
    final accentColor = isReceived
        ? const Color(0xFF16A34A)
        : AppColors.indigo;
    final directionLabel = isReceived ? 'Reçu' : 'Envoyé';
    final directionIcon = isReceived ? Icons.south_west : Icons.north_east;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withOpacity(0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DeviceIconCircle(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.deviceName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _TransferDirectionBadge(
                      label: directionLabel,
                      icon: directionIcon,
                      color: accentColor,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 15,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.detail,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _SuccessBadge(),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 15,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.timeLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              Text(
                item.sizeLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceIconCircle extends StatelessWidget {
  const _DeviceIconCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.iconGradient,
      ),
      child: const Icon(
        Icons.phone_iphone_rounded,
        size: 17,
        color: Colors.white,
      ),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFDCFCE7),
      ),
      child: const Icon(
        Icons.check,
        size: 18,
        color: Color(0xFF22C55E),
      ),
    );
  }
}

class _TransferDirectionBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _TransferDirectionBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
