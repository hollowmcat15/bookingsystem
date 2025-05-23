import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup.dart';
import 'client_dashboard.dart';
import 'manager_dashboard.dart';
import 'therapist_dashboard.dart';
import 'receptionist_dashboard.dart';
import 'admin_dashboard.dart';  // Add this import
import 'change_password.dart';

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
      if (session == null) {
        throw 'Authentication failed';
      }

      final String userId = session.user.id;
      final String? userEmail = session.user.email;

      // Check roles in order of privilege: Admin > Staff > Client
      try {
        // 1. Check Admin
        final adminData = await supabase
            .from('admin')
            .select()
            .eq('auth_id', userId)
            .single();
            
        if (adminData != null) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AdminDashboard(adminData: adminData),
              ),
            );
          }
          return;
        }
      } catch (e) {
        // Not an admin, continue checking other roles
      }

      try {
        // 2. Check Staff (Manager, Therapist, Receptionist)
        final staffData = await supabase
            .from('staff')
            .select('''
              *,
              spa (
                spa_id,
                spa_name,
                spa_address,
                postal_code,
                spa_phonenumber,
                opening_time,
                closing_time
              )
            ''')
            .eq('auth_id', userId)
            .single();

        if (staffData != null) {
          if (mounted) {
            switch (staffData['role']) {
              case 'Manager':
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManagerDashboard(managerData: staffData),
                  ),
                );
                break;
              case 'Therapist':
                if (staffData['status'] == 'Inactive') {
                  throw 'Your account is currently inactive. Please contact your manager.';
                }
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TherapistDashboard(therapistData: staffData),
                  ),
                );
                break;
              case 'Receptionist':
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReceptionistDashboard(receptionistData: staffData),
                  ),
                );
                break;
            }
          }
          return;
        }
      } catch (e) {
        // Not a staff member, continue checking client
      }

      try {
        // 3. Check Client
        if (userEmail == null) throw 'Invalid email';
        
        final clientData = await supabase
            .from('client')
            .select()
            .eq('email', userEmail)
            .single();

        if (clientData != null) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ClientDashboard(), // Remove clientData parameter
              ),
            );
          }
          return;
        }
      } catch (e) {
        // Not a client
      }

      // No valid role found
      await supabase.auth.signOut();
      throw 'Access denied: No valid role assigned';

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
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
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangePasswordPage(
                        isForgotPassword: true,
                      ),
                    ),
                  );
                },
                child: Text(
                  "Forgot password? Click here",
                  style: TextStyle(fontSize: 16, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}