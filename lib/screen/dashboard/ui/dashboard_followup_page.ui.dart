import 'package:crm_app/modals/followup_model.dart';
import 'package:crm_app/screen/deals/ui/deal_screen.dart';
import 'package:crm_app/screen/leads/ui/lead_screen.dart';
import 'package:crm_app/thems/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

enum _FollowUpFilter { all, leads, deals }

class FollowUpsScreen extends StatefulWidget {
  final List<FollowUpItem> items;
  const FollowUpsScreen({super.key, required this.items});

  @override
  State<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends State<FollowUpsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _FollowUpFilter _filter = _FollowUpFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FollowUpItem> get _filtered {
    var list = widget.items;

    if (_filter == _FollowUpFilter.leads) {
      list = list.where((i) => i.type == FollowUpType.lead).toList();
    } else if (_filter == _FollowUpFilter.deals) {
      list = list.where((i) => i.type == FollowUpType.deal).toList();
    }

    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      list = list.where((i) {
        return i.title.toLowerCase().contains(q) ||
            i.subtitle.toLowerCase().contains(q) ||
            (i.phone ?? '').contains(q);
      }).toList();
    }

    return list;
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to place call.')),
      );
    }
  }

  // Opens the Leads screen with this lead's detail sheet on top.
  void _viewLead(FollowUpItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeadsScreen(
          selectedLeadId: item.id,
          showBackButton: true,
        ),
      ),
    );
  }

  // Opens the Deals screen with this deal's detail sheet on top.
  void _openDeal(FollowUpItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DealsScreen(
          selectedDealId: item.id,
          showBackButton: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());
    final items = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Follow-ups",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text(today,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
      body: Column(children: [
        // ── Search ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search Follow-up...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),

        // ── Filter tabs ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _FilterChip(
              label: 'All',
              selected: _filter == _FollowUpFilter.all,
              onTap: () => setState(() => _filter = _FollowUpFilter.all),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Leads',
              selected: _filter == _FollowUpFilter.leads,
              onTap: () => setState(() => _filter = _FollowUpFilter.leads),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Deals',
              selected: _filter == _FollowUpFilter.deals,
              onTap: () => setState(() => _filter = _FollowUpFilter.deals),
            ),
          ]),
        ),

        const SizedBox(height: 8),

        // ── List ────────────────────────────────────────────
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text('No follow-ups found',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: items.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FollowUpDetailCard(
                      item: items[i],
                      onCall: _call,
                      onViewLead: _viewLead,
                      onOpenDeal: _openDeal,
                    ),
                  ),
                ),
        ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary)),
        ),
      );
}

class _FollowUpDetailCard extends StatelessWidget {
  final FollowUpItem item;
  final void Function(String phone) onCall;
  final void Function(FollowUpItem item) onViewLead;
  final void Function(FollowUpItem item) onOpenDeal;

  const _FollowUpDetailCard({
    required this.item,
    required this.onCall,
    required this.onViewLead,
    required this.onOpenDeal,
  });

  bool get _isLead => item.type == FollowUpType.lead;
  Color get _accent => _isLead ? AppColors.primary : AppColors.success;

  String get _timeLabel => DateFormat('hh:mm a').format(item.followUpDate);

  String get _valueLabel {
    if (item.dealValue == null) return '';
    final f = NumberFormat.currency(
      locale: item.currency == 'INR' ? 'en_IN' : 'en_US',
      symbol: item.currency == 'INR' ? '₹' : (item.currency ?? ''),
      decimalDigits: 0,
    );
    return f.format(item.dealValue);
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Type header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: _accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(_isLead ? 'Lead' : 'Deal',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _accent)),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_isLead ? Icons.person_outline : Icons.business_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(item.title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
              ]),
              const SizedBox(height: 6),

              if (_isLead && (item.phone ?? '').isNotEmpty)
                _InfoRow(icon: Icons.call_outlined, text: item.phone!),
              if (!_isLead && item.dealValue != null)
                _InfoRow(
                    icon: Icons.currency_rupee_rounded, text: _valueLabel),

              _InfoRow(icon: Icons.access_time_rounded, text: _timeLabel),
              _InfoRow(icon: Icons.assignment_outlined, text: item.subtitle),

             
              const SizedBox(height: 12),

              Row(children: [
                if (_isLead) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (item.phone ?? '').isEmpty
                          ? null
                          : () => onCall(item.phone!),
                      icon: const Icon(Icons.call_outlined, size: 16),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onViewLead(item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('View'),
                    ),
                  ),
                ] else
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onOpenDeal(item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('Open Deal'),
                    ),
                  ),
              ]),
            ]),
          ),
        ]),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ]),
      );
}