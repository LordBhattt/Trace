import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static final UserSession instance = UserSession._internal();
  UserSession._internal();

  String? userId;
  String? userName;
  String? userEmail;
  String? token;
  String? currentRideId;

  bool get isLoggedIn => token != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    userId = prefs.getString('userId');
    userName = prefs.getString('userName');
    userEmail = prefs.getString('userEmail');
    currentRideId = prefs.getString('currentRideId');
  }

  Future<void> saveRideId(String rideId) async {
    currentRideId = rideId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentRideId', rideId);
  }

  Future<void> clearRideId() async {
    currentRideId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentRideId');
  }

  Future<void> logout() async {
    userId = null;
    userName = null;
    userEmail = null;
    token = null;
    currentRideId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
