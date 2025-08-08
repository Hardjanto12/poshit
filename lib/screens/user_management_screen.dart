import 'package:flutter/material.dart';
import 'package:poshit/api/api_client.dart';
import 'package:poshit/services/user_session_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _api = ApiClient();
  final _session = UserSessionService();
  late Future<List<Map<String, dynamic>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchUsers();
    // Guard access: show toast and immediately go back instead of blocking screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final role = _session.currentRole;
      if (role != 'owner' && role != 'manager') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient permissions')),
        );
        Navigator.of(context).pop();
      }
    });
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    try {
      final list = await _api.getJsonList('/users');
      return list.cast<Map<String, dynamic>>();
    } on ApiError catch (e) {
      if (!mounted) return [];
      final msg = e.statusCode == 403
          ? 'Insufficient permissions'
          : 'Error loading users';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return [];
    }
  }

  void _refresh() {
    setState(() {
      _usersFuture = _fetchUsers();
    });
  }

  Future<void> _createUserDialog() async {
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String role = 'cashier';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: usernameCtrl,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: passwordCtrl,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            DropdownButtonFormField<String>(
              value: role,
              items: const [
                DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                DropdownMenuItem(value: 'manager', child: Text('Manager')),
                DropdownMenuItem(value: 'owner', child: Text('Owner')),
              ],
              onChanged: (v) => role = v ?? 'cashier',
              decoration: const InputDecoration(labelText: 'Role'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _api.postJson('/users', {
        'name': nameCtrl.text.trim(),
        'username': usernameCtrl.text.trim(),
        'password': passwordCtrl.text,
        'role': role,
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      final msg = e.statusCode == 403
          ? 'Insufficient permissions'
          : 'Failed to create user';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    _refresh();
  }

  Future<void> _updateUserDialog(Map<String, dynamic> user) async {
    String role = user['role'] as String? ?? 'cashier';
    bool isActive = user['is_active'] as bool? ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update ${user['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: role,
              items: const [
                DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                DropdownMenuItem(value: 'manager', child: Text('Manager')),
                DropdownMenuItem(value: 'owner', child: Text('Owner')),
              ],
              onChanged: (v) => role = v ?? role,
              decoration: const InputDecoration(labelText: 'Role'),
            ),
            SwitchListTile(
              value: isActive,
              onChanged: (v) => isActive = v,
              title: const Text('Active'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _api.putJson('/users/${user['id']}', {
        'role': role,
        'is_active': isActive,
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      final msg = e.statusCode == 403
          ? 'Insufficient permissions'
          : 'Update failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    _refresh();
  }

  Future<void> _resetPassword(int userId) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'New Password'),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.postJson('/users/$userId/reset-password', {
        'newPassword': ctrl.text,
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      final msg = e.statusCode == 403
          ? 'Insufficient permissions'
          : 'Reset failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password reset')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: _createUserDialog,
            icon: const Icon(Icons.person_add),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final users = snapshot.data ?? const [];
          if (users.isEmpty) {
            return const Center(child: Text('No users'));
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = users[i];
              return ListTile(
                title: Text(u['name'] as String? ?? ''),
                subtitle: Text(
                  '${u['username']} • ${u['role']} • ${u['is_active'] == true ? 'Active' : 'Inactive'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.lock_reset),
                      onPressed: () => _resetPassword(u['id'] as int),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _updateUserDialog(u),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
