import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class UserModel {
  final String? id;
  final String? employeeId;
  String firstName;
  String lastName;
  String email;
  String role;
  String status;
  String phoneNum;
  String? profilePhotoUrl;
  final DateTime? createOn;

  UserModel({
    this.id,
    this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.phoneNum,
    required this.status,
    this.profilePhotoUrl,
    this.createOn,
  });

  factory UserModel.fromJson(Map<String, dynamic> data) => UserModel(
        id: data['id'] as String,
        employeeId: data['employeeId'] as String,
        firstName: data['firstName'] as String,
        lastName: data['lastName'] as String,
        email: data['email'] as String,
        role: data['role'] as String,
        phoneNum: data['phoneNum'] as String,
        status: data['status'] as String,
        profilePhotoUrl: data['profilePhotoUrl'] as String,
        createOn: DateTime.tryParse(data['createOn'].toString()),
      );

  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    return UserModel(
      id: id,
      employeeId: data['employeeId'] as String ?? '',
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: _normalizeRole(data['role']) as String? ?? '',
      phoneNum: data['phoneNum'] as String? ?? '',
      status: data['status'] as String? ?? '',
      profilePhotoUrl: data['profilePhotoUrl'] as String? ?? '',
      createOn: data['createOn'] != null
          ? (data['createOn'] as Timestamp).toDate()
          : null,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserModel(
      id: doc.id,
      // use document ID
      employeeId: data['employeeId'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? '',
      phoneNum: data['phoneNum'] ?? '',
      status: data['status'] ?? '',
      profilePhotoUrl: data['profilePhotoUrl'] ?? '',
      createOn: data['createOn'] != null
          ? (data['createOn'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'employeeId': employeeId,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'role': role,
        'phoneNum': phoneNum,
        'status': status,
        'profilePhotoUrl': profilePhotoUrl,
        'createOn': createOn,
      };

  // Normalize role to match dropdown options
  static String _normalizeRole(String? role) {
    if (role == null) return 'All';
    final normalized = role.toLowerCase();
    if (['admin', 'manager'].contains(normalized)) {
      return normalized[0].toUpperCase() +
          normalized.substring(1); // Capitalize
    }
    return 'All'; // Default to 'All' if role is invalid
  }
}
