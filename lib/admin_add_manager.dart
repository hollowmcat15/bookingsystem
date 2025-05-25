import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'widgets/otp_verification_dialog.dart';

class AdminAddManager extends StatefulWidget {
  @override
  _AdminAddManagerState createState() => _AdminAddManagerState();
}

class _AdminAddManagerState extends State<AdminAddManager> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  bool _isLoading = false;
  DateTime? _selectedDate;

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (value.length != 11) return 'Phone number must be 11 digits';
    if (!RegExp(r'^\d{11}$').hasMatch(value)) {
      return 'Enter a valid 11 digit phone number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$')
        .hasMatch(value)) {
      return 'Password must contain uppercase, lowercase,\nnumber and special character';
    }
    return null;
  }

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

  Future<void> _addManager() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // First create auth user, which will trigger email verification
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        emailRedirectTo: 'io.supabase.flutterquickstart://login-callback/',
        data: {'role': 'manager'},
      );

      if (authResponse.user == null) throw Exception('Failed to create user');

      // Show OTP verification dialog
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => OTPVerificationDialog(
          email: _emailController.text,
          title: 'Verify Manager Email',
          message: 'Please enter the verification code sent to ${_emailController.text}',
          type: OtpType.signup,
        ),
      );

      if (verified == true) {
        // Add to staff table
        await supabase.from('staff').insert({
          'auth_id': authResponse.user!.id,
          'first_name': _firstNameController.text,
          'last_name': _lastNameController.text,
          'email': _emailController.text,
          'phonenumber': _phoneController.text,
          'birthday': _selectedDate?.toIso8601String(),
          'role': 'Manager',
          'status': 'Active',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Manager added successfully')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final currentYear = DateTime.now().year;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(currentYear - 25),
      firstDate: DateTime(1950),
      lastDate: DateTime(currentYear - 1), // Prevent selecting current year
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add New Manager')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: 'Email'),
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(labelText: 'First Name'),
                      validator: (value) => _validateName(value, 'First Name'),
                    ),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(labelText: 'Last Name'),
                      validator: (value) => _validateName(value, 'Last Name'),
                    ),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(labelText: 'Phone Number'),
                      validator: _validatePhone,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                    ),
                    TextFormField(
                      controller: _birthdayController,
                      decoration: InputDecoration(
                        labelText: 'Birthday',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => 
                            _isPasswordVisible = !_isPasswordVisible
                          ),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _addManager,
                      child: Text('Add Manager'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
