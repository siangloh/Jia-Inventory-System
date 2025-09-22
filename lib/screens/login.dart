import 'package:assignment/database_service.dart';
import 'package:assignment/screens/forgetPasswordScreen.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/login/remember_me_service.dart';
import '../services/login/user_data_service.dart';
import '../widgets/alert.dart';
import '../dao/user_dao.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailFieldKey = GlobalKey<FormFieldState>();
  final _passwordFieldKey = GlobalKey<FormFieldState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final userDao = UserDao();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Load saved credentials if remember me was enabled
  Future<void> _loadSavedCredentials() async {
    try {
      final savedData = await RememberMeService.getSavedCredentials();

      setState(() {
        _emailController.text = savedData['email'] ?? '';
        _passwordController.text = savedData['password'] ?? '';
        _rememberMe = savedData['rememberMe'] ?? false;
        _isInitializing = false;
      });
    } catch (e) {
      print('Error loading saved credentials: $e');
      setState(() {
        _isInitializing = false;
      });
    }
  }

  /// Check if user should be automatically logged in
  Future<void> _checkAutoLogin() async {
    try {
      final shouldAutoLogin = await RememberMeService.shouldAutoLogin();

      if (shouldAutoLogin && mounted) {
        final savedData = await RememberMeService.getSavedCredentials();
        final email = savedData['email'] ?? '';
        final password = savedData['password'] ?? '';

        if (email.isNotEmpty && password.isNotEmpty) {
          // Auto-login after a short delay
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            _autoLogin(email, password);
          }
        }
      }
    } catch (e) {
      print('Error checking auto-login: $e');
    }
  }

  /// Perform automatic login
  Future<void> _autoLogin(String email, String password) async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool exist = await userDao.isPassMatch(email, password);

      if (exist) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboard',
          (Route<dynamic> route) => false,
        );
        BeautifulAlerts.showSuccessToast(
          context,
          message: 'Welcome back!',
          subtitle: 'Automatically signed in',
        );
      } else {
        // Clear auto-login if credentials are invalid
        await RememberMeService.clearAutoLogin();
        setState(() {
          _isLoading = false;
        });
        BeautifulAlerts.showErrorDialog(
          context,
          title: 'Auto-login Failed',
          message: 'Please sign in manually.',
        );
      }
    } catch (e) {
      await RememberMeService.clearAutoLogin();
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto-login failed: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String email = _emailController.text.trim();
        String password = _passwordController.text.trim();
        bool exist = await userDao.isPassMatch(email, password);

        // If the password match
        if (exist) {
          // Save credentials if remember me is checked
          await RememberMeService.saveCredentials(email, password, _rememberMe);

          // Set auto-login for next time if remember me is enabled
          if (_rememberMe) {
            await RememberMeService.saveAutoLogin(true);
          }

          UserModel? user =
              await userDao.getUserByEmail(email); // await the Future

          if (user != null) {
            await UserData.saveUserData(
              user.employeeId as String,
            );
          } else {
            print('User not found');
          }

          await Future.delayed(const Duration(seconds: 1));
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/dashboard',
            (Route<dynamic> route) => false,
          );
          BeautifulAlerts.showSuccessToast(
            context,
            message: 'Login Successful!',
            subtitle: 'Welcome back',
          );
        } else {
          BeautifulAlerts.showErrorDialog(
            context,
            title: 'Login Unsuccessful!',
            message: 'Email or Password may be wrong. Please check again.',
          );
        }
        setState(() {
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Login Unsuccessful: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Handle remember me checkbox change
  void _onRememberMeChanged(bool? value) {
    setState(() {
      _rememberMe = value ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading spinner while initializing
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Column(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 300,
                        height: 200,
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Login Form
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email Field
                          TextFormField(
                            key: _emailFieldKey,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'Enter your email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.blue[600]!),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                            onChanged: (_) {
                              _emailFieldKey.currentState?.validate();
                            },
                          ),
                          const SizedBox(height: 20),

                          // Password Field
                          TextFormField(
                            key: _passwordFieldKey,
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.blue[600]!),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                            onChanged: (_) {
                              _passwordFieldKey.currentState?.validate();
                            },
                          ),
                          const SizedBox(height: 16),

                          // Remember Me & Forgot Password
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    onChanged: _isLoading
                                        ? null
                                        : _onRememberMeChanged,
                                    activeColor: Colors.blue[600],
                                  ),
                                  GestureDetector(
                                    onTap: _isLoading
                                        ? null
                                        : () =>
                                            _onRememberMeChanged(!_rememberMe),
                                    child: Text(
                                      'Remember me',
                                      style: TextStyle(
                                        color: _isLoading
                                            ? Colors.grey
                                            : Colors.black87,
                                        fontWeight: _rememberMe
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  ForgetPasswordScreen()),
                                        );
                                      },
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: _isLoading
                                        ? Colors.grey
                                        : Colors.blue[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Login Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}