import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'admin_manage_manager.dart';
import 'admin_manage_staff.dart';
import 'admin_manage_spa.dart';
import 'admin_view_clients.dart';
import 'admin_view_appointments.dart';

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
      final spasCount = await supabase
          .from('spa')
          .select('count');
      final managersCount = await supabase
          .from('staff')
          .select('count')
          .eq('role', 'Manager');
      final clientsCount = await supabase
          .from('client')
          .select('count');
      final appointmentsCount = await supabase
          .from('appointment')
          .select('count');
          
      setState(() {
        stats = {
          'spas': spasCount.length,
          'managers': managersCount.length,
          'clients': clientsCount.length,
          'appointments': appointmentsCount.length,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addNewManager() async {
    // Show dialog to add new manager
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Manager'),
        content: SingleChildScrollView(
          child: AddManagerForm(
            onManagerAdded: () {
              _fetchStats();
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewManager,
        child: Icon(Icons.add),
        tooltip: 'Add New Manager',
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

class AddManagerForm extends StatefulWidget {
  final VoidCallback onManagerAdded;

  const AddManagerForm({Key? key, required this.onManagerAdded}) : super(key: key);

  @override
  _AddManagerFormState createState() => _AddManagerFormState();
}

class _AddManagerFormState extends State<AddManagerForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthdayController = TextEditingController();

  Future<void> _addManager() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final supabase = Supabase.instance.client;
      
      // Create auth user
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text,
        password: 'temppass123', // Temporary password
        data: {'role': 'manager'},
      );

      if (authResponse.user != null) {
        // Add to staff table
        await supabase.from('staff').insert({
          'auth_id': authResponse.user!.id,
          'first_name': _firstNameController.text,
          'last_name': _lastNameController.text,
          'email': _emailController.text,
          'phonenumber': _phoneController.text,
          'role': 'Manager',
          'birthday': _birthdayController.text,
        });

        widget.onManagerAdded();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding manager: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(labelText: 'Email'),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          TextFormField(
            controller: _firstNameController,
            decoration: InputDecoration(labelText: 'First Name'),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          TextFormField(
            controller: _lastNameController,
            decoration: InputDecoration(labelText: 'Last Name'),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(labelText: 'Phone'),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              if (value.length != 11) return 'Phone number must be 11 digits';
              if (!RegExp(r'^\d{11}$').hasMatch(value)) {
                return 'Enter a valid 11 digit phone number';
              }
              return null;
            },
            keyboardType: TextInputType.phone,
            maxLength: 11,
          ),
          TextFormField(
            controller: _birthdayController,
            decoration: InputDecoration(labelText: 'Birthday (YYYY-MM-DD)'),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
                return 'Enter a valid date in YYYY-MM-DD format';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _addManager,
            child: Text('Add Manager'),
          ),
        ],
      ),
    );
  }
}