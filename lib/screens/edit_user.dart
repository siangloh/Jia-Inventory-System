import 'package:assignment/dao/user_dao.dart';
import 'package:assignment/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/debouncer_service.dart';

class EditUserScreen extends StatefulWidget {
  final UserModel user;

  const EditUserScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final _firstNameKey = GlobalKey<FormFieldState>();
  final _lastNameKey = GlobalKey<FormFieldState>();
  final _emailKey = GlobalKey<FormFieldState>();
  final _phoneKey = GlobalKey<FormFieldState>();
  final userDao = UserDao();

  String? _selectedRole;
  bool _isLoading = false;
  late Debouncer _debouncer;
  String? _emailError;
  String? _phoneError;

  final List<String> _userRoles = ['Admin', 'Manager', 'Employee'];

  @override
  void initState() {
    super.initState();
    _debouncer = Debouncer(delay: const Duration(milliseconds: 500));

    // Pre-populate form fields with existing user data
    _firstNameCtrl.text = widget.user.firstName ?? '';
    _lastNameCtrl.text = widget.user.lastName ?? '';
    _emailCtrl.text = widget.user.email ?? '';
    _phoneCtrl.text = widget.user.phoneNum ?? '';
    _selectedRole = widget.user.role;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _debouncer.cancel();
    super.dispose();
  }

  Future<String?> _validateEmail(String email) async {
    // Skip validation if email hasn't changed
    if (email.trim() == widget.user.email.trim()) {
      return null;
    }

    final user = await userDao.getUserByEmail(email);
    return user != null ? 'Email is already in use. Please change it.' : null;
  }

  Future<String?> _validatePhone(String phoneNum) async {
    // Skip validation if phone hasn't changed
    if (phoneNum == widget.user.phoneNum) {
      return null;
    }

    final user = await userDao.getUserByPhoneNum(phoneNum);
    return user != null
        ? 'Phone Number is already in use. Please change it.'
        : null;
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() &&
        _emailError == null &&
        _phoneError == null) {
      if (_selectedRole == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a user role'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        // Create updated user data
        final updatedUserData = UserModel(
          id: widget.user.id,
          firstName: _firstNameCtrl.text,
          lastName: _lastNameCtrl.text,
          email: _emailCtrl.text,
          phoneNum: _phoneCtrl.text.replaceAll(RegExp(r'[\s-]'), ''),
          role: _selectedRole.toString().toUpperCase(),
          status: widget.user.status,
        );

        // Update user locally
        // final errLocal = await userDao.updateUser(widget.user.id!, updatedUserData);
        // if (errLocal != null) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(
        //       content: Text('Failed to update local user: $errLocal'),
        //       backgroundColor: Colors.red,
        //     ),
        //   );
        //   setState(() {
        //     _isLoading = false;
        //   });
        //   return;
        // }
        print('Yessss');
        final errFirebase =
            await userDao.updateUser(widget.user.id!, updatedUserData);
        if (errFirebase != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update Firebase user: $errFirebase'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _isLoading = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back
        Navigator.of(context)
            .pop(true); // Return true to indicate successful update
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix validation errors'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit User'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(15.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Header
                Column(
                  children: [
                    Icon(
                      Icons.edit,
                      size: 50,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Edit User Account',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Update the details below',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                // Form Container
                Column(
                  children: [
                    // First Name
                    TextFormField(
                      key: _firstNameKey,
                      controller: _firstNameCtrl,
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z\s]')), // Letters and spaces only
                      ],
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.blue[600]!, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'First name is required';
                        } else if (value.length <= 1) {
                          return 'Ensure your first name is more than one character.';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        _debouncer.run(() {
                          _firstNameKey.currentState?.validate();
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    // Last Name
                    TextFormField(
                      controller: _lastNameCtrl,
                      key: _lastNameKey,
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z\s]')), // Letters and spaces only
                      ],
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.blue[600]!, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Last name is required';
                        } else if (value.length <= 1) {
                          return 'Ensure your last name is more than one character.';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        _debouncer.run(() {
                          _lastNameKey.currentState?.validate();
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      key: _emailKey,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.blue[600]!, width: 2),
                        ),
                        errorText: _emailError,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email is required';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        _debouncer.run(() async {
                          setState(() {
                            _emailError = null;
                          });
                          if (_emailKey.currentState!.validate()) {
                            final error = await _validateEmail(value);
                            setState(() {
                              _emailError = error;
                            });
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    // Phone Number
                    TextFormField(
                      controller: _phoneCtrl,
                      key: _phoneKey,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d\s-]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.blue[600]!, width: 2),
                        ),
                        errorText: _phoneError,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Phone number is required';
                        }
                        final phoneRegex = RegExp(
                            r'^0(11(?:[\s\-]?\d){8}|1[0-9](?:[\s\-]?\d){7})$');
                        if (!phoneRegex.hasMatch(value)) {
                          return 'Enter a valid Malaysian phone number (e.g., 0123456789)';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        _debouncer.run(() async {
                          setState(() {
                            _phoneError = null;
                          });
                          if (_phoneKey.currentState!.validate()) {
                            final error = await _validatePhone(value);
                            setState(() {
                              _phoneError = error;
                            });
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    // User Role Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'User Role',
                        prefixIcon: const Icon(Icons.work),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.blue[600]!, width: 2),
                        ),
                      ),
                      items: _userRoles.map((String role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedRole = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a user role';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    // Submit Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Cancel Button
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                    },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.grey[100],
                                side: BorderSide(color: Colors.grey[400]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Update User Button
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Update User',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
