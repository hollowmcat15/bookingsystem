import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'otp_verification.dart';
import 'login.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>(); // Add form key
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  DateTime? _selectedBirthday;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  final SupabaseClient supabase = Supabase.instance.client;

  // Update name validation
  String? _validateName(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    // Only allow letters, spaces, and hyphens
    if (!RegExp(r"^[a-zA-Z\s-]+$").hasMatch(value)) {
      return '$fieldName can only contain letters, spaces, and hyphens';
    }
    return null;
  }

  // Add phone validation
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length != 11) {
      return 'Phone number must be exactly 11 digits';
    }
    if (!RegExp(r'^\d{11}$').hasMatch(value)) {
      return 'Please enter valid phone number';
    }
    return null;
  }

  // Update birthday validation
  String? _validateBirthday(DateTime? date) {
    if (date == null) {
      return 'Birthday is required';
    }
    final now = DateTime.now();
    if (date.year >= now.year) {
      return 'Please select a valid birth year';
    }
    // Optional: Add minimum age requirement
    if (now.year - date.year < 13) {
      return 'You must be at least 13 years old';
    }
    return null;
  }

  // Add password validation method after other validation methods
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  /// Update OTP handling
  Future<void> _sendEmailOTP() async {
    if (!_formKey.currentState!.validate()) return;

    String? birthdayError = _validateBirthday(_selectedBirthday);
    if (birthdayError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(birthdayError), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create auth user with OTP
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        emailRedirectTo: 'io.supabase.flutterquickstart://login-callback/',
        data: {
          'first_name': _firstNameController.text,
          'last_name': _lastNameController.text,
          'phone': _phoneController.text,
          'address': _addressController.text,
          'birthday': _selectedBirthday?.toIso8601String(),
          'role': 'client'
        },
      );

      if (res.user != null) {
        // Navigate to OTP verification
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationPage(
                email: _emailController.text.trim(),
                firstName: _firstNameController.text.trim(),
                lastName: _lastNameController.text.trim(),
                phone: _phoneController.text.trim(),
                address: _addressController.text.trim(),
                birthday: _selectedBirthday,
              ),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Modified date picker to prevent current year
  void _pickBirthday() async {
    final currentYear = DateTime.now().year;
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(currentYear - 18), // Set default to 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime(currentYear - 1), // Prevent selecting current year
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedBirthday = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Header section - make it more compact
                        Icon(Icons.person_add, size: 48, color: Colors.blue),
                        SizedBox(height: 8),
                        Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        SizedBox(height: 16),

                        // Form fields with reduced spacing
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstNameController,
                                validator: (value) => _validateName(value, 'First name'),
                                decoration: InputDecoration(
                                  labelText: "First Name",
                                  prefixIcon: Icon(Icons.person_outline, size: 20),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameController,
                                validator: (value) => _validateName(value, 'Last name'),
                                decoration: InputDecoration(
                                  labelText: "Last Name",
                                  prefixIcon: Icon(Icons.person_outline, size: 20),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: "Email",
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        SizedBox(height: 12),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          validator: _validatePassword,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            helperText: 'Password must contain:\n'
                                '• At least 8 characters\n'
                                '• One uppercase letter\n'
                                '• One lowercase letter\n'
                                '• One number\n'
                                '• One special character',
                            helperMaxLines: 6,
                            errorMaxLines: 2,
                          ),
                        ),
                        SizedBox(height: 12),

                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 11,
                          validator: _validatePhone,
                          decoration: InputDecoration(
                            labelText: "Phone",
                            prefixIcon: Icon(Icons.phone_outlined, size: 20),
                            counterText: '',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        SizedBox(height: 12),

                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: "Address",
                            prefixIcon: Icon(Icons.home_outlined, size: 20),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        SizedBox(height: 12),

                        // Birthday field
                        InkWell(
                          onTap: _pickBirthday,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: "Birthday",
                              prefixIcon: Icon(Icons.calendar_today, size: 20),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: Text(
                              _selectedBirthday == null
                                  ? "Select Birthday"
                                  : "${_selectedBirthday!.toLocal()}".split(" ")[0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Fixed bottom section
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: _sendEmailOTP,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text("Sign Up"),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Already have an account? "),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("Log in"),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}