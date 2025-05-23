import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminViewAppointments extends StatefulWidget {
  @override
  _AdminViewAppointmentsState createState() => _AdminViewAppointmentsState();
}

class _AdminViewAppointmentsState extends State<AdminViewAppointments> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> appointments = [];
  bool _isLoading = false;
  String? _error;
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    try {
      setState(() => _isLoading = true);
      final response = await supabase
          .from('appointment')
          .select('''
            *,
            client:client_id(*),
            spa:spa_id(*),
            service:service_id(*),
            therapist:therapist_id(*)
          ''')
          .order('booking_date', ascending: false);

      setState(() {
        appointments = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredAppointments = _filterStatus == 'All'
        ? appointments
        : appointments.where((a) => a['status'] == _filterStatus).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('View Appointments'),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String>(
              value: _filterStatus,
              dropdownColor: Theme.of(context).primaryColor,
              style: TextStyle(color: Colors.white),
              iconEnabledColor: Colors.white,
              underline: Container(),
              items: ['All', 'Scheduled', 'Completed', 'Cancelled', 'Rescheduled']
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _filterStatus = value!),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAppointments,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : filteredAppointments.isEmpty
                ? Center(child: Text('No appointments found'))
                : ListView.builder(
                    itemCount: filteredAppointments.length,
                    itemBuilder: (context, index) {
                      final appointment = filteredAppointments[index];
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text('${appointment['client']['first_name']} ${appointment['client']['last_name']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Service: ${appointment['service']['service_name']}'),
                              Text('Spa: ${appointment['spa']['spa_name']}'),
                              Text('Date: ${appointment['booking_date']}'),
                              Text('Status: ${appointment['status']}',
                                  style: TextStyle(
                                    color: _getStatusColor(appointment['status']),
                                    fontWeight: FontWeight.bold,
                                  )),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Scheduled':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      case 'Rescheduled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
