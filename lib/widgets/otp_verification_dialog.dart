import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OTPVerificationDialog extends StatefulWidget {
  final String email;
  final String title;
  final String message;
  final OtpType type;

  const OTPVerificationDialog({
    Key? key,
    required this.email,
    this.title = 'Verify Email',
    this.message = 'Enter verification code',
    this.type = OtpType.signup,
  }) : super(key: key);

  @override
  _OTPVerificationDialogState createState() => _OTPVerificationDialogState();
}

class _OTPVerificationDialogState extends State<OTPVerificationDialog> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;
  String? _error;

  Future<void> _verifyOTP() async {
    if (_otpController.text.isEmpty) return;

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      // Use the correct method name 'verifyOTP' instead of 'verifyOtp'
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: _otpController.text,
        type: widget.type,
      );

      print("OTP Verification Response: $response"); // Debug log

      if (response.session != null || response.user != null) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Invalid verification code');
      }
    } catch (e) {
      print("OTP Verification Error: $e"); // Debug log
      setState(() {
        _error = 'Invalid verification code. Please try again.';
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          SizedBox(height: 16),
          TextField(
            controller: _otpController,
            decoration: InputDecoration(
              labelText: 'Verification Code',
              errorText: _error,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isVerifying ? null : _verifyOTP,
          child: _isVerifying
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Verify'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }
}
