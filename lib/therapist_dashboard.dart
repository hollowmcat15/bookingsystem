import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'therapist_commission.dart';
import 'login.dart';
import 'edit_profile.dart';
import 'profile_page.dart';

class TherapistDashboard extends StatefulWidget {
  final Map<String, dynamic> therapistData;

  const TherapistDashboard({Key? key, required this.therapistData}) : super(key: key);

  @override
  _TherapistDashboardState createState() => _TherapistDashboardState();
}

class _TherapistDashboardState extends State<TherapistDashboard> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingAppointments = [];
  List<Map<String, dynamic>> _pastAppointments = []; // Still needed for the dialog
  String _currentStatus = 'Active';
  final List<String> _statusOptions = ['Active', 'Inactive', 'Busy'];

  @override
  void initState() {
    super.initState();
    _loadTherapistData();
    _loadAppointments();
  }

  Future<void> _loadTherapistData() async {
     try {
      final int therapistId = widget.therapistData['therapist_id'];
      final response = await supabase
          .from('therapist')
          .select('status')
          .eq('therapist_id', therapistId)
          .single();

      if (mounted) {
        setState(() {
          _currentStatus = response['status'] ?? 'Active';
        });
      }
    } catch (e) {
      print("Error loading therapist status: $e");
       if (mounted) {
        setState(() {
          _currentStatus = widget.therapistData['status'] ?? 'Active';
        });
      }
    }
  }

  Future<void> _loadAppointments() async {
  if (!mounted) return;
  setState(() {
    _isLoading = true;
    _upcomingAppointments = [];
    _pastAppointments = [];
  });

  try {
    final int therapistId = widget.therapistData['therapist_id'];
    final DateTime today = DateTime.now();
    final DateTime midnightToday = DateTime(today.year, today.month, today.day);
    final String formattedMidnightToday = DateFormat('yyyy-MM-dd').format(midnightToday);

    // Fetch UPCOMING Appointments
    final upcomingResponse = await supabase
        .from('appointment')
        .select('''
          book_id, booking_date, booking_start_time, booking_end_time, status,
          client(client_id, first_name, last_name),
          service(service_id, service_name, service_price)
        ''')
        .eq('therapist_id', therapistId)
        .gte('booking_date', formattedMidnightToday)
        .order('booking_date', ascending: true)
        .order('booking_start_time', ascending: true);

    // Fetch PAST Appointments (Still fetch them, but display in dialog)
    final pastResponse = await supabase
        .from('appointment')
        .select('''
          book_id, booking_date, booking_start_time, booking_end_time, status,
          client(client_id, first_name, last_name),
          service(service_id, service_name, service_price)
        ''')
        .eq('therapist_id', therapistId)
        .lt('booking_date', formattedMidnightToday)
        .order('booking_date', ascending: false)
        .order('booking_start_time', ascending: false);

    if (mounted) {
      setState(() {
        _upcomingAppointments = List<Map<String, dynamic>>.from(upcomingResponse);
        _pastAppointments = List<Map<String, dynamic>>.from(pastResponse); // Store past appointments
        
        // Sort appointments by status priority
        _upcomingAppointments.sort((a, b) => _getStatusPriority(a['status']) - _getStatusPriority(b['status']));
        _pastAppointments.sort((a, b) => _getStatusPriority(a['status']) - _getStatusPriority(b['status']));
        
        _isLoading = false;
      });
    }
  } catch (e) {
    print("Error loading appointments: $e");
    if (mounted) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading appointments: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }
}

// Helper method to determine status priority for sorting
int _getStatusPriority(String? status) {
  switch (status) {
    case 'Scheduled': return 0;
    case 'Rescheduled': return 1;
    case 'Completed': return 2;
    case 'Cancelled': return 3;
    default: return 4; // Any unknown status will be shown last
  }
}

  void _navigateToProfile() {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => ProfilePage(
      userRole: 'therapist',
      initialData: widget.therapistData,
    )),
  ).then((updatedData) { 
    // Check if we got updated data back
    if (updatedData != null && updatedData is Map<String, dynamic>) {
      setState(() {
        // Update the local therapist data with new values
        widget.therapistData['first_name'] = updatedData['first_name'];
        widget.therapistData['last_name'] = updatedData['last_name'];
        widget.therapistData['email'] = updatedData['email'];
        widget.therapistData['phonenumber'] = updatedData['phonenumber'];
        // Add other fields you want to update
      });
    }
    // Also refresh from database
    _loadTherapistData(); 
  });
}

  void _navigateToCommissions() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => TherapistCommission(therapistData: widget.therapistData)));
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage())
      );
    }
  }

  // --- Function to Show Past Appointments Dialog ---
  Future<void> _showPastAppointmentsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Past Appointments'),
          insetPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          contentPadding: EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 0),
          titlePadding: EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _pastAppointments.isEmpty
                  ? Center(
                      child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text('No past appointments found.', style: TextStyle(color: Colors.grey[600])),
                    ))
                  : ListView.builder(
                      itemCount: _pastAppointments.length,
                      itemBuilder: (context, index) {
                        return _buildAppointmentListItem(_pastAppointments[index]);
                      },
                    ),
          ),
          actionsPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        );
      },
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
              decoration: BoxDecoration(color: Colors.teal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.spa, color: Colors.white, size: 50),
                  SizedBox(height: 8),
                  Text(
                    "Therapist Menu",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text("Profile Settings"),
              onTap: () {
                Navigator.pop(context);
                _navigateToProfile();
              },
            ),
            ListTile(
              leading: Icon(Icons.calendar_today),
              title: Text("View Appointments"),
              onTap: () {
                Navigator.pop(context);
                // Just refresh the appointments on the main screen
                _loadAppointments();
              },
            ),
            ListTile(
              leading: Icon(Icons.attach_money),
              title: Text("View Commissions"),
              onTap: () {
                Navigator.pop(context);
                _navigateToCommissions();
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
        title: Text("Therapist Dashboard"),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAppointments,
            tooltip: 'Refresh Appointments',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAppointments,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Therapist Info Card (similar to spa info card)
              Text(
                "Your Profile",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Card(
                margin: EdgeInsets.symmetric(vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.therapistData['first_name'] ?? ''} ${widget.therapistData['last_name'] ?? ''}',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text('Therapist ID: ${widget.therapistData['therapist_id'] ?? 'N/A'}'),
                              SizedBox(height: 4),
                              Text('Spa ID: ${widget.therapistData['spa_id'] ?? 'N/A'}'),
                            ],
                          ),
                          // Status dropdown
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(_currentStatus).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButton<String>(
                              value: _currentStatus,
                              items: _statusOptions.map((String status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10, 
                                        height: 10, 
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status), 
                                          shape: BoxShape.circle
                                        )
                                      ),
                                      SizedBox(width: 8),
                                      Text(status),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null && newValue != _currentStatus) {
                                  _updateStatus(newValue);
                                }
                              },
                              underline: Container(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Upcoming Appointments",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _showPastAppointmentsDialog,
                    icon: Icon(Icons.history, size: 20),
                    label: Text("Past"),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Expanded(
                child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _upcomingAppointments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No upcoming appointments',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _upcomingAppointments.length,
                        itemBuilder: (context, index) {
                          return _buildAppointmentListItem(_upcomingAppointments[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active': return Colors.green;
      case 'Busy': return Colors.orange;
      case 'Inactive': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildAppointmentListItem(Map<String, dynamic> appointment) {
    final clientData = appointment['client'] as Map<String, dynamic>? ?? {};
    final serviceData = appointment['service'] as Map<String, dynamic>? ?? {};
    final clientName = '${clientData['first_name'] ?? 'Unknown'} ${clientData['last_name'] ?? 'Client'}'.trim();
    final serviceName = serviceData['service_name'] ?? 'Unknown Service';
    final bookingDate = _formatAppointmentDate(appointment['booking_date']);
    final startTime = _formatAppointmentTime(appointment['booking_start_time']);
    final endTime = _formatAppointmentTime(appointment['booking_end_time']);
    final status = appointment['status'] ?? 'Scheduled';
    
    Color statusColor;
    switch (status) {
      case 'Completed': statusColor = Colors.green; break;
      case 'Cancelled': statusColor = Colors.red; break;
      case 'Rescheduled': statusColor = Colors.orange; break;
      case 'Scheduled': statusColor = Colors.blue; break;
      default: statusColor = Colors.grey;
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade100,
          child: Icon(Icons.person, color: Colors.teal),
        ),
        title: Text(
          clientName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text('Service: $serviceName'),
            Text('Date: $bookingDate'),
            Text('Time: $startTime - $endTime'),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatAppointmentDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try { return DateFormat('EEE, MMM dd, yyyy').format(DateTime.parse(dateString)); }
    catch (e) { return dateString; }
  }

  String _formatAppointmentTime(String? timeString) {
    if (timeString == null) return 'N/A';
    try { return DateFormat('h:mm a').format(DateFormat('HH:mm:ss').parse(timeString)); }
    catch (e) { return timeString; }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      final int therapistId = widget.therapistData['therapist_id'];
      await supabase.from('therapist').update({'status': newStatus}).eq('therapist_id', therapistId);
      if (mounted) {
        setState(() { 
          _currentStatus = newStatus; 
          widget.therapistData['status'] = newStatus; 
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'), 
            backgroundColor: Colors.green, 
            duration: Duration(seconds: 2)
          )
        );
      }
    } catch (e) {
      print("Error updating status: $e");
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: ${e.toString()}'), 
            backgroundColor: Colors.red
          )
        ); 
      }
    }
  }
}