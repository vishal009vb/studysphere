import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/report_model.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/admin_log_service.dart';

class ReportsTab extends ConsumerStatefulWidget {
  const ReportsTab({super.key});

  @override
  ConsumerState<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<ReportsTab> {
  List<ReportModel> _reports = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadReports();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isFetchingMore && _hasMore) {
        _loadMoreReports();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _reports = [];
      _lastDoc = null;
      _hasMore = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final result = await firestoreService.getReportsPaginated(limit: 50);
      
      if (mounted) {
        setState(() {
          _reports = result['reports'] as List<ReportModel>;
          _lastDoc = result['lastDoc'] as DocumentSnapshot?;
          _hasMore = _reports.length >= 50;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading reports: \$e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreReports() async {
    if (_lastDoc == null || !_hasMore) return;
    setState(() => _isFetchingMore = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final result = await firestoreService.getReportsPaginated(
        startAfter: _lastDoc,
        limit: 50,
      );

      final newReports = result['reports'] as List<ReportModel>;
      if (mounted) {
        setState(() {
          _reports.addAll(newReports);
          _lastDoc = result['lastDoc'] as DocumentSnapshot?;
          _hasMore = newReports.length >= 50;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  Future<void> _updateReportStatus(ReportModel report, String newStatus) async {
    final firestoreService = ref.read(firestoreServiceProvider);
    final user = ref.read(authServiceProvider).currentUser;
    try {
      await firestoreService.resolveReport(report.reportId, newStatus);
      
      if (newStatus == 'content_removed') {
        if (report.contentType == 'note') {
          await FirebaseFirestore.instance.collection('notes').doc(report.contentId).delete();
        } else if (report.contentType == 'questionPaper' || report.contentType == 'paper') {
          await FirebaseFirestore.instance.collection('questionPapers').doc(report.contentId).delete();
        }
      }

      if (user != null) {
        await ref.read(adminLogServiceProvider).logAction(
          adminId: user.uid,
          adminName: user.displayName ?? 'Admin',
          action: 'Resolve Report - \$newStatus',
          targetContent: report.contentType,
          targetId: report.reportId,
        );
      }
      
      _loadReports();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report marked as \$newStatus'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: \$e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('User Reports', style: AppTextStyles.headingMedium),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                    ? Center(child: Text('No reports available.', style: AppTextStyles.bodyMedium))
                    : Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(AppColors.surface),
                              columns: const [
                                DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Reason', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: [
                                ..._reports.map((report) {
                                  final isPending = report.status == 'pending';
                                  
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(report.contentType.toUpperCase())),
                                      DataCell(Text(report.reason, style: const TextStyle(fontWeight: FontWeight.w500))),
                                      DataCell(Text(DateFormat('MMM dd, yyyy').format(report.createdAt))),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isPending ? AppColors.warning.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            report.status.toUpperCase(),
                                            style: TextStyle(
                                              color: isPending ? AppColors.warning : AppColors.success,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isPending) ...[
                                              TextButton(
                                                onPressed: () => _updateReportStatus(report, 'dismissed'),
                                                child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                                                onPressed: () => _updateReportStatus(report, 'content_removed'),
                                                child: const Text('Delete Content'),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                                if (_isFetchingMore)
                                  const DataRow(cells: [
                                    DataCell(CircularProgressIndicator()),
                                    DataCell(Text('Loading more...')),
                                    DataCell(Text('')),
                                    DataCell(Text('')),
                                    DataCell(Text('')),
                                  ])
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
