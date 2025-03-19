import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup.dart';
import 'client_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final SupabaseClient supabase = Supabase.instance.client;

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
    try {
      final AuthResponse res = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (res.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login successful!')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ClientDashboard()),
        );
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred. Please try again.')),
      );
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
              Icon(Icons.lock, size: 80, color: Colors.blue), // ✅ Stylish Icon
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
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text("Log-in", style: TextStyle(fontSize: 18)),
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


