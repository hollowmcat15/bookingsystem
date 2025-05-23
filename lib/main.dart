import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'client_dashboard.dart';
import 'signup.dart';
import 'otp_verification.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase with realtime options
  await Supabase.initialize(
    url: 'https://qhqvnyefgqzzwovastnz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFocXZueWVmZ3F6endvdmFzdG56Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzkyMzMzMjIsImV4cCI6MjA1NDgwOTMyMn0.vo_S4s4FEdwJPwbkUPEfWvLahX1J26c2erRNCyLjl_Y',
    realtimeClientOptions: const RealtimeClientOptions(
      eventsPerSecond: 40,
    ),
  );
  
  // Enable realtime for general subscriptions
  final client = Supabase.instance.client;
  client.channel('public').subscribe();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Booking System',
      theme: ThemeData(
        fontFamily: 'Outfit', // ✅ Apply Outfit font globally
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/login', // ✅ Force login as the first screen
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => LoginPage());
          case '/signup':
            return MaterialPageRoute(builder: (_) => SignUpPage());
          case '/otp':
            return MaterialPageRoute(builder: (_) => OTPVerificationPage(
              email: '',
              firstName: '',
              lastName: '',
              phone: '',
              address: '',
              birthday: null,
            ));
          case '/dashboard':
            return MaterialPageRoute(builder: (_) => ClientDashboard());
          default:
            return MaterialPageRoute(builder: (_) => LoginPage());
        }
      },
    );
  }
}

/// ✅ Determines the initial screen based on user session
class AuthCheck extends StatefulWidget {
  @override
  _AuthCheckState createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() {
    super.initState();
    _redirectUser();
  }

  /// ✅ Check if there's an active session and navigate accordingly
  void _redirectUser() async {
    await Future.delayed(Duration(seconds: 1)); // ✅ Small delay for better user experience
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && session.user != null) {
      Navigator.pushReplacementNamed(context, '/dashboard'); // ✅ Use named route
    } else {
      Navigator.pushReplacementNamed(context, '/login'); // ✅ Use named route
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()), // ✅ Show loading while checking session
    );
  }
}
