import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OTPVerificationPage extends StatefulWidget {
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final String address;
  final DateTime? birthday;

  OTPVerificationPage({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.address,
    required this.birthday,
  });

  @override
  _OTPVerificationPageState createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isVerifying = false;

  /// ✅ Verifies OTP & Stores User Data
  Future<void> _verifyOTP() async {
    setState(() {
      _isVerifying = true;
    });

    try {
      await supabase.auth.verifyOTP(
        email: widget.email,
        token: _otpController.text,
        type: OtpType.signup,
      );

      final existingUser = await supabase.from('client').select('email').eq('email', widget.email).maybeSingle();

      if (existingUser == null) {
        await supabase.from('client').insert({
          'first_name': widget.firstName,
          'last_name': widget.lastName,
          'email': widget.email,
          'phonenumber': widget.phone,
          'address': widget.address,
          'birthday': widget.birthday?.toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      print("✅ OTP verified! Redirecting to login...");

      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (Route<dynamic> route) => false,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid OTP: $e")),
      );
    }

    setState(() {
      _isVerifying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("OTP Verification")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("Enter the OTP sent to ${widget.email}", textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            TextField(controller: _otpController, decoration: InputDecoration(labelText: "Enter OTP", border: OutlineInputBorder())),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isVerifying ? null : _verifyOTP,
              child: _isVerifying ? CircularProgressIndicator() : Text("Verify OTP"),
            ),
          ],
        ),
      ),
    );
  }
}

