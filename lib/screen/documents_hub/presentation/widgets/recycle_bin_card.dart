// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/presentation/widgets/                ║
// ║                            recycle_bin_card.dart              ║
// ║  CARD — one deleted document: file badge, name, source, days  ║
// ║  left, time-used bar, deleted / expires dates and Restore +   ║
// ║  delete-forever buttons. Expiring ones get a red edge.        ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/recycled_document.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_document_card.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_styles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecycleBinCard extends StatelessWidget {
  final RecycledDocument item;

  /// Reference time, shared by the whole list so every card agrees.
  final DateTime now;

  /// Null = disabled (dimmed).
  final VoidCallback? onRestore;
  final VoidCallback? onDeleteForever;

  /// Restore in flight: spinner on Restore, both buttons locked.
  final bool restoring;

  const RecycleBinCard({
    super.key,
    required this.item,
    required this.now,
    this.onRestore,
    this.onDeleteForever,
    this.restoring = false,
  });

  static const _danger = Color(0xFFDC2626);

  String _day(DateTime date) {
    final local = date.toLocal();
    final sameYear = local.year == now.year;
    return DateFormat(sameYear ? 'MMM d' : 'MMM d, y').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final doc = item.document;
    final soon = item.expiringSoon(now);
    final (sourceBg, sourceFg) = sourceTone(doc.sourceType);
    final radius = BorderRadius.circular(18);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: HubPalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HubFileBadge(document: doc, size: 50),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.name.trim().isEmpty
                                  ? doc.fileName
                                  : doc.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: HubPalette.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (doc.sourceType.isNotEmpty) ...[
                                  HubPill(
                                    label: doc.sourceType,
                                    background: sourceBg,
                                    foreground: sourceFg,
                                    radius: 6,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    doc.sourceName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: HubPalette.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _DaysLeftPill(days: item.daysLeft(now), soon: soon),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _UsedBar(value: item.elapsed(now), soon: soon),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Deleted ${_day(item.deletedAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: HubPalette.hint,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Expires ${_day(item.expiresAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: HubPalette.hint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _BinButton(
                          onPressed: restoring ? null : onRestore,
                          busy: restoring,
                          background: const Color(0xFFECFDF3),
                          border: const Color(0xFFA7F3D0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              restoring
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF15803D),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.restore_rounded,
                                      size: 20,
                                      color: Color(0xFF15803D),
                                    ),
                              const SizedBox(width: 8),
                              const Text(
                                'Restore',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 48,
                        child: _BinButton(
                          onPressed: restoring ? null : onDeleteForever,
                          background: const Color(0xFFFEF2F2),
                          border: const Color(0xFFFECACA),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            size: 22,
                            color: _danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Red edge on cards about to be purged.
            if (soon)
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 4,
                  child: ColoredBox(color: _danger),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "5d left" — red when expiring soon, amber otherwise.
class _DaysLeftPill extends StatelessWidget {
  final int days;
  final bool soon;

  const _DaysLeftPill({required this.days, required this.soon});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = soon
        ? (const Color(0xFFFDECEC), const Color(0xFFB91C1C))
        : (const Color(0xFFFEF3C7), const Color(0xFF92400E));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$days',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: 'd left'),
          ],
        ),
        style: TextStyle(fontSize: 12, color: fg),
      ),
    );
  }
}

/// How much of the 30 days is used up.
class _UsedBar extends StatelessWidget {
  final double value;
  final bool soon;

  const _UsedBar({required this.value, required this.soon});

  @override
  Widget build(BuildContext context) {
    final colors = soon
        ? const [Color(0xFFF87171), Color(0xFFDC2626)]
        : const [Color(0xFFCBD5E1), Color(0xFF94A3B8)];

    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: HubPalette.track,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        // A sliver even on day one, so the bar reads as a bar.
        widthFactor: value.clamp(0.03, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _BinButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color background;
  final Color border;
  final Widget child;

  /// Working — not dimmed even though taps are off.
  final bool busy;

  const _BinButton({
    required this.onPressed,
    required this.background,
    required this.border,
    required this.child,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);

    return Opacity(
      opacity: onPressed == null && !busy ? 0.5 : 1,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: border),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
