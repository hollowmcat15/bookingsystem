import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'admin_manage_manager.dart';
import 'admin_manage_staff.dart';
import 'admin_manage_spa.dart';
import 'admin_view_clients.dart';
import 'admin_view_appointments.dart';
import 'admin_add_manager.dart';  // Add this import
import 'profile_page.dart'; // Import the profile page
import 'admin_view_commission.dart';
import 'admin_view_reports.dart';
import 'admin_view_feedback.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic> adminData;

  const AdminDashboard({
    Key? key,
    required this.adminData,
  }) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final SupabaseClient supabase = Supabase.instance.client;
  Map<String, int> stats = {
    'spas': 0,
    'managers': 0,
    'clients': 0,
    'appointments': 0,
  };
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      setState(() => _isLoading = true);

      // Get count of approved spas
      final List<Map<String, dynamic>> spasResponse = await supabase
          .from('spa')
          .select('spa_id')
          .eq('approved', true);

      // Get count of managers
      final List<Map<String, dynamic>> managersResponse = await supabase
          .from('staff')
          .select('staff_id')
          .eq('role', 'Manager');

      // Get count of clients
      final List<Map<String, dynamic>> clientsResponse = await supabase
          .from('client')
          .select('client_id');

      // Get count of active appointments
      final List<Map<String, dynamic>> appointmentsResponse = await supabase
          .from('appointment')
          .select('book_id')
          .neq('status', 'Cancelled'); // Count non-cancelled appointments
          
      // Get count of feedback
      final List<Map<String, dynamic>> feedbackResponse = await supabase
          .from('feedback')
          .select('feedback_id');

      setState(() {
        stats = {
          'spas': spasResponse.length,
          'managers': managersResponse.length,
          'clients': clientsResponse.length,
          'appointments': appointmentsResponse.length,
          'feedback': feedbackResponse.length,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('Error fetching stats: $e'); // For debugging
    }
  }

  Future<void> _addNewManager() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AdminAddManager()),
    );
    
    if (result == true) {
      // Refresh stats if manager was added successfully
      _fetchStats();
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.admin_panel_settings, color: Colors.white, size: 50),
                  SizedBox(height: 8),
                  Text(
                    "Admin Menu",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.account_circle),
              title: Text("Profile Settings"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(
                      userRole: 'admin',
                      initialData: widget.adminData,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.people),
              title: Text("Manage Staff"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminManageStaff()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.manage_accounts),  // Add this ListTile
              title: Text("Manage Managers"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminManageManager()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.spa),
              title: Text("Manage Spas"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminManageSpa()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text("View Clients"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminViewClients()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text("View Appointments"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminViewAppointments()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.monetization_on),
              title: Text("View Commissions"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminViewCommission()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.assessment),
              title: Text("View Reports"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminViewReports()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.feedback),
              title: Text("View Feedback"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminViewFeedback()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.exit_to_app),
              title: Text("Logout"),
              onTap: _logout,
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text("Admin Dashboard"),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchStats,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Overview',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        _buildStatCard('Spas', stats['spas'] ?? 0, Icons.spa),
                        _buildStatCard('Managers', stats['managers'] ?? 0, Icons.manage_accounts),
                        _buildStatCard('Clients', stats['clients'] ?? 0, Icons.people),
                        _buildStatCard('Appointments', stats['appointments'] ?? 0, Icons.calendar_today),
                        _buildStatCard('Feedback', stats['feedback'] ?? 0, Icons.feedback),
                      ],
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Quick Actions',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.person_add),
                        title: Text('Add New Manager'),
                        trailing: Icon(Icons.arrow_forward_ios),
                        onTap: _addNewManager,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}