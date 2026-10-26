// ══════════════════════════════════════════════════════════════
// DEAL DETAIL — PROPOSALS TAB
// GET /{tenantSlug}/api/deals/:id/proposals
// ══════════════════════════════════════════════════════════════
import 'package:crm_app/screen/deals/cubit/deals_cubit.dart';
import 'package:crm_app/screen/deals/modal/deal_modal.dart';
import 'package:crm_app/screen/proposal/UI/create_proposal_screen.dart';
import 'package:crm_app/screen/proposal/cubit/proposal_cubit.dart';
import 'package:crm_app/screen/proposal/modal/proposal_modal.dart';
import 'package:crm_app/thems/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class DealProposalsTab extends StatefulWidget {
  final Deal deal;
  final ScrollController controller;

  const DealProposalsTab({
    super.key,
    required this.deal,
    required this.controller,
  });

  @override
  State<DealProposalsTab> createState() => _DealProposalsTabState();
}

class _DealProposalsTabState extends State<DealProposalsTab> {
  late Future<List<Proposal>> _future;

  /// Local status overrides so a status change shows immediately,
  /// without refetching the whole list.
  final Map<String, String> _statusOverride = {};
  final Set<String> _updating = {};

  /// Same rule as CreateProposalScreen's deal picker: closed deals
  /// can't get new proposals.
  bool get _canCreate {
    final stage = DealConstants.canonicalStage(widget.deal.stage);
    return stage != 'Closed Won' && stage != 'Closed Lost';
  }

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<Proposal>> _fetch() =>
      context.read<DealsCubit>().getDealProposals(widget.deal.id);

  Future<void> _reload() async {
    final next = _fetch();
    setState(() {
      _statusOverride.clear();
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // Shown by the FutureBuilder's error state.
    }
  }

  Future<void> _changeStatus(Proposal p, String status) async {
    final current = _statusOf(p);
    if (status == current) return;

    setState(() {
      _statusOverride[p.id] = status;
      _updating.add(p.id);
    });
    try {
      await context.read<DealsCubit>().updateProposalStatus(p.id, status);
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusOverride[p.id] = current);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _updating.remove(p.id));
    }
  }

  /// New proposal ([existing] null) or edit an existing one; reloads
  /// the list when the form saves.
  Future<void> _openForm({Proposal? existing}) async {
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => ProposalCubit()),
            BlocProvider(create: (_) => DealsCubit()..loadDeals()),
          ],
          child: CreateProposalScreen(
            proposal: existing,
            initialDeal: widget.deal,
          ),
        ),
      ),
    );
    if (saved == true && mounted) await _reload();
  }

  String _statusOf(Proposal p) =>
      (_statusOverride[p.id] ?? p.status).trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          FutureBuilder<List<Proposal>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return _message(
                  'Failed to load proposals',
                  action: TextButton(
                    onPressed: _reload,
                    child: const Text('Retry'),
                  ),
                );
              }
              final proposals = [...?snap.data]..sort((a, b) =>
                  (b.createdAt ?? DateTime(0))
                      .compareTo(a.createdAt ?? DateTime(0)));
              if (proposals.isEmpty) return _message('No proposals yet');

              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView.separated(
                  controller: widget.controller,
                  physics: const AlwaysScrollableScrollPhysics(),
                  // bottom room so the last card clears the + button
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: proposals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _card(proposals[i]),
                ),
              );
            },
          ),
          if (_canCreate)
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton(
                heroTag: 'dealProposalFab',
                tooltip: 'New proposal',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                onPressed: _openForm,
                child: const Icon(Icons.add, size: 26),
              ),
            ),
        ],
      ),
    );
  }

  Widget _message(String text, {Widget? action}) => ListView(
        controller: widget.controller,
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (action != null) Center(child: action),
        ],
      );

  Widget _card(Proposal p) {
    final date = p.createdAt?.toLocal();
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openForm(existing: p),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.title.isEmpty ? 'Untitled proposal' : p.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      date == null ? '—' : DateFormat('MMM dd, yyyy').format(date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  _statusPill(p),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Status pill (tap to change) ──────────────────────────────

  /// Backend values → label + colour. Same set as the Proposals screen.
  static const _statuses = ['sent', 'no reply', 'success', 'rejection'];

  static String _label(String s) => switch (s) {
        'sent' => 'Sent',
        'no reply' => 'No reply',
        'success' => 'Success',
        'rejection' => 'Rejection',
        'draft' => 'Draft',
        _ => s.isEmpty ? '—' : '${s[0].toUpperCase()}${s.substring(1)}',
      };

  static Color _color(String s) => switch (s) {
        'sent' => const Color(0xFF2563EB),
        'success' => const Color(0xFF16A34A),
        'no reply' => const Color(0xFFD97706),
        'rejection' => const Color(0xFFDC2626),
        _ => AppColors.textSecondary,
      };

  Widget _statusPill(Proposal p) {
    final status = _statusOf(p);
    final color = _color(status);
    final isDraft = status == 'draft';
    final busy = _updating.contains(p.id);

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _label(status),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          if (busy)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          else
            Icon(
              isDraft ? Icons.lock_outline : Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: color,
            ),
        ],
      ),
    );

    // Drafts must be sent from the Proposals screen first.
    if (isDraft || busy) return pill;

    return PopupMenuButton<String>(
      tooltip: 'Change status',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (s) => _changeStatus(p, s),
      itemBuilder: (_) => [
        for (final s in _statuses)
          PopupMenuItem<String>(
            value: s,
            height: 40,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _color(s),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _label(s),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: s == status ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: pill,
    );
  }
}
