import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class GenerateReports extends StatefulWidget {
  final int spaId;

  const GenerateReports({
    Key? key,
    required this.spaId,
  }) : super(key: key);

  @override
  _GenerateReportsState createState() => _GenerateReportsState();
}

class _GenerateReportsState extends State<GenerateReports> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _error;
  
  // Updated report parameters
  String _reportType = 'sales';  // Changed to match narrative
  String _dateRange = 'daily';
  int? _therapistId;
  int? _serviceId;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  
  // Data lists
  List<Map<String, dynamic>> _therapists = [];
  List<Map<String, dynamic>> _services = [];
  
  // Report data
  List<Map<String, dynamic>> _salesData = [];
  List<Map<String, dynamic>> _servicesData = [];
  Map<String, dynamic>? _currentReport;
  List<Map<String, dynamic>> _reports = [];
  
  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _fetchReports();
  }

  Future<void> _fetchInitialData() async {
    try {
      // Fetch therapists for this spa
      final therapistsResponse = await supabase
          .from('therapist')
          .select('therapist_id, first_name, last_name')
          .eq('spa_id', widget.spaId);
      
      // Fetch services for this spa
      final servicesResponse = await supabase
          .from('service')
          .select('service_id, service_name')
          .eq('spa_id', widget.spaId);

      setState(() {
        _therapists = therapistsResponse;
        _services = servicesResponse;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch actual completed appointments for reports list
      final response = await supabase
          .from('appointment')
          .select('''
            book_id,
            booking_date,
            service:service_id (
              service_name,
              service_price
            )
          ''')
          .eq('spa_id', widget.spaId)
          .eq('status', 'Completed')
          .order('booking_date', ascending: false);

      // Convert appointments to reports format
      final reports = response.fold<Map<String, Map<String, dynamic>>>({}, (map, appointment) {
        final date = appointment['booking_date'].toString().split(' ')[0];
        final monthKey = date.substring(0, 7); // Get YYYY-MM

        if (!map.containsKey(monthKey)) {
          map[monthKey] = {
            'id': DateTime.parse(date).millisecondsSinceEpoch,
            'type': 'sales',
            'title': 'Sales Report',
            'date_range': '$monthKey-01 to $monthKey-31',
            'booking_date': date,
          };
        }
        return map;
      }).values.toList();

      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final formattedStartDate = DateFormat('yyyy-MM-dd').format(_startDate);
      final formattedEndDate = DateFormat('yyyy-MM-dd').format(_endDate);
      
      Map<String, dynamic> reportData;
      
      switch (_reportType) {
        case 'sales':
          reportData = await _generateAppointmentReport(formattedStartDate, formattedEndDate);
          setState(() {
            _salesData = _processSalesDataFromReport(reportData);
          });
          break;
        case 'services':
          reportData = await _generateTherapistReport(formattedStartDate, formattedEndDate);
          setState(() {
            _servicesData = _processServicesDataFromReport(reportData);
          });
          break;
        default:
          throw Exception('Invalid report type');
      }

      final newReport = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'type': _reportType,
        'title': _getReportTitle(_reportType),
        'date_range': '$formattedStartDate to $formattedEndDate',
        'booking_date': formattedStartDate, // Changed from created_at
        'data': reportData,
      };

      setState(() {
        _reports.insert(0, newReport);
        _currentReport = newReport;
        _isLoading = false;
      });

      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _viewReport(Map<String, dynamic> report) async {
    setState(() {
      _isLoading = true;
      _currentReport = report;
    });

    try {
      final dateRange = report['date_range'].split(' to ');
      
      if (report['type'] == 'sales') {
        final reportData = await _generateAppointmentReport(dateRange[0], dateRange[1]);
        setState(() {
          _salesData = _processSalesDataFromReport(reportData);
        });
      } else if (report['type'] == 'services') {
        final reportData = await _generateTherapistReport(dateRange[0], dateRange[1]);
        setState(() {
          _servicesData = _processServicesDataFromReport(reportData);
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _processSalesDataFromReport(Map<String, dynamic> reportData) {
    final appointments = reportData['appointments'] as List;
    final Map<String, Map<String, dynamic>> dailyData = {};
    
    for (var appt in appointments) {
      if (appt['status'] == 'Completed') {
        final date = appt['booking_date'].toString().split(' ')[0];
        final servicePrice = double.tryParse(
          appt['service']['service_price'].toString()
        ) ?? 0.0;
        
        if (!dailyData.containsKey(date)) {
          dailyData[date] = {
            'date': date,
            'total_revenue': 0.0,
            'bookings': 0,
          };
        }
        
        dailyData[date]!['bookings'] = (dailyData[date]!['bookings'] as int) + 1;
        dailyData[date]!['total_revenue'] = 
            (dailyData[date]!['total_revenue'] as double) + servicePrice;
      }
    }
    
    final result = dailyData.values.toList();
    result.sort((a, b) => a['date'].compareTo(b['date']));
    return result;
  }

  List<Map<String, dynamic>> _processServicesDataFromReport(Map<String, dynamic> reportData) {
    print('Processing services data: $reportData'); // Debug print
    
    final appointments = reportData['appointments'] as List;
    final Map<int, Map<String, dynamic>> servicesCount = {};
    
    // Count service frequencies
    for (var appointment in appointments) {
      final serviceId = appointment['service_id'];
      final serviceName = appointment['service']['service_name'];
      
      if (!servicesCount.containsKey(serviceId)) {
        servicesCount[serviceId] = {
          'service_name': serviceName,
          'count': 0,
        };
      }
      servicesCount[serviceId]!['count'] = servicesCount[serviceId]!['count']! + 1;
    }
    
    // Calculate percentages
    final totalAppointments = appointments.length;
    final result = servicesCount.values.map((service) {
      return {
        'service_name': service['service_name'],
        'count': service['count'],
        'percentage': totalAppointments > 0 
          ? ((service['count'] as int) / totalAppointments * 100).round() 
          : 0,
      };
    }).toList();
    
    // Sort by count in descending order
    result.sort((a, b) => b['count'].compareTo(a['count']));
    
    print('Processed services data: $result'); // Debug print
    return result;
  }

  Future<Map<String, dynamic>> _generateAppointmentReport(String startDate, String endDate) async {
    final formattedEndDate = endDate + ' 23:59:59';
    
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
        .eq('spa_id', widget.spaId)
        .eq('status', 'Completed')
        .gte('booking_date', startDate)
        .lte('booking_date', formattedEndDate)
        .order('booking_date', ascending: true);

    return {
      'appointments': response,
    };
  }

  Future<Map<String, dynamic>> _generateTherapistReport(String startDate, String endDate) async {
    print('Generating services report for: $startDate to $endDate'); // Debug print
    
    final response = await supabase
        .from('appointment')
        .select('''
          *,
          service:service_id (
            service_name,
            service_price
          )
        ''')
        .eq('spa_id', widget.spaId)
        .eq('status', 'Completed')
        .gte('booking_date', startDate)
        .lte('booking_date', endDate);

    print('Services report response: $response'); // Debug print
    
    return {
      'appointments': response,
    };
  }

  Future<Map<String, dynamic>> _generateCommissionReport(String startDate, String endDate) async {
    // Similar to therapist report but focused on commission calculations
    final response = await supabase
        .from('appointment')
        .select('''
          *,
          therapist:therapist_id (
            first_name, 
            last_name,
            commission_percentage
          ),
          service:service_id (
            service_name,
            service_price
          )
        ''')
        .eq('spa_id', widget.spaId)
        .eq('status', 'Completed')
        .gte('booking_date', startDate)
        .lte('booking_date', endDate);

    // Calculate commissions
    final commissionStats = _processCommissionStats(response);

    return {
      'appointments': response,
      'commissionStats': commissionStats,
    };
  }

  // Helper methods for data processing
  Map<String, dynamic> _processDailyAppointmentStats(List<Map<String, dynamic>> appointments) {
    final stats = <String, dynamic>{
      'totalAppointments': appointments.length,
      'dailyCount': <String, int>{},
      'totalRevenue': 0.0,
    };

    for (var appointment in appointments) {
      final date = DateTime.parse(appointment['booking_date']).toString().split(' ')[0];
      stats['dailyCount'][date] = (stats['dailyCount'][date] ?? 0) + 1;
      stats['totalRevenue'] += (appointment['service']?['service_price'] ?? 0.0);
    }

    return stats;
  }

  Map<String, dynamic> _processAppointmentStatusStats(List<Map<String, dynamic>> appointments) {
    final stats = <String, dynamic>{
      'totalAppointments': appointments.length,
      'statusCount': <String, int>{},
    };

    for (var appointment in appointments) {
      final status = appointment['status'] as String;
      stats['statusCount'][status] = (stats['statusCount'][status] ?? 0) + 1;
    }

    return stats;
  }

  Map<String, dynamic> _processTherapistStats(List<Map<String, dynamic>> appointments) {
    final stats = <String, dynamic>{
      'totalAppointments': appointments.length,
      'therapistStats': <String, dynamic>{},
    };

    for (var appointment in appointments) {
      final therapist = appointment['therapist'];
      final therapistId = appointment['therapist_id'];
      final servicePrice = appointment['service']?['service_price'] ?? 0.0;

      if (!stats['therapistStats'].containsKey(therapistId)) {
        stats['therapistStats'][therapistId] = {
          'name': '${therapist['first_name']} ${therapist['last_name']}',
          'appointmentCount': 0,
          'totalRevenue': 0.0,
        };
      }

      stats['therapistStats'][therapistId]['appointmentCount']++;
      stats['therapistStats'][therapistId]['totalRevenue'] += servicePrice;
    }

    return stats;
  }

  Map<String, dynamic> _processCommissionStats(List<Map<String, dynamic>> appointments) {
    final stats = <String, dynamic>{
      'totalAppointments': appointments.length,
      'commissionStats': <String, dynamic>{},
      'totalCommissions': 0.0,
    };

    for (var appointment in appointments) {
      final therapist = appointment['therapist'];
      final therapistId = appointment['therapist_id'];
      final servicePrice = appointment['service']?['service_price'] ?? 0.0;
      final commissionPercentage = therapist['commission_percentage'] ?? 0.0;
      final commission = (servicePrice * commissionPercentage) / 100;

      if (!stats['commissionStats'].containsKey(therapistId)) {
        stats['commissionStats'][therapistId] = {
          'name': '${therapist['first_name']} ${therapist['last_name']}',
          'appointmentCount': 0,
          'totalRevenue': 0.0,
          'totalCommission': 0.0,
          'commissionPercentage': commissionPercentage,
        };
      }

      stats['commissionStats'][therapistId]['appointmentCount']++;
      stats['commissionStats'][therapistId]['totalRevenue'] += servicePrice;
      stats['commissionStats'][therapistId]['totalCommission'] += commission;
      stats['totalCommissions'] += commission;
    }

    return stats;
  }

  String _getReportTitle(String type) {
    switch (type) {
      case 'sales':
        return 'Sales Report';
      case 'services':
        return 'Frequently Availed Services';
      default:
        return 'Unknown Report Type';
    }
  }

  // Update the dialog to include new filters
  void _showGenerateReportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Generate Report'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Report Type',
                      ),
                      value: _reportType,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _reportType = newValue;
                          });
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'sales', 
                          child: Text('Sales Report')
                        ),
                        DropdownMenuItem(
                          value: 'services', 
                          child: Text('Frequently Availed Services')
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Date Range', 
                      ),
                      value: _dateRange,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _dateRange = newValue;
                            // Update dates based on selection
                            if (newValue == 'daily') {
                              _startDate = DateTime.now();
                              _endDate = DateTime.now();
                            } else if (newValue == 'weekly') {
                              _startDate = DateTime.now().subtract(const Duration(days: 7));
                              _endDate = DateTime.now();
                            }
                          });
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Start Date',
                            ),
                            readOnly: true,
                            controller: TextEditingController(
                              text: DateFormat('yyyy-MM-dd').format(_startDate),
                            ),
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null && picked != _startDate) {
                                setState(() {
                                  _startDate = picked;
                                  _dateRange = 'custom';
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'End Date',
                            ),
                            readOnly: true,
                            controller: TextEditingController(
                              text: DateFormat('yyyy-MM-dd').format(_endDate),
                            ),
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null && picked != _endDate) {
                                setState(() {
                                  _endDate = picked;
                                  _dateRange = 'custom';
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_reportType == 'therapist' || _reportType == 'commission')
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: 'Therapist',
                        ),
                        value: _therapistId,
                        onChanged: (int? newValue) {
                          setState(() {
                            _therapistId = newValue;
                          });
                        },
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Therapists'),
                          ),
                          ..._therapists.map((therapist) => DropdownMenuItem(
                            value: therapist['therapist_id'],
                            child: Text('${therapist['first_name']} ${therapist['last_name']}'),
                          )),
                        ],
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : () {
                    // Update the parent widget's state
                    this.setState(() {
                      // Copy values from dialog state to parent state
                      this._reportType = _reportType;
                      this._dateRange = _dateRange;
                      this._startDate = _startDate;
                      this._endDate = _endDate;
                    });
                    _generateReport();
                  },
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Generate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSalesReport() {
    final totalRevenue = _salesData.fold<double>(
      0, (sum, item) => sum + (item['total_revenue'] as double));
    final totalBookings = _salesData.fold<int>(
      0, (sum, item) => sum + (item['bookings'] as int));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Revenue',
                    '\$${totalRevenue.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Total Bookings',
                    totalBookings.toString(),
                    Icons.calendar_today,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Revenue & Bookings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _salesData.isEmpty
                      ? const Center(child: Text('No data available'))
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: _salesData.fold<double>(
                              0,
                              (max, item) => 
                                item['total_revenue'] > max ? item['total_revenue'] : max
                            ) * 1.2,
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value >= 0 && value < _salesData.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          _salesData[value.toInt()]['date'].toString().substring(5),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '\$${value.toInt()}',
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                  reservedSize: 40,
                                ),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: false,
                                ),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: false,
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: FlGridData(show: false),
                            barGroups: List.generate(
                              _salesData.length,
                              (index) => BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: _salesData[index]['total_revenue'],
                                    color: Colors.blue,
                                    width: 16,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Revenue'), numeric: true),
                      DataColumn(label: Text('Bookings'), numeric: true),
                    ],
                    rows: _salesData.map((item) {
                      return DataRow(cells: [
                        DataCell(Text(item['date'])),
                        DataCell(Text('\$${item['total_revenue'].toStringAsFixed(2)}')),
                        DataCell(Text('${item['bookings']}')),
                      ]);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesReport() {
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service Distribution',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _servicesData.isEmpty
                      ? const Center(child: Text('No data available'))
                      : PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: List.generate(_servicesData.length, (index) {
                              return PieChartSectionData(
                                color: colors[index % colors.length],
                                value: _servicesData[index]['percentage'].toDouble(),
                                title: '${_servicesData[index]['percentage']}%',
                                radius: 60,
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_servicesData.length, (index) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          color: colors[index % colors.length],
                        ),
                        const SizedBox(width: 4),
                        Text(_servicesData[index]['service_name'], style: const TextStyle(fontSize: 12)),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Service')),
                      DataColumn(label: Text('Count'), numeric: true),
                      DataColumn(label: Text('Percentage'), numeric: true),
                    ],
                    rows: _servicesData.map((item) {
                      return DataRow(cells: [
                        DataCell(Text(item['service_name'])),
                        DataCell(Text('${item['count']}')),
                        DataCell(Text('${item['percentage']}%')),
                      ]);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Reports'),
      ),
      body: _isLoading && _reports.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _reports.isEmpty
              ? Center(child: Text('Error: $_error'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Reports',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showGenerateReportDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Generate Report'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _reports.isEmpty && _currentReport == null
                          ? Card(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No reports available.',
                                      style: TextStyle(fontSize: 18, color: Colors.grey),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _showGenerateReportDialog,
                                      child: const Text('Generate Your First Report'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Reports list
                                  Expanded(
                                    flex: 1,
                                    child: Card(
                                      child: ListView.separated(
                                        itemCount: _reports.length,
                                        separatorBuilder: (context, index) => const Divider(),
                                        itemBuilder: (context, index) {
                                          final report = _reports[index];
                                          return ListTile(
                                            leading: Icon(
                                              report['type'] == 'appointment' 
                                                  ? Icons.bar_chart
                                                  : (report['type'] == 'therapist' ? Icons.person : Icons.monetization_on),
                                              color: Theme.of(context).primaryColor,
                                            ),
                                            title: Text(report['title']),
                                            subtitle: Text(
                                              '${report['date_range']}\nBooking Date: ${report['booking_date']}',
                                            ),
                                            isThreeLine: true,
                                            selected: _currentReport != null &&
                                                _currentReport!['id'] == report['id'],
                                            onTap: () => _viewReport(report),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Report display
                                  if (_currentReport != null)
                                    Expanded(
                                      flex: 2,
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _currentReport!['title'],
                                              style: const TextStyle(
                                                fontSize: 18, 
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'Date Range: ${_currentReport!['date_range']}',
                                              style: const TextStyle(color: Colors.grey),
                                            ),
                                            const SizedBox(height: 16),
                                            _currentReport!['type'] == 'sales'
                                                ? _buildSalesReport()
                                                : _buildServicesReport(),
                                          ],
                                        ),
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