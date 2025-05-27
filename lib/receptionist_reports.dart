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
  double _totalSales = 0;
  List<Map<String, dynamic>> _serviceStats = [];
  String _selectedReport = 'sales';

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
          .eq('status', 'Completed')
          .gte('booking_date', _dateRange!.start.toIso8601String())
          .lte('booking_date', _dateRange!.end.toIso8601String());

      Map<String, Map<String, dynamic>> serviceStats = {};
      double totalSales = 0;

      for (var appointment in response) {
        final serviceName = appointment['service']['service_name'] as String;
        final servicePrice = appointment['service']['service_price'] as num;
        
        if (!serviceStats.containsKey(serviceName)) {
          serviceStats[serviceName] = {
            'service': serviceName,
            'count': 0,
            'revenue': 0.0,
          };
        }
        
        serviceStats[serviceName]!['count'] = (serviceStats[serviceName]!['count'] as int) + 1;
        serviceStats[serviceName]!['revenue'] = (serviceStats[serviceName]!['revenue'] as double) + servicePrice;
        totalSales += servicePrice;
      }

      setState(() {
        _totalSales = totalSales;
        _serviceStats = serviceStats.values.toList()
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Reports'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Sales Report'),
              Tab(text: 'Frequently Availed Services'),
            ],
            onTap: (index) {
              setState(() {
                _selectedReport = index == 0 ? 'sales' : 'services';
              });
            },
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.calendar_today),
                      label: Text(DateFormat('yyyy-MM-dd').format(_dateRange!.start)),
                      onPressed: () => _selectDateRange(),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.calendar_today),
                      label: Text(DateFormat('yyyy-MM-dd').format(_dateRange!.end)),
                      onPressed: () => _selectDateRange(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _buildSalesView(),
                        _buildServicesView(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesView() {
    double totalRevenue = _totalSales;

    return Column(
      children: [
        Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Total Revenue', style: TextStyle(fontSize: 20)),
                Text(
                  '₱${totalRevenue.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _serviceStats.length,
            itemBuilder: (context, index) {
              final stat = _serviceStats[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(stat['service']),
                  subtitle: Text('${stat['count']} bookings'),
                  trailing: Text(
                    '₱${(stat['revenue'] as double).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildServicesView() {
    if (_serviceStats.isEmpty) {
      return Center(child: Text('No services data available'));
    }

    final totalBookings = _serviceStats.fold(0, (sum, item) => sum + (item['count'] as int));

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.7,
          child: Card(
            margin: EdgeInsets.all(16),
            child: PieChart(
              PieChartData(
                sections: _serviceStats.take(5).map((service) {
                  final percentage = (service['count'] as int) / totalBookings * 100;
                  return PieChartSectionData(
                    value: service['count'].toDouble(),
                    title: '${percentage.toStringAsFixed(1)}%\n${service['service']}',
                    radius: 100,
                    titleStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _serviceStats.length,
            itemBuilder: (context, index) {
              final service = _serviceStats[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  title: Text(service['service']),
                  subtitle: Text('Booked ${service['count']} times'),
                  trailing: Text(
                    '₱${(service['revenue'] as double).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
