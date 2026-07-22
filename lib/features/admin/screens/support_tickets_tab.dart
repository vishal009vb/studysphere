import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class SupportTicketsTab extends StatefulWidget {
  const SupportTicketsTab({super.key});

  @override
  State<SupportTicketsTab> createState() => _SupportTicketsTabState();
}

class _SupportTicketsTabState extends State<SupportTicketsTab> {
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;
  String _filterStatus = 'All';

  static const List<String> _statusFilters = ['All', 'Pending', 'In Progress', 'Resolved', 'Closed'];


  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance
          .collection('supportTickets')
          .orderBy('createdAt', descending: true)
          .limit(100);

      final snap = await query.get();
      if (mounted) {
        setState(() {
          _tickets = snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String ticketId, String status) async {
    await FirebaseFirestore.instance.collection('supportTickets').doc(ticketId).update({'status': status});
    _loadTickets();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket marked as $status'), backgroundColor: AppColors.success),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return AppColors.warning;
      case 'in progress': return AppColors.blue;
      case 'resolved': return AppColors.success;
      case 'closed': return AppColors.textSecondary;
      default: return AppColors.textSecondary;
    }
  }

  List<Map<String, dynamic>> get _filteredTickets {
    if (_filterStatus == 'All') return _tickets;
    return _tickets.where((t) => (t['status'] ?? '').toString().toLowerCase() == _filterStatus.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Support Tickets', style: AppTextStyles.headingMedium),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                  onPressed: _loadTickets,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // Status filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusFilters.map((s) {
                  final isSelected = _filterStatus == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(s),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _filterStatus = s),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTickets.isEmpty
                    ? Center(child: Text('No tickets found.', style: AppTextStyles.bodyMedium))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: _filteredTickets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final ticket = _filteredTickets[i];
                          final status = ticket['status'] ?? 'Pending';
                          final createdAt = ticket['createdAt'] != null
                              ? (ticket['createdAt'] as Timestamp).toDate()
                              : DateTime.now();
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              title: Text(
                                ticket['subject'] ?? 'No Subject',
                                style: AppTextStyles.headingSmall.copyWith(fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        ticket['issueType'] ?? 'Unknown',
                                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _statusColor(status).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: _statusColor(status),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${ticket['userName'] ?? 'Unknown'} • ${DateFormat('MMM d, yyyy').format(createdAt)}',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      _infoRow('Email', ticket['email'] ?? '-'),
                                      _infoRow('User ID', ticket['userId'] ?? '-'),
                                      const SizedBox(height: 8),
                                      Text('Message:', style: AppTextStyles.labelMedium),
                                      const SizedBox(height: 4),
                                      Text(
                                        ticket['message'] ?? '',
                                        style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
                                      ),
                                      const SizedBox(height: 16),
                                      Text('Update Status:', style: AppTextStyles.labelMedium),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        children: ['Pending', 'In Progress', 'Resolved', 'Closed'].map((s) {
                                          return ActionChip(
                                            label: Text(s),
                                            backgroundColor: _statusColor(s).withOpacity(0.1),
                                            labelStyle: TextStyle(color: _statusColor(s), fontWeight: FontWeight.bold),
                                            onPressed: () => _updateStatus(ticket['id'], s),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text('$label:', style: AppTextStyles.bodySmall),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}
