import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  String? _userType; 
  String? _token;
  Map<String, dynamic>? _userData;


  String? get userType => _userType;
  String? get token => _token;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoggedIn => _token != null && _userType != null;


  Future<void> loadUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    _userType = prefs.getString('user_type');
    _token = prefs.getString('token');
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      _userData = Map<String, dynamic>.from(jsonDecode(userDataString));
    }
    notifyListeners();
  }

  void setUserType(String type) {
    _userType = type;
    notifyListeners();
  }

  void setToken(String? token) {
    _token = token;
    notifyListeners();
  }
   void setUserData(Map<String, dynamic>? data) {
    _userData = data;
    notifyListeners();
  }


  Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_type');
    await prefs.remove('user_data');
    _userType = null;
    _token = null;
    _userData = null;
    notifyListeners();
  }
}
