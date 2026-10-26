import 'dart:ui';

import 'package:crm_app/modals/modals.dart';
import 'package:crm_app/screen/leads/cubit/lead_cubit.dart'
    show MissedFollowupPage;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _headerStart = Color(0xFF2B3EAE);
const _headerEnd = Color(0xFF3A5BD9);
const _accent = Color(0xFF2F45C2);
const _accentSoft = Color(0xFFE8EDFF);
const _accentBorder = Color(0xFFC7D2FE);
const _listBg = Color(0xFFF5F7FF);
const _textPrimary = Color(0xFF0F172A);
const _textSecondary = Color(0xFF64748B);
const _iconMuted = Color(0xFF94A3B8);

class MissedFollowupDialog extends StatefulWidget {
  /// Page 1, already fetched by the caller (it decides whether to show
  /// the popup at all).
  final MissedFollowupPage firstPage;

  /// Fetches the given page number; called when the list nears its end.
  final Future<MissedFollowupPage> Function(int page) loadPage;
  final ValueChanged<Lead> onViewLead;

  const MissedFollowupDialog({
    super.key,
    required this.firstPage,
    required this.loadPage,
    required this.onViewLead,
  });

  @override
  State<MissedFollowupDialog> createState() => _MissedFollowupDialogState();
}

class _MissedFollowupDialogState extends State<MissedFollowupDialog> {
  final _scroll = ScrollController();
  late final List<Lead> _leads = [...widget.firstPage.leads];
  late int _page = widget.firstPage.page;
  late int _total = widget.firstPage.total;
  late bool _hasMore = widget.firstPage.hasMore;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // A tall screen may fit the whole first page with nothing to scroll —
    // fetch the next one straight away so scrolling becomes possible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _scroll.hasClients &&
          _scroll.position.maxScrollExtent <= 0) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 200) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || _failed) return;
    setState(() => _loading = true);
    try {
      final next = await widget.loadPage(_page + 1);
      if (!mounted) return;
      setState(() {
        final seen = _leads.map((l) => l.id).toSet();
        _leads.addAll(next.leads.where((l) => seen.add(l.id)));
        _page = next.page;
        _total = next.total;
        _hasMore = next.hasMore && next.leads.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Missed follow-ups page ${_page + 1} failed: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _retry() {
    setState(() => _failed = false);
    _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final showFooterRow = _hasMore || _loading;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 30,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.of(context).size.height * .78,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(count: _total),

              /// LIST — 10 at a time, next page near the bottom
              Flexible(
                child: Container(
                  color: _listBg,
                  child: RawScrollbar(
                    controller: _scroll,
                    thumbVisibility: true,
                    interactive: true,
                    thickness: 4,
                    radius: const Radius.circular(4),
                    thumbColor: _accent.withOpacity(0.45),
                    mainAxisMargin: 10,
                    crossAxisMargin: 4,
                    child: ListView.separated(
                      controller: _scroll,
                      shrinkWrap: true,
                      // Right inset leaves room for the scrollbar thumb.
                      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                      itemCount: _leads.length + (showFooterRow ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        if (index == _leads.length) {
                          return _LoadMoreRow(
                            failed: _failed,
                            onRetry: _retry,
                          );
                        }
                        final lead = _leads[index];
                        return _LeadCard(
                          lead: lead,
                          onView: () => widget.onViewLead(lead),
                        );
                      },
                    ),
                  ),
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              /// FOOTER
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: _accentSoft,
                      foregroundColor: _accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Dismiss",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int count;

  const _Header({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_headerStart, _headerEnd],
        ),
      ),
      child: Stack(
        children: [
          /// Decorative circles
          Positioned(
            right: -60,
            top: -30,
            child: _circle(200),
          ),
          Positioned(
            left: -50,
            bottom: -70,
            child: _circle(140),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Title + count badge flow as one text run: the title
                    // gets the whole row, and on a narrow screen the badge
                    // wraps under it instead of cutting "Follow-ups" off.
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: "Missed Follow-ups "),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "$count",
                                  style: const TextStyle(
                                    color: _accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Material(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.pop(context),
                        child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Text(
                  "The following follow-ups are overdue. "
                  "Please update them as soon as possible.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.06),
      ),
    );
  }
}

class _LoadMoreRow extends StatelessWidget {
  final bool failed;
  final VoidCallback onRetry;

  const _LoadMoreRow({required this.failed, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Center(
        child: failed
            ? TextButton.icon(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: _accent),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  "Couldn't load more — Retry",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              )
            : const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: _accent,
                ),
              ),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback onView;

  const _LeadCard({required this.lead, required this.onView});

  @override
  Widget build(BuildContext context) {
    final name = lead.name.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          /// Avatar
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              name.isEmpty ? "?" : name[0].toUpperCase(),
              style: const TextStyle(
                color: _accent,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(width: 12),

          /// Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? "-" : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (lead.companyName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _infoRow(Icons.apartment_outlined, lead.companyName),
                ],
                const SizedBox(height: 3),
                _infoRow(
                  Icons.calendar_today_outlined,
                  lead.followUpDate == null
                      ? "-"
                      : DateFormat("dd MMM yyyy").format(lead.followUpDate!),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          /// View Lead
          OutlinedButton.icon(
            onPressed: onView,
            style: OutlinedButton.styleFrom(
              foregroundColor: _accent,
              side: const BorderSide(color: _accentBorder),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text(
              "View Lead",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _iconMuted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
