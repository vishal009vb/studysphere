import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../providers/app_cache_provider.dart';
import '../../models/notification_model.dart';
import '../../models/global_notification_model.dart';
import '../../services/firestore_service.dart';

class InAppNotificationOverlayManager extends ConsumerStatefulWidget {
  final Widget child;
  const InAppNotificationOverlayManager({super.key, required this.child});

  @override
  ConsumerState<InAppNotificationOverlayManager> createState() => _InAppNotificationOverlayManagerState();
}

class _InAppNotificationOverlayManagerState extends ConsumerState<InAppNotificationOverlayManager>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  NotificationModel? _currentBannerNotif;
  Timer? _autoDismissTimer;
  final Set<String> _seenNotificationIds = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _showBanner(NotificationModel notification) {
    _autoDismissTimer?.cancel();
    setState(() {
      _currentBannerNotif = notification;
    });
    _animController.forward(from: 0);

    _autoDismissTimer = Timer(const Duration(seconds: 5), () {
      _hideBanner();
    });
  }

  void _hideBanner() {
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentBannerNotif = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to real-time user activity notifications
    ref.listen<AsyncValue<List<NotificationModel>>>(
      userNotificationsStreamProvider,
      (previous, next) {
        if (next.hasValue && next.value != null && next.value!.isNotEmpty) {
          final latest = next.value!.first;
          // Only show banner if notification is unread and has not been displayed yet in this session
          if (!latest.read && !_seenNotificationIds.contains(latest.notificationId)) {
            _seenNotificationIds.add(latest.notificationId);
            _showBanner(latest);
          }
        }
      },
    );

    // Listen to real-time global announcements
    ref.listen<AsyncValue<List<GlobalNotificationModel>>>(
      globalAnnouncementsStreamProvider,
      (previous, next) {
        if (next.hasValue && next.value != null && next.value!.isNotEmpty) {
          final latest = next.value!.first;
          final notifId = 'global_${latest.id}';
          if (!_seenNotificationIds.contains(notifId)) {
            _seenNotificationIds.add(notifId);
            _showBanner(NotificationModel(
              notificationId: notifId,
              receiverId: 'all',
              senderId: 'admin',
              senderName: 'StudySphere Announcement',
              type: latest.type,
              contentId: latest.id,
              title: latest.title,
              body: latest.body,
              route: latest.route,
              priority: latest.priority,
              createdAt: latest.createdAt,
            ));
          }
        }
      },
    );

    return Stack(
      children: [
        widget.child,
        if (_currentBannerNotif != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: SlideTransition(
                position: _slideAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onVerticalDragUpdate: (details) {
                      if (details.primaryDelta != null && details.primaryDelta! < -5) {
                        _hideBanner();
                      }
                    },
                    onTap: () async {
                      final notif = _currentBannerNotif;
                      final router = GoRouter.of(context);
                      _hideBanner();
                      if (notif != null) {
                        final route = notif.route;
                        await ref.read(firestoreServiceProvider).markNotificationAsRead(notif.notificationId);
                        if (route != null && route.isNotEmpty) {
                          router.push(route);
                        }
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getPriorityBorderColor(_currentBannerNotif!.priority),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1a000000),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(_currentBannerNotif!.priority).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getIconForType(_currentBannerNotif!.type),
                              color: _getPriorityColor(_currentBannerNotif!.priority),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _currentBannerNotif!.title,
                                        style: AppTextStyles.headingSmall.copyWith(fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      'Just now',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currentBannerNotif!.body,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                            onPressed: _hideBanner,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

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

  Color _getPriorityBorderColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return AppColors.error;
      case 'high':
        return Colors.orange;
      case 'normal':
      default:
        return AppColors.primary.withValues(alpha: 0.3);
    }
  }
}
