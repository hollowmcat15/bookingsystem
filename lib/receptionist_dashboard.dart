import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'receptionist_bookings.dart'; // Import the receptionist_bookings.dart file
import 'login.dart';
import 'profile_page.dart';
import 'receptionist_commission.dart';
import 'receptionist_reports.dart';
import 'notifications_page.dart';

class ReceptionistDashboard extends StatefulWidget {
  final Map<String, dynamic> receptionistData;

  const ReceptionistDashboard({
    Key? key,
    required this.receptionistData,
  }) : super(key: key);

  @override
  _ReceptionistDashboardState createState() => _ReceptionistDashboardState();
}

class _ReceptionistDashboardState extends State<ReceptionistDashboard> {
  final SupabaseClient supabase = Supabase.instance.client;
  Map<String, dynamic>? spaDetails;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSpaDetails();
  }

  Future<void> _fetchSpaDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await supabase
          .from('spa')
          .select('*, service(*)')
          .eq('spa_id', widget.receptionistData['spa_id'])
          .single();

      setState(() {
        spaDetails = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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

  void _navigateToBookings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceptionistBookings(
          receptionistId: widget.receptionistData['receptionist_id'],
          spaId: widget.receptionistData['spa_id'],
        )
      )
    ).then((_) {
      // Refresh data when returning from bookings page
      setState(() {}); // Trigger a rebuild to refresh the appointments list
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.business, color: Colors.white, size: 50),
                  SizedBox(height: 8),
                  Text(
                    "Receptionist Menu",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.spa),
              title: Text("Spa Details"),
              onTap: () {
                Navigator.pop(context);
                _fetchSpaDetails();
              },
            ),
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text("Manage Appointments"),
              onTap: () {
                Navigator.pop(context);
                _navigateToBookings();
              },
            ),
            ListTile(
              leading: Icon(Icons.account_circle),
              title: Text("Profile Settings"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(userRole: 'receptionist')
                  )
                ).then((_) {
                  // Refresh receptionist data when returning from profile page if needed
                  _fetchSpaDetails();
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.assessment),
              title: Text("View Reports"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReceptionistReports(receptionistData: widget.receptionistData)
                  )
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.attach_money),
              title: Text("View Commissions"),
              onTap: () {
                Navigator.pop(context);
                  Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ReceptionistCommissionsPage(
      receptionistId: widget.receptionistData['receptionist_id'],
    ),
  ),
);

              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NotificationsPage(
                    userId: widget.receptionistData['receptionist_id'].toString(), // Convert to String
                    role: 'receptionist',
                  )),
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
        title: Text("Receptionist Dashboard"),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(fontSize: 18, color: Colors.red)))
              : _buildSpaDetailsView(),
    );
  }
  
  Widget _buildSpaDetailsView() {
    if (spaDetails == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No spa details available',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Spa Details Card - removed welcome back dialog and spa information heading
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image with overlay
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        child: spaDetails!['image_url'] != null
                            ? Image.network(
                                spaDetails!['image_url'],
                                width: double.infinity,
                                height: 180,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: double.infinity,
                                height: 180,
                                color: Colors.teal.shade100,
                                child: Icon(Icons.image, size: 64, color: Colors.teal.shade700),
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Text(
                            spaDetails!['spa_name'],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Spa details content
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Address row
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.grey[700], size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                spaDetails!['spa_address'],
                                style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        
                        // Phone row
                        Row(
                          children: [
                            Icon(Icons.phone, color: Colors.grey[700], size: 20),
                            SizedBox(width: 8),
                            Text(
                              spaDetails!['spa_phonenumber'],
                              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        
                        // Description
                        Text(
                          "About",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          spaDetails!['description'],
                          style: TextStyle(fontSize: 15, height: 1.4),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Services section
                        Text(
                          "Services Offered",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 12),
                        
                        // Services list
                        ListView.separated(
                          physics: NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: spaDetails!['service'].length,
                          separatorBuilder: (context, index) => Divider(height: 1),
                          itemBuilder: (context, index) {
                            final service = spaDetails!['service'][index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.spa, color: Colors.teal),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      service['service_name'],
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  Text(
                                    "\$${service['service_price'].toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}