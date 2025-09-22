import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:assignment/models/user_model.dart';

class UserData {
  static Future<void> saveUserData(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('userID', userId);
  }

  static Future<String> readUserData() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString("userID")!;
  }
}
