import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'otp_verification.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  DateTime? _selectedBirthday;

  final SupabaseClient supabase = Supabase.instance.client;

  /// ✅ Sends OTP via Email and Navigates to OTP Screen
  Future<void> _sendEmailOTP() async {
    try {
      await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("OTP sent to ${_emailController.text}. Check your email.")),
      );

      // ✅ Navigate to OTP Verification Screen
      Navigator.push(
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send OTP: $e")),
      );
    }
  }

  /// ✅ Open Date Picker for Birthday
  void _pickBirthday() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(height: 50),
            Icon(Icons.person_add, size: 80, color: Colors.blue),
            SizedBox(height: 20),
            Text("Create an Account", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            SizedBox(height: 30),

            /// ✅ First Name & Last Name Fields
            Row(
              children: [
                Expanded(
                  child: TextField(controller: _firstNameController, decoration: InputDecoration(labelText: "First Name", border: OutlineInputBorder())),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(controller: _lastNameController, decoration: InputDecoration(labelText: "Last Name", border: OutlineInputBorder())),
                ),
              ],
            ),
            SizedBox(height: 16),

            /// ✅ Email & Password
            TextField(controller: _emailController, decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder())),
            SizedBox(height: 16),
            TextField(controller: _passwordController, decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder()), obscureText: true),
            SizedBox(height: 16),

            /// ✅ Phone Number & Address
            TextField(controller: _phoneController, decoration: InputDecoration(labelText: "Phone Number", border: OutlineInputBorder())),
            SizedBox(height: 16),
            TextField(controller: _addressController, decoration: InputDecoration(labelText: "Address", border: OutlineInputBorder())),
            SizedBox(height: 16),

            /// ✅ Birthday Field
            GestureDetector(
              onTap: _pickBirthday,
              child: InputDecorator(
                decoration: InputDecoration(labelText: "Birthday", border: OutlineInputBorder()),
                child: Text(_selectedBirthday == null ? "Select Birthday" : "${_selectedBirthday!.toLocal()}".split(" ")[0]),
              ),
            ),
            SizedBox(height: 20),

            /// ✅ Sign Up Button
            ElevatedButton(
              onPressed: _sendEmailOTP,
              child: Text("Sign Up", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}











