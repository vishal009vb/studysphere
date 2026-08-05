import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_cache_provider.dart';
import '../../core/utils/time_formatter.dart';
import '../../models/notification_model.dart';
import '../../models/global_notification_model.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _markAllRead() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user != null) {
      await ref.read(firestoreServiceProvider).markAllNotificationsAsRead(user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userNotifsAsync = ref.watch(userNotificationsStreamProvider);
    final globalNotifsAsync = ref.watch(globalAnnouncementsStreamProvider);
    final unreadCount = ref.watch(unreadNotifCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Notifications', style: AppTextStyles.headingMedium),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all_rounded, size: 18, color: AppColors.primary),
              label: const Text(
                'Mark read',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            tooltip: 'Notification Settings',
            onPressed: () => context.push('/notification-settings'),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.campaign_rounded, size: 18),
                  const SizedBox(width: 6),
                  const Text('Announcements'),
                  if (globalNotifsAsync.value?.isNotEmpty ?? false) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${globalNotifsAsync.value!.length}',
                        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt_rounded, size: 18),
                  const SizedBox(width: 6),
                  const Text('Activity'),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TAB 1: Global Announcements ──────────────────────────────────
          RefreshIndicator(
            onRefresh: () async => ref.refresh(globalAnnouncementsStreamProvider),
            child: globalNotifsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading announcements: $err')),
              data: (announcements) {
                if (announcements.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'No Announcements Yet',
                    subtitle: 'Stay tuned! Important platform updates and exam alerts will appear here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: announcements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = announcements[index];
                    return _buildGlobalAnnouncementCard(context, item);
                  },
                );
              },
            ),
          ),

          // ── TAB 2: Personal Activity ────────────────────────────────────
          RefreshIndicator(
            onRefresh: () async => ref.refresh(userNotificationsStreamProvider),
            child: userNotifsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error loading activity: $err')),
              data: (notifications) {
                if (notifications.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'No Activity Notifications',
                    subtitle: 'Likes, comments, followers, and upload updates will be listed here.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    return _buildActivityCard(context, item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Global Announcement Card ───────────────────────────────────────────────
  Widget _buildGlobalAnnouncementCard(BuildContext context, GlobalNotificationModel item) {
    final priorityColor = _getPriorityColor(item.priority);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.priority == 'critical' ? AppColors.error : AppColors.border,
          width: item.priority == 'critical' ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: priorityColor.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIconForType(item.type), color: priorityColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTextStyles.headingSmall.copyWith(fontSize: 15),
                          ),
                        ),
                        if (item.priority == 'critical' || item.priority == 'high')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: priorityColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.priority.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      TimeFormatter.timeAgo(item.createdAt),
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(item.body, style: AppTextStyles.bodyMedium),
          if (item.targetCourse != 'All' || item.targetSemester != 'All') ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                if (item.targetCourse != 'All')
                  Chip(
                    label: Text('Target: ${item.targetCourse}'),
                    backgroundColor: AppColors.surfaceLowest,
                    labelStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    visualDensity: VisualDensity.compact,
                  ),
                if (item.targetSemester != 'All')
                  Chip(
                    label: Text(item.targetSemester),
                    backgroundColor: AppColors.surfaceLowest,
                    labelStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (item.route != null && item.route!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => context.push(item.route!),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(item.actionLabel ?? 'View Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Personal Activity Card (Swipe to Dismiss) ──────────────────────────────
  Widget _buildActivityCard(BuildContext context, NotificationModel item) {
    final priorityColor = _getPriorityColor(item.priority);
    final iconData = _getIconForType(item.type);

    return Dismissible(
      key: Key(item.notificationId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      onDismissed: (_) async {
        await ref.read(firestoreServiceProvider).deleteNotification(item.notificationId);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final route = item.route;
            if (!item.read) {
              await ref.read(firestoreServiceProvider).markNotificationAsRead(item.notificationId);
            }
            if (mounted && route != null && route.isNotEmpty) {
              GoRouter.of(context).push(route);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: item.read ? Colors.white : AppColors.primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: item.read ? AppColors.border : AppColors.primary.withOpacity(0.3),
                width: item.read ? 1.0 : 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconData, color: priorityColor, size: 20),
                    ),
                    if (!item.read)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: AppTextStyles.headingSmall.copyWith(
                                fontSize: 14,
                                fontWeight: item.read ? FontWeight.w600 : FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            TimeFormatter.timeAgo(item.createdAt),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: item.read ? AppColors.textSecondary : AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helper Icon Selector ───────────────────────────────────────────────────
  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'like':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.chat_bubble_rounded;
      case 'follow':
        return Icons.person_add_rounded;
      case 'upload_approved':
        return Icons.verified_rounded;
      case 'upload_rejected':
        return Icons.cancel_rounded;
      case 'ai_credits':
        return Icons.smart_toy_rounded;
      case 'warning':
      case 'account_notice':
        return Icons.warning_rounded;
      case 'update_available':
      case 'system':
        return Icons.rocket_launch_rounded;
      case 'course_update':
      case 'exam_alert':
        return Icons.school_rounded;
      case 'announcement':
      default:
        return Icons.campaign_rounded;
    }
  }

  // ── Helper Priority Color Selector ──────────────────────────────────────────
  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return AppColors.error;
      case 'high':
        return Colors.orange;
      case 'normal':
        return AppColors.primary;
      case 'low':
      default:
        return AppColors.secondary;
    }
  }

  // ── Empty State Component ──────────────────────────────────────────────────
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title, style: AppTextStyles.headingMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
