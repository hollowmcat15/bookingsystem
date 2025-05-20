import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChangePasswordPage extends StatefulWidget {
  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  TextEditingController _oldPasswordController = TextEditingController();
  TextEditingController _newPasswordController = TextEditingController();
  TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  /// ✅ Detect user role
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

  /// ✅ Update Password in Supabase Auth
  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate() || _userRole == null) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("New passwords do not match!")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password updated successfully!")),
      );

      Navigator.pop(context);
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update password: ${e.message}")),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Change Password")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _oldPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Old Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) => value!.isEmpty ? "Enter your old password" : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "New Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (value) => value!.length < 6 ? "Password must be at least 6 characters" : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Confirm New Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.check),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _updatePassword,
                child: _isLoading ? CircularProgressIndicator() : Text("Update Password"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
