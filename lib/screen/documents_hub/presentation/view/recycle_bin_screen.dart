// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/presentation/view/                   ║
// ║                            recycle_bin_screen.dart            ║
// ║  VIEW — deleted assignments (GET /document-hub/recycle-bin):  ║
// ║  source tabs, then "Expiring soon" and "Recently deleted"     ║
// ║  sections of cards.                                           ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/documents_hub_injection.dart';
import 'package:crm_app/screen/documents_hub/presentation/cubit/recycle_bin_cubit.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_source_tabs.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_styles.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/recycle_bin_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pushes the bin. Completes with true when something was restored, so
/// the hub knows to reload.
Future<bool> showRecycleBin(BuildContext context) async {
  var restored = false;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RecycleBinScreen(onRestored: () => restored = true),
    ),
  );
  return restored;
}

class RecycleBinScreen extends StatelessWidget {
  /// Called after each successful restore.
  final VoidCallback? onRestored;

  const RecycleBinScreen({super.key, this.onRestored});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => buildRecycleBinCubit()..load(),
      child: _RecycleBinView(onRestored: onRestored),
    );
  }
}

class _RecycleBinView extends StatelessWidget {
  final VoidCallback? onRestored;

  const _RecycleBinView({this.onRestored});

  static const _hPad = EdgeInsets.symmetric(horizontal: 18);

  Future<void> _restore(BuildContext context, RecycledDocument item) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await context.read<RecycleBinCubit>().restore(item);

    final error = result.error;
    final message = result.message;
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } else if (message != null) {
      onRestored?.call();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// "All" plus every source that has something in the bin.
  static List<HubSourceTab> _tabs(Map<HubSourceFilter, int> counts) => [
        for (final tab in HubSourceTabs.hubTabs)
          if (tab.$1 == HubSourceFilter.assigned)
            (tab.$1, 'All', Icons.delete_sweep_outlined)
          else if ((counts[tab.$1] ?? 0) > 0)
            tab,
      ];

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RecycleBinCubit>();

    return Scaffold(
      backgroundColor: HubPalette.background,
      body: SafeArea(
        child: BlocBuilder<RecycleBinCubit, RecycleBinState>(
          builder: (context, state) {
            final loaded = state is RecycleBinLoaded ? state : null;
            final counts = loaded?.counts ?? const {};

            return RefreshIndicator(
              color: HubPalette.accent,
              onRefresh: cubit.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 12, bottom: 28),
                children: [
                  const Padding(padding: _hPad, child: _Header()),
                  if (loaded != null && loaded.items.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Padding(
                      padding: _hPad,
                      child: HubSourceTabs(
                        selected: loaded.source,
                        counts: counts,
                        onChanged: cubit.selectSource,
                        tabs: _tabs(counts),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ..._body(context, state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, RecycleBinState state) {
    switch (state) {
      case RecycleBinInitial():
      case RecycleBinLoading():
        return const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: CircularProgressIndicator(color: HubPalette.accent),
            ),
          ),
        ];

      case RecycleBinError(:final message):
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 60, 18, 0),
            child: _Message(
              icon: Icons.error_outline_rounded,
              text: message,
              actionLabel: 'Retry',
              onAction: context.read<RecycleBinCubit>().load,
            ),
          ),
        ];

      case RecycleBinLoaded():
        final now = DateTime.now();
        final items = state.visible;

        if (items.isEmpty) {
          return const [
            Padding(
              padding: EdgeInsets.fromLTRB(18, 48, 18, 0),
              child: _Message(
                icon: Icons.delete_outline_rounded,
                text: 'Recycle bin is empty',
              ),
            ),
          ];
        }

        final soon = [
          for (final i in items)
            if (i.expiringSoon(now)) i,
        ];
        final recent = [
          for (final i in items)
            if (!i.expiringSoon(now)) i,
        ];

        Widget card(RecycledDocument item) => Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              // Delete forever: waiting on its API.
              child: RecycleBinCard(
                item: item,
                now: now,
                restoring: state.restoringIds.contains(item.document.id),
                onRestore: () => _restore(context, item),
              ),
            );

        return [
          if (soon.isNotEmpty) ...[
            const Padding(
              padding: _hPad,
              child: _SectionLabel(
                label: 'Expiring soon',
                color: Color(0xFFDC2626),
                halo: Color(0xFFFDECEC),
              ),
            ),
            const SizedBox(height: 12),
            for (final i in soon) card(i),
          ],
          if (recent.isNotEmpty) ...[
            if (soon.isNotEmpty) const SizedBox(height: 8),
            const Padding(
              padding: _hPad,
              child: _SectionLabel(
                label: 'Recently deleted',
                color: HubPalette.hint,
              ),
            ),
            const SizedBox(height: 12),
            for (final i in recent) card(i),
          ],
        ];
    }
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HubPalette.border),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: HubPalette.ink,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recycle Bin',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: HubPalette.ink,
                  height: 1.15,
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: HubPalette.muted,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Auto-deleted after 30 days',
                    style: TextStyle(fontSize: 13, color: HubPalette.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "● EXPIRING SOON" — dot (with an optional halo) and caps label.
class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  final Color? halo;

  const _SectionLabel({required this.label, required this.color, this.halo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: halo ?? Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: halo != null ? color : HubPalette.muted,
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 40, color: HubPalette.hint),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: HubPalette.muted),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 10),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}
