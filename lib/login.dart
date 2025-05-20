import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup.dart';
import 'client_dashboard.dart';
import 'manager_dashboard.dart';
import 'therapist_dashboard.dart';
import 'receptionist_dashboard.dart';  // Import the new receptionist dashboard

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  /// ✅ Check if user is already logged in
  void _checkSession() async {
    final session = supabase.auth.currentSession;

    if (session?.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      });
    }
  }

  /// ✅ Handle Login
  void _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final Session? session = response.session;
      if (session != null) {
        final String userId = session.user.id;

        // Check if user is a Manager
        final List<Map<String, dynamic>> managerCheck = await supabase
            .from('manager')
            .select()
            .eq('auth_id', userId);

        if (managerCheck.isNotEmpty) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ManagerDashboard(managerData: managerCheck.first),
              ),
            );
          }
          return;
        }

        // Check if user is a Therapist
        final List<Map<String, dynamic>> therapistCheck = await supabase
            .from('therapist')
            .select()
            .eq('auth_id', userId);

        if (therapistCheck.isNotEmpty) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TherapistDashboard(therapistData: therapistCheck.first),
              ),
            );
          }
          return;
        }

        // Check if user is a Receptionist
        final List<Map<String, dynamic>> receptionistCheck = await supabase
            .from('receptionist')
            .select()
            .eq('auth_id', userId);

        if (receptionistCheck.isNotEmpty) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ReceptionistDashboard(receptionistData: receptionistCheck.first),
              ),
            );
          }
          return;
        }

        // Check if user is a Client
        final String? userEmail = session?.user.email;

        if (userEmail != null) {  // Ensure userEmail is not null
          final List<Map<String, dynamic>> clientCheck = await supabase
              .from('client')
              .select()
              .eq('email', userEmail);  // This prevents the nullable error

          if (clientCheck.isNotEmpty) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ClientDashboard(),
                ),
              );
            }
            return;
          }
        }

        // No valid role found
        await supabase.auth.signOut();
        if (mounted) {
          setState(() {
            _errorMessage = "Access denied: No valid role assigned.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Login failed: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.lock, size: 80, color: Colors.blue),
              SizedBox(height: 20),
              Text("Welcome!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text("Log-in to continue", style: TextStyle(fontSize: 16, color: Colors.grey)),
              SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16.0),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              SizedBox(height: 20),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text("Log-in", style: TextStyle(fontSize: 18)),
              ),
              SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => SignUpPage()));
                },
                child: Text("Don't have an account? Sign up", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}