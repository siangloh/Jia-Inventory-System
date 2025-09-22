import 'package:assignment/dao/user_dao.dart';
import 'package:assignment/models/user_model.dart';
import 'package:assignment/services/login/user_data_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final UserDao userDao = UserDao();
UserModel? user;

// Non-static method to load user data
Future<UserModel?> loadCurrentUser() async {
  try {
    // Read user session from SharedPreferences
    final userId = await UserData.readUserData();

    // Validate savedUser
    if (userId.isEmpty) {
      throw Exception('No user data found. Please login again.');
    }

    // Fetch full user from local DB using the ID
    user = await userDao.getUserByEmployeeId(userId);
    return user!;
  } catch (e) {
    // Handle errors (e.g., log or rethrow)
    print('Error loading user: $e');
    user = null; // Reset user on error
    return user;
  }
}

final _users = FirebaseFirestore.instance.collection('users');

Stream<UserModel?> getUserStream(String uid) {
  return _users.doc(uid).snapshots().map((doc) {
    if (doc.exists) {
      return UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    } else {
      return null;
    }
  });
}
