import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChangeEmailPage extends StatefulWidget {
  @override
  _ChangeEmailPageState createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  TextEditingController _currentPasswordController = TextEditingController();
  TextEditingController _newEmailController = TextEditingController();
  
  bool _isLoading = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  /// Detect user role
  Future<void> _fetchUserRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    List<String> roles = ["client", "manager", "therapist", "receptionist"];
    for (String role in roles) {
      final response = await supabase.from(role).select('email').eq('email', user.email!).maybeSingle();
      if (response != null) {
        setState(() {
          _userRole = role;
        });
        return;
      }
    }
  }

  /// Update email directly
  Future<void> _updateEmail() async {
    if (!_formKey.currentState!.validate() || _userRole == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUserEmail = supabase.auth.currentUser!.email!;
      final newEmail = _newEmailController.text.trim();
      final currentPassword = _currentPasswordController.text;

      // First verify password
      final AuthResponse verifyResponse = await supabase.auth.signInWithPassword(
        email: currentUserEmail,
        password: currentPassword,
      );

      if (verifyResponse.user == null) {
        throw AuthException('Invalid credentials');
      }

      // Use RPC to update auth email (preserves verification status)
      await supabase.rpc('change_user_email', params: {
        'old_email': currentUserEmail,
        'new_email': newEmail,
      });

      // Update the database table
      await supabase.from(_userRole!).update({
        'email': newEmail,
      }).eq('email', currentUserEmail);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email updated successfully. Please sign in with your new email.')),
      );

      // Sign out and redirect to login
      await supabase.auth.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Authentication error: ${e.message}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating email: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Change Email")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Please enter your current password and new email address.",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              TextFormField(
                controller: _newEmailController,
                decoration: InputDecoration(
                  labelText: "New Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Enter your new email";
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return "Enter a valid email address";
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  labelText: "Current Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter your current password";
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateEmail,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
                child: _isLoading 
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Update Email", style: TextStyle(fontSize: 16)),
              ),
              SizedBox(height: 16),
              Text(
                "Note: After updating, you'll receive a confirmation email at your new address. The change won't be complete until you confirm.",
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}