import 'package:lokseva/services/api_service.dart';

/// Simple singleton to hold user state globally
class UserState {
  static final UserState _instance = UserState._internal();
  factory UserState() => _instance;
  UserState._internal();

  UserProfileResponse? _currentUser;

  UserProfileResponse? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  void setUser(UserProfileResponse user) {
    _currentUser = user;
  }

  void clearUser() {
    _currentUser = null;
  }
}