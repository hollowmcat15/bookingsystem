import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'manage_bookings.dart';
import 'login.dart';
import 'manage_spa.dart';
import 'profile_page.dart';
import 'manage_commission.dart';
import 'generate_reports.dart';
import 'manage_feedback.dart';
import 'manage_users.dart';
import 'add_spa.dart';
import 'manager_appointments.dart';

class ManagerDashboard extends StatefulWidget {
  final Map<String, dynamic> managerData;

  const ManagerDashboard({
    Key? key,
    required this.managerData,
  }) : super(key: key);

  @override
  _ManagerDashboardState createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> managedSpas = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Add validation check
    if (widget.managerData['manager_id'] == null) {
      setState(() {
        _error = 'Invalid manager data';
      });
      return;
    }
    _fetchManagedSpas();
  }

  Future<void> _fetchManagedSpas() async {
    if (widget.managerData['manager_id'] == null) {
      setState(() {
        _error = 'Invalid manager ID';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await supabase
          .from('spa')
          .select('*, service(*)')
          .eq('manager_id', widget.managerData['manager_id']);

      if (mounted) {
        setState(() {
          managedSpas = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        print('Error fetching spas: $e'); // Debug print
      }
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
                  Icon(Icons.business, color: Colors.white, size: 50),
                  SizedBox(height: 8),
                  Text(
                    "Manager Menu",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.spa),
              title: Text("My Spas"),
              onTap: _fetchManagedSpas,
            ),
            ListTile(
  leading: Icon(Icons.calendar_today),
  title: Text("Manage Appointments"),
  onTap: () {
    // If multiple spas, show a selection dialog first
    if (managedSpas.length > 1) {
      _selectSpaForAction((selectedSpaId) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ManagerAppointmentsPage(
              managerId: widget.managerData['manager_id'],
              spaId: selectedSpaId,
            )
          )
        );
      });
    } else if (managedSpas.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ManagerAppointmentsPage(
            managerId: widget.managerData['manager_id'],
            spaId: managedSpas[0]['spa_id'],
          )
        )
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No spas available to manage appointments for"))
      );
    }
  },
),
            ListTile(
              leading: Icon(Icons.account_circle),
              title: Text("Profile Settings"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(userRole: 'manager')
                  )
                ).then((_) {
                  // Refresh manager data when returning from profile page if needed
                  _fetchManagedSpas();
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.feedback),
              title: Text("Manage Feedback"),
              onTap: () {
                // If multiple spas, show a selection dialog first
                if (managedSpas.length > 1) {
                  _selectSpaForAction((selectedSpaId) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManageFeedback(spaId: selectedSpaId)
                      )
                    );
                  });
                } else if (managedSpas.length == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageFeedback(spaId: managedSpas[0]['spa_id'])
                    )
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("No spas available to manage feedback for"))
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.assessment),
              title: Text("Generate Reports"),
              onTap: () {
                // If multiple spas, show a selection dialog first
                if (managedSpas.length > 1) {
                  _selectSpaForAction((selectedSpaId) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GenerateReports(spaId: selectedSpaId)
                      )
                    );
                  });
                } else if (managedSpas.length == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GenerateReports(spaId: managedSpas[0]['spa_id'])
                    )
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("No spas available to generate reports for"))
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.attach_money),
              title: Text("Manage Commissions"),
              onTap: () {
                // If multiple spas, show a selection dialog first
                if (managedSpas.length > 1) {
                  _selectSpaForAction((selectedSpaId) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManageCommission(spaId: selectedSpaId)
                      )
                    );
                  });
                } else if (managedSpas.length == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageCommission(spaId: managedSpas[0]['spa_id'])
                    )
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("No spas available to manage commissions for"))
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.people),
              title: Text("Manage Users"),
              onTap: () {
                // If multiple spas, show a selection dialog first
                if (managedSpas.length > 1) {
                  _selectSpaForAction((selectedSpaId) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManageUsers(spaId: selectedSpaId)
                      )
                    );
                  });
                } else if (managedSpas.length == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageUsers(spaId: managedSpas[0]['spa_id'])
                    )
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("No spas available to manage users for"))
                  );
                }
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
        title: Text("Manager Dashboard"),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Managed Spas",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text("Add Spa"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddSpa(
                          managerId: widget.managerData['manager_id'],
                        ),
                      ),
                    ).then((_) {
                      // Refresh spa details when returning from AddSpa
                      _fetchManagedSpas();
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 10),
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: TextStyle(fontSize: 18, color: Colors.red)))
                    : managedSpas.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.business, size: 60, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    "No spas found.",
                                    style: TextStyle(fontSize: 18, color: Colors.grey),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Add a spa to begin managing your business.",
                                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Expanded(
                            child: ListView.builder(
                              itemCount: managedSpas.length,
                              itemBuilder: (context, index) {
                                final spa = managedSpas[index];
                                final services = spa['service'] ?? [];
                                
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
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(spa['spa_name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                            SizedBox(height: 4),
                                            Text(spa['spa_address']),
                                            SizedBox(height: 4),
                                            Text(spa['description'] ?? "No description available"),
                                            SizedBox(height: 4),
                                            Text("Phone: ${spa['spa_phonenumber']}"),
                                            SizedBox(height: 8),
                                            
                                            if (services.isNotEmpty) ...[
                                              Text("Services:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                              SizedBox(height: 4),
                                              ...List.generate(services.length > 3 ? 3 : services.length, (serviceIndex) {
                                                final service = services[serviceIndex];
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                                  child: Text("${service['service_name']} - ₱${service['service_price']}"),
                                                );
                                              }),
                                              if (services.length > 3)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2.0),
                                                  child: Text("+ ${services.length - 3} more services", style: TextStyle(color: Colors.blue)),
                                                ),
                                            ] else
                                              Text("No services available", style: TextStyle(fontStyle: FontStyle.italic)),
                                            
                                            SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                ElevatedButton(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => ManageSpa(spaId: spa['spa_id']),
                                                      ),
                                                    ).then((_) {
                                                      _fetchManagedSpas();
                                                    });
                                                  },
                                                  child: Text("Manage"),
                                                ),
                                              ],
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
  
  // Helper method to show a spa selection dialog when a manager has multiple spas
  void _selectSpaForAction(Function(int) onSpaSelected) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Spa"),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: managedSpas.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(managedSpas[index]['spa_name']),
                  subtitle: Text(managedSpas[index]['spa_address']),
                  onTap: () {
                    Navigator.of(context).pop();
                    onSpaSelected(managedSpas[index]['spa_id']);
                  },
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}