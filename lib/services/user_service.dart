import 'package:poshit/models/user.dart';
import 'package:poshit/api/api_client.dart';

class UserService {
  final ApiClient _api = ApiClient();

  Future<int> insertUser(User user) async {
    final res = await _api.postJson('/auth/register', {
      'name': user.name,
      'username': user.username,
      'password': user.password,
      'date_created': user.dateCreated,
      'date_updated': user.dateUpdated,
    });
    return (res['id'] as num).toInt();
  }

  Future<List<User>> getUsers() async {
    // Not exposed by API; return current user if needed via /auth/me
    final me = await getUserById(0);
    return me != null ? [me] : [];
  }

  Future<int> updateUser(User user) async {
    // Not implemented in API; no-op
    return 0;
  }

  Future<int> deleteUser(int id) async {
    // Not implemented in API; no-op
    return 0;
  }

  Future<User?> getUserByUsername(String username) async {
    // Not exposed by API directly; rely on login for lookup
    return null;
  }

  Future<User?> getUserById(int id) async {
    // Map to /auth/me using current token
    try {
      final res = await _api.getJson('/auth/me');
      final userMap =
          res['user'] as Map<String, dynamic>? ??
          (res.containsKey('name') ? res : null);
      return userMap != null ? User.fromMap(userMap) : null;
    } catch (_) {
      return null;
    }
  }

  Future<User?> authenticateUser(String username, String password) async {
    try {
      final res = await _api.postJson('/auth/login', {
        'username': username,
        'password': password,
      });
      final token = res['token'] as String?;
      if (token != null) {
        _api.setAuthToken(token);
      }
      final userMap = res['user'] as Map<String, dynamic>;
      return User.fromMap(userMap);
    } catch (_) {
      return null;
    }
  }
}
