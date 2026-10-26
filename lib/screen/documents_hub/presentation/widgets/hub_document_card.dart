// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/presentation/widgets/                ║
// ║                            hub_document_card.dart             ║
// ║  CARD — file badge, name, source chip + name, dashed divider, ║
// ║  status pill and last-updated date.                           ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_styles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HubDocumentCard extends StatelessWidget {
  final HubDocument document;
  final VoidCallback? onTap;

  const HubDocumentCard({super.key, required this.document, this.onTap});

  /// "Recently updated" order → show the last update, local time.
  String get _date {
    final date = (document.updatedAt ?? document.uploadedAt)?.toLocal();
    if (date == null) return '';
    final sameYear = date.year == DateTime.now().year;
    return DateFormat(sameYear ? 'MMM d' : 'MMM d, y').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    return Material(
      color: Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: HubPalette.border),
          ),
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    final (sourceBg, sourceFg) = sourceTone(document.sourceType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HubFileBadge(document: document),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: HubPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      HubPill(
                        label: document.sourceType,
                        background: sourceBg,
                        foreground: sourceFg,
                        radius: 6,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          document.sourceName,
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
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: HubDashedDivider(),
        ),
        Row(
          children: [
            HubStatusPill(status: document.status),
            const Spacer(),
            Text(
              _date,
              style: const TextStyle(fontSize: 12, color: HubPalette.muted),
            ),
          ],
        ),
      ],
    );
  }
}

/// PDF / XLSX / DOC … square, tinted by file type.
class HubFileBadge extends StatelessWidget {
  final HubDocument document;
  final double size;

  const HubFileBadge({super.key, required this.document, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = fileBadgeTone(document);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Text(
        fileBadgeLabel(document),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );
  }
}

class HubStatusPill extends StatelessWidget {
  final String status;

  const HubStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = statusTone(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.isEmpty ? 'Assigned' : status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small tinted label — the source chip ("Lead", "Invoice" …).
class HubPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final double radius;

  const HubPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class HubDashedDivider extends StatelessWidget {
  const HubDashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        const dash = 4.0, gap = 3.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Container(
              width: dash,
              height: 1,
              margin: const EdgeInsets.only(right: gap),
              color: HubPalette.border,
            ),
          ),
        );
      },
    );
  }
}
