import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageBookingsPage extends StatefulWidget {
  @override
  _ManageBookingsPageState createState() => _ManageBookingsPageState();
}

class _ManageBookingsPageState extends State<ManageBookingsPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  /// ✅ Fetch upcoming and past appointments
  Future<void> _fetchAppointments() async {
  final response = await supabase
      .from('appointment')
      .select('book_id, booking_date, booking_time, status, service:service_id(service_name, spa:spa_id(spa_name))')
      .order('booking_date', ascending: true);

  if (mounted) {
    setState(() {
      _appointments = List<Map<String, dynamic>>.from(response);
      _isLoading = false;
    });
  }
}


  /// ✅ Cancel an appointment
  Future<void> _cancelAppointment(int appointmentId) async {
    await supabase.from('appointment').delete().eq('appointment_id', appointmentId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Appointment canceled.")));
    _fetchAppointments(); // Refresh appointments
  }

  /// ✅ Reschedule an appointment (Placeholder for now)
  void _rescheduleAppointment(int appointmentId) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rescheduling feature (To be implemented).")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage Appointments")),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
              ? Center(child: Text("No appointments found."))
              : ListView.builder(
                  itemCount: _appointments.length,
                  itemBuilder: (context, index) {
                    final appointment = _appointments[index];
                    return Card(
                      margin: EdgeInsets.all(10),
                      child: ListTile(
                        title: Text("${appointment['service']['service_name']} at ${appointment['spa']['spa_name']}"),
                        subtitle: Text("Date: ${appointment['date']} | Time: ${appointment['time']} | Status: ${appointment['status']}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _rescheduleAppointment(appointment['appointment_id']),
                            ),
                            IconButton(
                              icon: Icon(Icons.cancel, color: Colors.red),
                              onPressed: () => _cancelAppointment(appointment['appointment_id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
