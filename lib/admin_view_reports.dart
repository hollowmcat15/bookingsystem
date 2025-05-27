import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminViewReports extends StatefulWidget {
  const AdminViewReports({super.key});

  @override
  _AdminViewReportsState createState() => _AdminViewReportsState();
}

class _AdminViewReportsState extends State<AdminViewReports> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<Map<String, dynamic>> reportData = [];
  String _selectedReport = 'sales'; // Changed from 'appointment'
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Set default date range to last 30 days
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(Duration(days: 30));
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    try {
      setState(() => _isLoading = true);

      final response = await supabase
          .from('appointment')
          .select('''
            book_id,
            booking_date,
            status,
            spa:spa_id (
              spa_name
            ),
            service:service_id (
              service_id,
              service_name,
              service_price
            )
          ''')
          .gte('booking_date', _startDate!.toIso8601String().split('T')[0])
          .lte('booking_date', _endDate!.toIso8601String().split('T')[0])
          .order('booking_date', ascending: false);

      setState(() {
        reportData = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report: $e')),
      );
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
                _fetchReportData();
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
                      label: Text(_startDate == null
                          ? 'Start Date'
                          : _startDate!.toString().split(' ')[0]),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _startDate = date;
                            _fetchReportData();
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.calendar_today),
                      label: Text(_endDate == null
                          ? 'End Date'
                          : _endDate!.toString().split(' ')[0]),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _endDate = date;
                            _fetchReportData();
                          });
                        }
                      },
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
                        _buildRevenueReport(),
                        _buildPopularServicesReport(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '₱${(amount / 1000000).toStringAsFixed(2)}M';
    } else if (amount >= 1000) {
      return '₱${(amount / 1000).toStringAsFixed(2)}K';
    }
    return '₱${amount.toStringAsFixed(2)}';
  }

  Widget _buildRevenueReport() {
    // Group sales by spa
    Map<String, double> spaRevenue = {};
    double totalRevenue = 0.0;

    for (var item in reportData) {
      if (item['status'] == 'Completed' &&
          item['service'] != null &&
          item['service']['service_price'] != null) {
        final spaName = item['spa']['spa_name'] as String;
        final price = (item['service']['service_price'] as num).toDouble();
        spaRevenue[spaName] = (spaRevenue[spaName] ?? 0) + price;
        totalRevenue += price;
      }
    }

    final spas = spaRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
                  _formatCurrency(totalRevenue),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Divider(height: 24),
                Text('Revenue by Spa', style: TextStyle(fontSize: 16)),
                ...spas.map((spa) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(spa.key),
                      Text(
                        _formatCurrency(spa.value),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: reportData.length,
            itemBuilder: (context, index) {
              final item = reportData[index];
              if (item['status'] != 'Completed') return SizedBox.shrink();
              
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text('${item['service']['service_name']} at ${item['spa']['spa_name']}'),
                  subtitle: Text(item['booking_date']),
                  trailing: Text(
                    _formatCurrency(item['service']['service_price']),
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

  Widget _buildPopularServicesReport() {
    Map<String, int> serviceFrequency = {};
    Map<String, double> serviceRevenue = {};

    for (var item in reportData) {
      if (item['status'] == 'Completed' &&
          item['service'] != null &&
          item['service']['service_name'] != null) {
        final serviceName = item['service']['service_name'] as String;
        final price = (item['service']['service_price'] as num).toDouble();

        serviceFrequency[serviceName] = (serviceFrequency[serviceName] ?? 0) + 1;
        serviceRevenue[serviceName] = (serviceRevenue[serviceName] ?? 0) + price;
      }
    }

    // Sort by frequency
    final sortedServices = serviceFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Get top 5 services for pie chart
    final top5Services = sortedServices.take(5).toList();
    final totalBookings = top5Services.fold(0, (sum, item) => sum + item.value);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.7,
          child: Card(
            margin: EdgeInsets.all(16),
            child: PieChart(
              PieChartData(
                sections: top5Services.map((service) {
                  final percentage = (service.value / totalBookings * 100);
                  return PieChartSectionData(
                    value: service.value.toDouble(),
                    title: '${percentage.toStringAsFixed(1)}%\n${service.key}',
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
            itemCount: sortedServices.length,
            itemBuilder: (context, index) {
              final service = sortedServices[index];
              final revenue = serviceRevenue[service.key] ?? 0.0;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  title: Text(service.key),
                  subtitle: Text('Booked ${service.value} times'),
                  trailing: Text(
                    _formatCurrency(revenue),
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
