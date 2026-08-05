import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/admin_log_service.dart';
import '../../../models/user_model.dart';
import 'dart:async';

class UsersTab extends ConsumerStatefulWidget {
  const UsersTab({super.key});

  @override
  ConsumerState<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<UsersTab> {
  List<UserModel> _users = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  String _searchField = 'name'; 
  String _roleFilter = 'All'; 
  String _statusFilter = 'All'; 
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isFetchingMore && _hasMore) {
        _loadMoreUsers();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _users = [];
      _lastDoc = null;
      _hasMore = true;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      String? role = _roleFilter == 'All' ? null : (_roleFilter == 'User' ? 'learner' : _roleFilter);
      final result = await firestoreService.getUsersPaginated(
        limit: 50,
        searchQuery: _searchQuery.trim(),
        searchField: _searchField,
        roleFilter: role,
        statusFilter: _statusFilter,
      );
      
      if (mounted) {
        setState(() {
          _users = result['users'] as List<UserModel>;
          _lastDoc = result['lastDoc'] as DocumentSnapshot?;
          _hasMore = _users.length >= 50;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading users: \$e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_lastDoc == null || !_hasMore) return;
    setState(() => _isFetchingMore = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      String? role = _roleFilter == 'All' ? null : (_roleFilter == 'User' ? 'learner' : _roleFilter);
      final result = await firestoreService.getUsersPaginated(
        startAfter: _lastDoc,
        limit: 50,
        searchQuery: _searchQuery.trim(),
        searchField: _searchField,
        roleFilter: role,
        statusFilter: _statusFilter,
      );

      final newUsers = result['users'] as List<UserModel>;
      if (mounted) {
        setState(() {
          _users.addAll(newUsers);
          _lastDoc = result['lastDoc'] as DocumentSnapshot?;
          _hasMore = newUsers.length >= 50;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = value;
      });
      _loadUsers();
    });
  }

  Future<void> _updateUserStatus(UserModel user, {bool? isBanned, bool? isSuspended, String? role, String? contributorRank}) async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final currentUser = ref.read(authStateProvider).value;
      
      await firestoreService.updateUserStatus(
        user.uid,
        isBanned: isBanned,
        isSuspended: isSuspended,
        role: role,
        contributorRank: contributorRank,
      );

      if (currentUser != null) {
        String action = 'Updated User Status';
        if (isBanned != null) {
          action = isBanned ? 'User Ban' : 'User Unban';
        } else if (isSuspended != null) {
          action = isSuspended ? 'User Warn' : 'User Remove Warning';
        } else if (role != null) {
          action = 'Changed User Role to $role';
        }

        await ref.read(adminLogServiceProvider).logAction(
          adminId: currentUser.uid,
          adminName: currentUser.displayName ?? currentUser.email ?? 'Admin',
          action: action,
          targetContent: 'User: \${user.email}',
          targetId: user.uid,
        );
      }

      // We just reload the first page after an update to reflect changes accurately
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully'), backgroundColor: AppColors.success),
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

  void _showEditUserDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Manage \${user.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Ban User'),
                trailing: Switch(
                  value: user.isBanned,
                  onChanged: (val) {
                    Navigator.pop(context);
                    _updateUserStatus(user, isBanned: val);
                  },
                ),
              ),
              ListTile(
                title: const Text('Suspend User'),
                trailing: Switch(
                  value: user.isSuspended,
                  onChanged: (val) {
                    Navigator.pop(context);
                    _updateUserStatus(user, isSuspended: val);
                  },
                ),
              ),
              ListTile(
                title: const Text('Promote to Admin'),
                trailing: Switch(
                  value: user.role == 'admin',
                  onChanged: (val) {
                    Navigator.pop(context);
                    _updateUserStatus(user, role: val ? 'admin' : 'learner');
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search & Filters Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _searchField,
                items: ['name', 'email'].map((e) => DropdownMenuItem(value: e, child: const Text('By \$e'))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _searchField = val);
                    if (_searchQuery.isNotEmpty) _loadUsers();
                  }
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _roleFilter,
                hint: const Text('Role'),
                items: ['All', 'Admin', 'Moderator', 'User'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _roleFilter = val);
                    _loadUsers();
                  }
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _statusFilter,
                hint: const Text('Status'),
                items: ['All', 'Suspended', 'Banned'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _statusFilter = val);
                    _loadUsers();
                  }
                },
              ),
            ],
          ),
        ),
        
        // List View
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Center(child: Text('No users found'))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _users.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _users.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final user = _users[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 1.5,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                              backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                              child: user.photoUrl.isEmpty ? const Icon(Icons.person, color: AppColors.primary) : null,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    user.name.isEmpty ? 'Student' : user.name,
                                    style: AppTextStyles.headingSmall.copyWith(fontSize: 15),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    '\$${(user.reputationPoints * 0.05).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF059669),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '${user.email} • ${user.role.toUpperCase()} • ${user.reputationPoints} pts',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (user.isBanned) const Icon(Icons.block, color: AppColors.error, size: 20),
                                if (user.isSuspended) const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                                IconButton(
                                  icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                                  onPressed: () => _showEditUserDialog(user),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
