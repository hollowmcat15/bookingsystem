import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart'; // Add this package

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
  List<Map<String, dynamic>> _appointmentStats = [];
  List<Map<String, dynamic>> _serviceStats = [];

  @override
  void initState() {
    super.initState();
    _dateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('appointment')
          .select('''
            booking_date,
            status,
            service:service_id (
              service_name,
              service_price
            )
          ''')
          .eq('spa_id', widget.receptionistData['spa_id'])
          .gte('booking_date', _dateRange!.start.toIso8601String())
          .lte('booking_date', _dateRange!.end.toIso8601String());

      // Process data for graphs
      Map<String, int> statusCounts = {
        'Scheduled': 0,
        'Completed': 0,
        'Cancelled': 0,
        'Rescheduled': 0,
      };
      
      Map<String, int> serviceBookings = {};

      for (var appointment in response) {
        // Count by status
        final status = appointment['status'] as String;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        // Count by service
        final serviceName = appointment['service']['service_name'] as String;
        serviceBookings[serviceName] = (serviceBookings[serviceName] ?? 0) + 1;
      }

      setState(() {
        _appointmentStats = statusCounts.entries
            .map((e) => {'status': e.key, 'count': e.value})
            .toList();

        _serviceStats = serviceBookings.entries
            .map((e) => {'service': e.key, 'count': e.value})
            .toList()
          ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
        _fetchAnalytics();
      });
    }
  }

  Widget _buildDateRangeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date Range',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('MMM dd, yyyy').format(_dateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange!.end)}',
            style: TextStyle(fontSize: 16, color: Colors.blueGrey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentStatusPieChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appointment Status',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
          ),
          const SizedBox(height: 16),
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: _appointmentStats
                          .map((stat) => PieChartSectionData(
                                value: stat['count'].toDouble(),
                                title: '${stat['status']}',
                                color: _getStatusColor(stat['status']),
                                radius: 50,
                              ))
                          .toList(),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildServiceBarChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Bookings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
          ),
          const SizedBox(height: 16),
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      barGroups: _serviceStats
                          .asMap()
                          .entries
                          .map((entry) {
                            final i = entry.key;
                            final stat = entry.value;
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: stat['count'].toDouble(),
                                  color: Colors.blue,
                                  width: 20,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          })
                          .toList(),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Scheduled':
        return Colors.orange;
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      case 'Rescheduled':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateRangeCard(),
                  const SizedBox(height: 20),
                  _buildAppointmentStatusPieChart(),
                  const SizedBox(height: 20),
                  _buildServiceBarChart(),
                ],
              ),
            ),
    );
  }
}
