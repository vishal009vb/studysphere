import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/notification_model.dart';
import '../../../models/user_model.dart';
import '../../../core/widgets/animated_transition.dart';

class NotificationsTab extends ConsumerStatefulWidget {
  const NotificationsTab({super.key});

  @override
  ConsumerState<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends ConsumerState<NotificationsTab> {
  int _modeIndex = 0; // 0 = Public Global Broadcast, 1 = Direct User / Testing

  // Global Broadcast Form Controllers
  final _globalFormKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _routeController = TextEditingController();

  String _selectedPriority = 'normal';
  String _selectedType = 'announcement';
  String _selectedCourse = 'All';
  String _selectedSemester = 'All';
  bool _isSendingGlobal = false;

  // Direct User Notification Form Controllers
  final _directFormKey = GlobalKey<FormState>();
  final _targetUidController = TextEditingController();
  final _directTitleController = TextEditingController();
  final _directBodyController = TextEditingController();
  final _directRouteController = TextEditingController();

  String _directPriority = 'normal';
  String _directType = 'like';
  bool _isSendingDirect = false;

  final List<String> _priorities = ['low', 'normal', 'high', 'critical'];
  final List<String> _globalTypes = ['announcement', 'maintenance', 'exam_alert', 'update_available'];
  final List<String> _userTypes = [
    'like',
    'comment',
    'follow',
    'upload_approved',
    'upload_rejected',
    'ai_credits',
    'warning',
    'account_notice',
    'course_update',
    'update_available'
  ];
  final List<String> _courses = ['All', 'BCA', 'B.Tech / Engineering', 'B.Sc', 'B.Com', 'B.A', 'Diploma', 'Other'];
  final List<String> _semesters = ['All', 'Semester 1', 'Semester 2', 'Semester 3', 'Semester 4', 'Semester 5', 'Semester 6', 'Semester 7', 'Semester 8'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = ref.read(authServiceProvider).currentUser;
      if (currentUser != null && mounted) {
        setState(() {
          _targetUidController.text = currentUser.uid;
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _routeController.dispose();
    _targetUidController.dispose();
    _directTitleController.dispose();
    _directBodyController.dispose();
    _directRouteController.dispose();
    super.dispose();
  }

  void _useSelfUid() {
    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser != null) {
      setState(() {
        _targetUidController.text = currentUser.uid;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target UID set to your account!')),
      );
    }
  }

  Future<void> _showUserPickerDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.people_alt_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Select Target User'),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 450,
                child: FutureBuilder<List<UserModel>>(
                  future: ref.read(firestoreServiceProvider).fetchAllUsers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading users: ${snapshot.error}'));
                    }

                    final users = snapshot.data ?? [];
                    final filteredUsers = users.where((u) {
                      final q = searchQuery.toLowerCase().trim();
                      if (q.isEmpty) return true;
                      return u.name.toLowerCase().contains(q) ||
                          u.email.toLowerCase().contains(q) ||
                          u.username.toLowerCase().contains(q) ||
                          u.coursePreference.toLowerCase().contains(q) ||
                          u.uid.toLowerCase().contains(q);
                    }).toList();

                    return Column(
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search by Name, Email, Course, or UID...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (val) {
                            setDialogState(() {
                              searchQuery = val;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: filteredUsers.isEmpty
                              ? const Center(child: Text('No matching users found.'))
                              : ListView.separated(
                                  itemCount: filteredUsers.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final user = filteredUsers[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                        child: Text(
                                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      ),
                                      title: Text(
                                        user.name.isNotEmpty ? user.name : user.username,
                                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        '${user.email.isNotEmpty ? user.email : user.uid}\nCourse: ${user.coursePreference.isNotEmpty ? user.coursePreference : 'N/A'}',
                                        style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: user.role == 'admin' ? Colors.red.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          user.role.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: user.role == 'admin' ? Colors.red : AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _targetUidController.text = user.uid;
                                        });
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Selected user: ${user.name.isNotEmpty ? user.name : user.uid}')),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Broadcast to Everyone / Targeted Course
  Future<void> _sendGlobalNotification() async {
    if (!_globalFormKey.currentState!.validate()) return;
    
    setState(() => _isSendingGlobal = true);
    try {
      await ref.read(firestoreServiceProvider).sendGlobalAnnouncement(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        priority: _selectedPriority,
        type: _selectedType,
        targetCourse: _selectedCourse,
        targetSemester: _selectedSemester,
        route: _routeController.text.trim().isEmpty ? null : _routeController.text.trim(),
        expiryDays: 30,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Targeted global announcement broadcasted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        _titleController.clear();
        _bodyController.clear();
        _routeController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send announcement: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingGlobal = false);
    }
  }

  // Send Direct Personal Notification to Specific User
  Future<void> _sendDirectNotification() async {
    if (!_directFormKey.currentState!.validate()) return;
    
    final targetUid = _targetUidController.text.trim();
    final adminUser = ref.read(authServiceProvider).currentUser;

    setState(() => _isSendingDirect = true);
    try {
      final notif = NotificationModel(
        notificationId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        receiverId: targetUid,
        senderId: adminUser?.uid ?? 'admin',
        senderName: 'StudySphere Admin',
        type: _directType,
        contentId: 'direct_admin_${DateTime.now().millisecondsSinceEpoch}',
        title: _directTitleController.text.trim(),
        body: _directBodyController.text.trim(),
        route: _directRouteController.text.trim().isEmpty ? null : _directRouteController.text.trim(),
        priority: _directPriority,
        createdAt: DateTime.now(),
      );

      await ref.read(firestoreServiceProvider).sendNotification(notif);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Direct notification sent to user: $targetUid'),
            backgroundColor: AppColors.success,
          ),
        );
        _directTitleController.clear();
        _directBodyController.clear();
        _directRouteController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send direct notification: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingDirect = false);
    }
  }

  // Quick Preset Test Buttons
  Future<void> _sendQuickPreset(String type) async {
    final targetUid = _targetUidController.text.trim();
    if (targetUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or select a Target User UID first!'), backgroundColor: AppColors.error),
      );
      return;
    }

    final adminUser = ref.read(authServiceProvider).currentUser;
    NotificationModel notif;

    switch (type) {
      case 'like':
        notif = NotificationModel(
          notificationId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          receiverId: targetUid,
          senderId: adminUser?.uid ?? 'user_123',
          senderName: 'Rahul Sharma',
          type: 'like',
          contentId: 'note_demo',
          title: 'New Like ❤️',
          body: 'Rahul Sharma liked your note "Data Structures & Algorithms Unit 1"',
          route: '/notes',
          priority: 'low',
          createdAt: DateTime.now(),
        );
        break;
      case 'comment':
        notif = NotificationModel(
          notificationId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          receiverId: targetUid,
          senderId: adminUser?.uid ?? 'user_456',
          senderName: 'Priya Patel',
          type: 'comment',
          contentId: 'post_demo',
          title: 'New Comment 💬',
          body: 'Priya Patel commented: "Awesome study notes! Thanks for sharing."',
          route: '/community',
          priority: 'normal',
          createdAt: DateTime.now(),
        );
        break;
      case 'follow':
        notif = NotificationModel(
          notificationId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          receiverId: targetUid,
          senderId: adminUser?.uid ?? 'user_789',
          senderName: 'Amit Verma',
          type: 'follow',
          contentId: 'user_789',
          title: 'New Follower 👤',
          body: 'Amit Verma started following your profile.',
          route: '/profile',
          priority: 'normal',
          createdAt: DateTime.now(),
        );
        break;
      case 'upload_approved':
        notif = NotificationModel(
          notificationId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          receiverId: targetUid,
          senderId: 'system',
          senderName: 'StudySphere Team',
          type: 'upload_approved',
          contentId: 'note_approved_demo',
          title: 'Note Approved 🎉',
          body: 'Your note "Operating Systems MCQ Set" was approved by moderators! You earned +10 Reputation Points.',
          route: '/notes',
          priority: 'high',
          createdAt: DateTime.now(),
        );
        break;
      case 'upload_rejected':
        notif = NotificationModel(
          notificationId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          receiverId: targetUid,
          senderId: 'system',
          senderName: 'StudySphere Team',
          type: 'upload_rejected',
          contentId: 'note_rejected_demo',
          title: 'Note Review Update',
          body: 'Your note upload did not meet quality guidelines. Please check community guidelines.',
          priority: 'normal',
          createdAt: DateTime.now(),
        );
        break;
      case 'ai_credits':
        notif = NotificationModel(
          notificationId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          receiverId: targetUid,
          senderId: 'system',
          senderName: 'StudySphere AI',
          type: 'ai_credits',
          contentId: 'ai_reset',
          title: 'Daily AI Limit Reset 🤖',
          body: 'Your daily AI assistant queries have been reset to 10 queries. Ask away!',
          route: '/ai',
          priority: 'normal',
          createdAt: DateTime.now(),
        );
        break;
      case 'warning':
      default:
        notif = NotificationModel(
          notificationId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
          receiverId: targetUid,
          senderId: 'system',
          senderName: 'Security Desk',
          type: 'warning',
          contentId: 'security_warn',
          title: 'Critical Security Alert 🚨',
          body: 'Important account security notice. Please verify your email preferences.',
          priority: 'critical',
          createdAt: DateTime.now(),
        );
        break;
    }

    try {
      await ref.read(firestoreServiceProvider).sendNotification(notif);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test preset notification ($type) sent to $targetUid!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send test: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteAnnouncement(String docId) async {
    try {
      await ref.read(firestoreServiceProvider).deleteGlobalAnnouncement(docId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement deleted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin Notification Center', style: AppTextStyles.headingMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Broadcast global announcements or send direct test notifications to a specific user.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Segment Switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _modeIndex = 0),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _modeIndex == 0 ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign_rounded, size: 18, color: _modeIndex == 0 ? Colors.white : AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'Global Broadcast',
                            style: TextStyle(
                              color: _modeIndex == 0 ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _modeIndex = 1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _modeIndex == 1 ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_pin_rounded, size: 18, color: _modeIndex == 1 ? Colors.white : AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'Direct User / Test Mode',
                            style: TextStyle(
                              color: _modeIndex == 1 ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          if (_modeIndex == 0) _buildGlobalForm() else _buildDirectUserForm(),
          
          const SizedBox(height: 40),
          Text('Global Broadcast History', style: AppTextStyles.headingSmall),
          const SizedBox(height: 16),
          _buildBroadcastHistory(),
        ],
      ),
    );
  }

  // ── Global Announcement Form ───────────────────────────────────────────────
  Widget _buildGlobalForm() {
    return AnimatedTransition.slideUp(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: Color(0x0a000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Form(
          key: _globalFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Broadcast Announcement (Everyone or Targeted)', style: AppTextStyles.headingSmall),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Notification Title',
                  hintText: 'e.g. Mid-Sem Exam Schedule Released',
                  prefixIcon: Icon(Icons.campaign_rounded),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Title required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notification Body',
                  hintText: 'Details about this global announcement...',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.notes_rounded),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Body required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedPriority,
                      decoration: const InputDecoration(labelText: 'Priority Level', prefixIcon: Icon(Icons.flag_rounded)),
                      items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))).toList(),
                      onChanged: (val) => setState(() => _selectedPriority = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_rounded)),
                      items: _globalTypes.map((t) => DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' ').toUpperCase()))).toList(),
                      onChanged: (val) => setState(() => _selectedType = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCourse,
                      decoration: const InputDecoration(labelText: 'Target Course', prefixIcon: Icon(Icons.school_rounded)),
                      items: _courses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _selectedCourse = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSemester,
                      decoration: const InputDecoration(labelText: 'Target Semester', prefixIcon: Icon(Icons.class_rounded)),
                      items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) => setState(() => _selectedSemester = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _routeController,
                decoration: const InputDecoration(
                  labelText: 'Deep Link Route (Optional)',
                  hintText: 'e.g. /notes, /courses, /community',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSendingGlobal ? null : _sendGlobalNotification,
                icon: _isSendingGlobal 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: Text(_isSendingGlobal ? 'Broadcasting...' : 'Broadcast Announcement'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Direct Personal User Notification & Testing Form ──────────────────────
  Widget _buildDirectUserForm() {
    return AnimatedTransition.slideUp(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          boxShadow: const [BoxShadow(color: Color(0x0a000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Form(
          key: _directFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text('Direct User Notification & Quick Test Suite', style: AppTextStyles.headingSmall),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showUserPickerDialog,
                        icon: const Icon(Icons.people_alt_rounded, size: 16),
                        label: const Text('Pick User from List'),
                        style: ElevatedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _useSelfUid,
                        icon: const Icon(Icons.person, size: 16),
                        label: const Text('Send to My Account'),
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetUidController,
                decoration: InputDecoration(
                  labelText: 'Target User UID (Receiver)',
                  hintText: 'Select user from list or paste UID',
                  prefixIcon: const Icon(Icons.fingerprint_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.person_search_rounded, color: AppColors.primary),
                    tooltip: 'Search & Pick User',
                    onPressed: _showUserPickerDialog,
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'User UID required' : null,
              ),
              const SizedBox(height: 24),
              
              // Preset Quick Test Buttons
              Text('🧪 1-Click Quick Notification Test Buttons:', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Text('❤️'),
                    label: const Text('Test Like'),
                    onPressed: () => _sendQuickPreset('like'),
                  ),
                  ActionChip(
                    avatar: const Text('💬'),
                    label: const Text('Test Comment'),
                    onPressed: () => _sendQuickPreset('comment'),
                  ),
                  ActionChip(
                    avatar: const Text('👤'),
                    label: const Text('Test Follow'),
                    onPressed: () => _sendQuickPreset('follow'),
                  ),
                  ActionChip(
                    avatar: const Text('🎉'),
                    label: const Text('Test Upload Approved'),
                    onPressed: () => _sendQuickPreset('upload_approved'),
                  ),
                  ActionChip(
                    avatar: const Text('❌'),
                    label: const Text('Test Upload Rejected'),
                    onPressed: () => _sendQuickPreset('upload_rejected'),
                  ),
                  ActionChip(
                    avatar: const Text('🤖'),
                    label: const Text('Test AI Credits Reset'),
                    onPressed: () => _sendQuickPreset('ai_credits'),
                  ),
                  ActionChip(
                    avatar: const Text('🚨'),
                    label: const Text('Test Critical Warning'),
                    onPressed: () => _sendQuickPreset('warning'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              Text('Custom Direct Message', style: AppTextStyles.headingSmall.copyWith(fontSize: 15)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _directTitleController,
                decoration: const InputDecoration(
                  labelText: 'Notification Title',
                  hintText: 'e.g. Account Security Update',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Title required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _directBodyController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notification Body',
                  hintText: 'Message content for this user...',
                  prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Body required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _directPriority,
                      decoration: const InputDecoration(labelText: 'Priority Level', prefixIcon: Icon(Icons.flag_rounded)),
                      items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))).toList(),
                      onChanged: (val) => setState(() => _directPriority = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _directType,
                      decoration: const InputDecoration(labelText: 'Type Icon', prefixIcon: Icon(Icons.category_rounded)),
                      items: _userTypes.map((t) => DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' ').toUpperCase()))).toList(),
                      onChanged: (val) => setState(() => _directType = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _directRouteController,
                decoration: const InputDecoration(
                  labelText: 'Deep Link Route (Optional)',
                  hintText: 'e.g. /notes/123, /community, /courses',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSendingDirect ? null : _sendDirectNotification,
                icon: _isSendingDirect 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: Text(_isSendingDirect ? 'Sending Direct Msg...' : 'Send Direct Message to User'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Broadcast History List ──────────────────────────────────────────────────
  Widget _buildBroadcastHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('global_notifications')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No announcements broadcasted yet.'));
        }
        
        final docs = snapshot.data!.docs;
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            final title = data['title'] ?? '';
            final body = data['body'] ?? '';
            final priority = data['priority'] ?? 'normal';
            final targetCourse = data['targetCourse'] ?? 'All';
            final targetSem = data['targetSemester'] ?? 'All';
            final time = data['createdAt'] as Timestamp?;
            
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: priority == 'critical' ? AppColors.error : AppColors.border,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.campaign_rounded,
                              color: priority == 'critical' ? AppColors.error : AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(title, style: AppTextStyles.headingSmall.copyWith(fontSize: 15))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: priority == 'critical'
                                    ? AppColors.error
                                    : (priority == 'high' ? Colors.orange : AppColors.primary.withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                priority.toUpperCase(),
                                style: TextStyle(
                                  color: (priority == 'critical' || priority == 'high') ? Colors.white : AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(body, style: AppTextStyles.bodyMedium),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Audience: $targetCourse ($targetSem)',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                            ),
                            const Spacer(),
                            if (time != null)
                              Text(
                                time.toDate().toString().split('.')[0],
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                    tooltip: 'Delete Announcement',
                    onPressed: () => _deleteAnnouncement(id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
