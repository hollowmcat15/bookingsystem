import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'spa_details.dart';
import 'manage_bookings.dart';
import 'login.dart';

class ClientDashboard extends StatefulWidget {
  @override
  _ClientDashboardState createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _spas = [];

  @override
  void initState() {
    super.initState();
    _fetchSpas();
  }

  /// ✅ Fetch available spas
  Future<void> _fetchSpas() async {
    final response = await supabase.from('spa').select('spa_id, spa_name, spa_address, image_url');
    if (mounted) {
      setState(() {
        _spas = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  /// ✅ Logout function
  Future<void> _logout() async {
    await supabase.auth.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
  }

  /// ✅ Opens account settings (Placeholder)
  void _openAccountSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Account Settings clicked (To be implemented).")),
    );
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
                  Icon(Icons.person, color: Colors.white, size: 50),
                  SizedBox(height: 8),
                  Text(
                    "Client Menu",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.account_circle),
              title: Text("Account Settings"),
              onTap: _openAccountSettings,
            ),
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text("Manage Appointments"),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ManageBookingsPage()));
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
        title: Text("Client Dashboard"),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Available Spas",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            _spas.isEmpty
                ? Expanded(
                    child: Center(
                      child: Text(
                        "No spas available",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      itemCount: _spas.length,
                      itemBuilder: (context, index) {
                        final spa = _spas[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8),
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                                child: spa['image_url'] != null
                                    ? Image.network(spa['image_url'], width: double.infinity, height: 150, fit: BoxFit.cover)
                                    : Container(
                                        width: double.infinity,
                                        height: 150,
                                        color: Colors.grey[300],
                                        child: Icon(Icons.image, size: 50, color: Colors.grey[700]),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(spa['spa_name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    SizedBox(height: 4),
                                    Text(spa['spa_address'] ?? "No location provided"),
                                    SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => SpaDetails(spaId: spa['spa_id']),
                                            ),
                                          );
                                        },
                                        child: Text("View Details"),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}



