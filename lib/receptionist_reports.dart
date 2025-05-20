import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReceptionistReports extends StatefulWidget {
  final Map<String, dynamic> receptionistData;

  const ReceptionistReports({Key? key, required this.receptionistData}) : super(key: key);

  @override
  _ReceptionistReportsState createState() => _ReceptionistReportsState();
}

class _ReceptionistReportsState extends State<ReceptionistReports> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = true;
  DateTimeRange? _dateRange;
  double _totalRevenue = 0;
  int _totalAppointments = 0;
  List<Map<String, dynamic>> _topServices = [];

  @override
  void initState() {
    super.initState();
    _dateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    );
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    if (widget.receptionistData['spa_id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No spa linked to this receptionist')),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      final int spaId = widget.receptionistData['spa_id'];
      final String startDate = DateFormat('yyyy-MM-dd').format(_dateRange!.start);
      final String endDate = DateFormat('yyyy-MM-dd').format(_dateRange!.end.add(const Duration(days: 1)));

      final appointments = await supabase
          .from('appointment')
          .select('*, service(service_name, service_price)')
          .eq('spa_id', spaId)
          .gte('booking_date', startDate)
          .lt('booking_date', endDate)
          .eq('status', 'Completed');

      double revenue = 0;
      int totalAppointments = appointments.length;
      Map<String, int> serviceCounts = {};

      for (var appointment in appointments) {
        final service = appointment['service'];
        if (service != null) {
          revenue += double.tryParse(service['service_price'].toString()) ?? 0.0;
          final serviceName = service['service_name'];
          serviceCounts[serviceName] = (serviceCounts[serviceName] ?? 0) + 1;
        }
      }

      final sortedServices = serviceCounts.entries
          .map((entry) => {'service_name': entry.key, 'count': entry.value})
          .toList()
          ..sort((a, b) => ((b as Map<String, dynamic>)['count'] ?? 0).compareTo((a as Map<String, dynamic>)['count'] ?? 0));


      if (mounted) {
        setState(() {
          _totalRevenue = revenue;
          _totalAppointments = totalAppointments;
          _topServices = sortedServices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
      });
      _fetchReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receptionist Reports'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  // Date Range Selector
                  InkWell(
                    onTap: _pickDateRange,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Date Range: ${DateFormat('MMM dd, yyyy').format(_dateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange!.end)}",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats
                  Text(
                    "Total Appointments: $_totalAppointments",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Total Revenue: ₱${_totalRevenue.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  // Services
                  const Text(
                    "Most Frequently Availed Services",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (_topServices.isEmpty)
                    const Text("No services found for selected period."),
                  ..._topServices.map((service) => ListTile(
                        title: Text(service['service_name']),
                        trailing: Text("${service['count']} bookings"),
                      )),
                ],
              ),
            ),
    );
  }
}
