import 'dart:io';

import 'package:assignment/services/login/load_user_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:supabase_flutter/supabase_flutter.dart' as supabases;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';

class UserDao {
  final CollectionReference _users =
      FirebaseFirestore.instance.collection("users");
  final supabases.SupabaseClient supabase = supabases.Supabase.instance.client;

  Future<String> generateEmployeeId() async {
    try {
      // Query the last employeeId from Firestore, sorted descending
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('employeeId', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return 'EMP0001'; // First employee
      }

      // Get last employeeId
      final lastId = querySnapshot.docs.first['employeeId'] as String;

      // Extract numeric part, increment by 1
      final numericPart = int.parse(lastId.replaceFirst('EMP', '')) + 1;

      // Format with leading zeros (EMP0001, EMP0002, etc.)
      return 'EMP${numericPart.toString().padLeft(4, '0')}';
    } catch (e) {
      throw Exception('Failed to generate employee ID: $e');
    }
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final querySnapshot = await _users
        .where('email', isEqualTo: email)
        .where('status', whereIn: ['Active', 'Inactive'])
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    return UserModel.fromFirestore(querySnapshot.docs.first);
  }

  Future<UserModel?> getUserByPhoneNum(String phoneNum) async {
    final querySnapshot = await _users
        .where('phoneNum', isEqualTo: phoneNum)
        .where('status', whereIn: ['Active', 'Inactive'])
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    return UserModel.fromFirestore(querySnapshot.docs.first);
  }

  Future<UserModel?> getUserByEmployeeId(String employeeId) async {
    final querySnapshot = await _users
        .where('employeeId', isEqualTo: employeeId)
        .where('status', whereIn: ['Active', 'Inactive'])
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    return UserModel.fromFirestore(querySnapshot.docs.first);
  }

  Future<String?> createUserAuth(String email, String password) async {
    try {
      final userCredential =
          await fb_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('User registered with UID: ${userCredential.user!.uid}');
      return null; // Success
    } on fb_auth.FirebaseAuthException catch (e) {
      print('Firebase error: ${e.message}');
      return e.message ?? 'Failed to create Firebase user';
    } catch (e) {
      print('Unexpected error: $e');
      return 'Failed to create Firebase user: $e';
    }
  }

// For now, let's focus on password changes only since email updates are complex
  Future<String?> changePasswordOnly({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return 'No user is currently signed in';

      // Reauthenticate user with current password for security
      final credential = fb_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      try {
        // Use reauthentication instead of isPassMatch
        await user.reauthenticateWithCredential(credential);
      } on fb_auth.FirebaseAuthException catch (e) {
        if (e.code == 'wrong-password') {
          return 'Current password is incorrect';
        }
        return 'Authentication failed: ${e.message}';
      }

      // Now user is still signed in, so we can update password
      await user.updatePassword(newPassword);
      print('Password updated successfully');

      // Reload user to get latest info
      await user.reload();

      return null; // Success
    } on fb_auth.FirebaseAuthException catch (e) {
      print('Firebase auth error: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'requires-recent-login':
          return 'For security reasons, please log out and log back in before making this change';
        case 'weak-password':
          return 'The new password is too weak';
        default:
          return e.message ?? 'Failed to update password';
      }
    } catch (e) {
      print('Unexpected error: $e');
      return 'An unexpected error occurred: $e';
    }
  }

// Use only if absolutely necessary and with proper user consent

  Future<String?> deleteAndRecreateAuth({
    required String currentPassword,
    required String newEmail,
    required String newPassword,
  }) async {
    try {
      final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) return 'No user is currently signed in';

      // Step 1: Reauthenticate to verify current password
      final credential = fb_auth.EmailAuthProvider.credential(
        email: currentUser.email!,
        password: currentPassword,
      );

      try {
        await currentUser.reauthenticateWithCredential(credential);
      } on fb_auth.FirebaseAuthException catch (e) {
        if (e.code == 'wrong-password') {
          return 'Current password is incorrect';
        }
        return 'Authentication failed: ${e.message}';
      }

      // Step 2: Get user's Firestore data before deletion
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        return 'User profile data not found';
      }

      final userData = userDoc.data()!;
      final oldUserId = currentUser.uid;

      // Step 3: Delete current auth user
      await currentUser.delete();

      // Step 4: Create new auth user
      final userCredential =
          await fb_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: newEmail,
        password: newPassword,
      );

      final newUser = userCredential.user!;

      // Step 5: Transfer Firestore data to new user ID
      await FirebaseFirestore.instance
          .collection('users')
          .doc(newUser.uid)
          .set({
        ...userData,
        'email': newEmail, // Update email in Firestore too
        'updatedOn': FieldValue.serverTimestamp(),
      });

      // Step 6: Delete old Firestore document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(oldUserId)
          .delete();

      print('Auth user recreated successfully');
      return null; // Success
    } on fb_auth.FirebaseAuthException catch (e) {
      print('Firebase auth error: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'requires-recent-login':
          return 'Please log out and log back in before making this change';
        case 'email-already-in-use':
          return 'This email address is already in use by another account';
        case 'weak-password':
          return 'The new password is too weak';
        case 'invalid-email':
          return 'The email address is invalid';
        default:
          return e.message ?? 'Failed to update account';
      }
    } catch (e) {
      print('Unexpected error: $e');
      return 'An unexpected error occurred: $e';
    }
  }

  Future<String?> updateEmailOnly({
    required String newEmail,
  }) async {
    try {
      final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) return 'No user is currently signed in';

      // Step 1: Send verification email to new address
      // This will require the user to verify the new email before the change takes effect
      await currentUser.verifyBeforeUpdateEmail(newEmail);

      // Step 2: Update email in Firestore immediately (optional - you might want to wait for verification)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'pendingEmail': newEmail, // Store as pending until verified
        'updatedOn': FieldValue.serverTimestamp(),
      });

      print('Verification email sent to $newEmail');
      return null; // Success
    } on fb_auth.FirebaseAuthException catch (e) {
      print('Firebase auth error: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'requires-recent-login':
          return 'Please log out and log back in before changing your email';
        case 'email-already-in-use':
          return 'This email address is already in use by another account';
        case 'invalid-email':
          return 'The email address is invalid';
        case 'missing-continue-uri':
          return 'Email verification setup error - please try again';
        case 'unauthorized-continue-uri':
          return 'Email verification setup error - please contact support';
        default:
          return e.message ?? 'Failed to update email';
      }
    } catch (e) {
      print('Unexpected error: $e');
      return 'An unexpected error occurred: $e';
    }
  }

// Helper function to listen for email changes and update Firestore
  void setupEmailUpdateListener() {
    fb_auth.FirebaseAuth.instance
        .authStateChanges()
        .listen((fb_auth.User? user) async {
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final firestoreEmail = userData['email'] as String?;
          final pendingEmail = userData['pendingEmail'] as String?;

          if (user.email != null &&
              user.email != firestoreEmail &&
              user.email == pendingEmail) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
              'email': user.email,
              'pendingEmail': FieldValue.delete(),
              'emailVerifiedAt': FieldValue.serverTimestamp(),
              'updatedOn': FieldValue.serverTimestamp(),
            });

            print('Email successfully updated in Firestore: ${user.email}');
          }
        }
      }
    });
  }

// Alternative: Combined function that handles both scenarios
  Future<String?> updateAccountInfo({
    String? currentPassword,
    String? newEmail,
    String? newPassword,
  }) async {
    try {
      final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) return 'No user is currently signed in';

      // If both password and email change are requested, use delete/recreate method
      if (currentPassword != null && newPassword != null && newEmail != null) {
        return await deleteAndRecreateAuth(
          currentPassword: currentPassword,
          newEmail: newEmail,
          newPassword: newPassword,
        );
      }

      // If only email change is requested
      if (newEmail != null && currentPassword == null) {
        // Send verification email to new address
        await currentUser.verifyBeforeUpdateEmail(newEmail);

        // Store as pending email in Firestore until verified
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'pendingEmail': newEmail,
          'updatedOn': FieldValue.serverTimestamp(),
        });

        print('Verification email sent to $newEmail');
        return null;
      }

      // If only password change is requested
      if (newPassword != null && currentPassword != null && newEmail == null) {
        // Reauthenticate first
        final credential = fb_auth.EmailAuthProvider.credential(
          email: currentUser.email!,
          password: currentPassword,
        );

        await currentUser.reauthenticateWithCredential(credential);

        // Update password
        await currentUser.updatePassword(newPassword);

        print('Password updated successfully');
        return null;
      }

      return 'Invalid parameters provided';
    } on fb_auth.FirebaseAuthException catch (e) {
      print('Firebase auth error: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'requires-recent-login':
          return 'Please log out and log back in before making this change';
        case 'email-already-in-use':
          return 'This email address is already in use by another account';
        case 'weak-password':
          return 'The new password is too weak';
        case 'invalid-email':
          return 'The email address is invalid';
        case 'wrong-password':
          return 'Current password is incorrect';
        default:
          return e.message ?? 'Failed to update account';
      }
    } catch (e) {
      print('Unexpected error: $e');
      return 'An unexpected error occurred: $e';
    }
  }

  Future<bool> isEmailExists(String email) async {
    final user = await getUserByEmail(email);
    return user != null;
  }

  Future<bool> isPassMatch(String email, String inputPassword) async {
    try {
      await fb_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: inputPassword,
      );
      print("valid");
      final user = await getUserByEmail(email);
      if (user != null) {
        if (user.status.toLowerCase() != 'active') {
          print("here");
          return false;
        }
      } else {
        return false;
      }
      print('Account matched.');
      await fb_auth.FirebaseAuth.instance.signOut();
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      print('Firebase auth error: ${e.code}');
      return false;
    }
  }

  Future<String?> createUser(Map<String, dynamic> userData) async {
    try {
      await _users.add({
        'employeeId': userData['employeeId'],
        'firstName': userData['firstName'],
        'lastName': userData['lastName'],
        'email': userData['email'],
        'role': userData['role'],
        'phoneNum': userData['phone'],
        'status': 'Active',
        "createOn": FieldValue.serverTimestamp(),
      });
      print('Registered locally.');
      return null; // Success
    } catch (e) {
      print('Error inserting user: $e');
      return 'Failed to save user locally: $e';
    }
  }

  // Get all users
  Future<List<UserModel>> getUsers() async {
    final querySnapshot =
        await _users.where('status', whereIn: ['Active', 'Inactive']).get();

    return querySnapshot.docs
        .map((doc) =>
            UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }

  // Update a user
  Future<String?> updateUser(String id, UserModel user) async {
    try {
      final data = <String, dynamic>{};
      if (user.firstName.isNotEmpty) data["firstName"] = user.firstName;
      if (user.lastName.isNotEmpty) data["lastName"] = user.lastName;
      if (user.email.isNotEmpty) data["email"] = user.email;
      if (user.phoneNum.isNotEmpty) data["phoneNum"] = user.phoneNum;
      if (user.status.isNotEmpty) data["status"] = user.status;
      if (user.role.isNotEmpty) data["role"] = user.role;
      print('ahah : ${user.id}');
      if (data.isNotEmpty) {
        await _users.doc(user.id).update(data);
      }
      return null;
    } catch (e) {
      return 'Update unsuccessful $e';
    }
  }

  Stream<List<UserModel>> getUsersStream() {
    return _users
        .where('status', whereIn: ['Active', 'Inactive'])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return UserModel.fromMap(
                doc.id, doc.data() as Map<String, dynamic>);
          }).toList();
        });
  }

  Stream<UserModel?> getUserStream() {
    final userId = fb_auth.FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const Stream.empty();
    return _users.doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      } else {
        return null;
      }
    });
  }

  // Update a user
  Future<String?> _updateUserImg(String downloadUrl) async {
    final user = await loadCurrentUser();
    try {
      if (user == null) {
        return "Update unsuccessful: Due user unavailable.";
      }
      await _users.doc(user.id).update({
        'profilePhotoUrl': downloadUrl, // add if not exists, replace if exists
      });
      return null;
    } catch (e) {
      return 'Update unsuccessful: $e';
    }
  }

  Future<String?> updateUserImg(File file) async {
    try {
      // Give the file a unique name
      final fileName = 'scaled_${Uuid().v4()}.jpg';

      // Upload to Supabase Storage
      await supabases.Supabase.instance.client.storage
          .from('profile_photos')
          .upload(fileName, file,
              fileOptions: const supabases.FileOptions(upsert: true));

      // Store only the object path (not URL) in user profile
      await _updateUserImg(fileName);

      // Return the object path so caller knows what was stored
      return fileName;
    } catch (e) {
      print("Upload error: $e");
      return null;
    }
  }
}