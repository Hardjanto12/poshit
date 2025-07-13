import 'package:shared_preferences/shared_preferences.dart';
import 'package:poshit/models/user.dart';
import 'package:poshit/services/user_service.dart';

class UserSessionService {
  static final UserSessionService _instance = UserSessionService._internal();
  factory UserSessionService() => _instance;
  UserSessionService._internal();

  User? _currentUser;
  final UserService _userService = UserService();

  User? get currentUser => _currentUser;

  /// Initialize the session service and check for saved login
  Future<bool> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getInt('current_user_id');

    if (savedUserId != null) {
      try {
        _currentUser = await _userService.getUserById(savedUserId);
        return _currentUser != null;
      } catch (e) {
        // If user doesn't exist anymore, clear saved session
        await logout();
        return false;
      }
    }
    return false;
  }

  /// Login a user and save the session
  Future<bool> login(String username, String password) async {
    try {
      final user = await _userService.authenticateUser(username, password);
      if (user != null) {
        _currentUser = user;
        await _saveSession(user.id!);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Logout the current user and clear session
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
  }

  /// Save the current user session
  Future<void> _saveSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_user_id', userId);
  }

  /// Check if a user is currently logged in
  bool get isLoggedIn => _currentUser != null;

  /// Get the current user ID
  int? get currentUserId => _currentUser?.id;

  /// Get the current user name
  String? get currentUserName => _currentUser?.name;

  /// Get the current user username
  String? get currentUserUsername => _currentUser?.username;
}
