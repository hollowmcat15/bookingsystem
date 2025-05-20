import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TherapistCommission extends StatefulWidget {
  final Map<String, dynamic> therapistData;

  const TherapistCommission({Key? key, required this.therapistData}) : super(key: key);

  @override
  _TherapistCommissionState createState() => _TherapistCommissionState();
}

class _TherapistCommissionState extends State<TherapistCommission> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _commissionData = [];
  double _totalEarnings = 0.0;
  int _completedServices = 0;
  double _commissionRate = 0.3;

  DateTime _startDate = DateTime.now().subtract(Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String _dateRangeText = '';
  String _selectedPeriod = 'Last 7 Days';
  final List<String> _periodOptions = ['Today', 'Last 7 Days', 'This Month', 'Last Month', 'Custom'];

  @override
  void initState() {
    super.initState();
    _setInitialDateRange();
    _loadCommissionData();
  }

  void _setInitialDateRange() {
    _dateRangeText = '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}';
  }

  Future<void> _loadCommissionData() async {
    setState(() => _isLoading = true);

    try {
      final int therapistId = widget.therapistData['therapist_id'];

      final therapistResponse = await supabase
          .from('therapist')
          .select('commission_percentage')
          .eq('therapist_id', therapistId)
          .single();

      // Convert commission percentage from database format (e.g., '15.00') to decimal (0.15)
      final double commissionRate = (therapistResponse['commission_percentage'] is int
          ? (therapistResponse['commission_percentage'] as int).toDouble()
          : therapistResponse['commission_percentage'] ?? 15.00) / 100.0;

      _commissionRate = commissionRate;

      final String formattedStartDate = DateFormat('yyyy-MM-dd').format(_startDate);
      final String formattedEndDate = DateFormat('yyyy-MM-dd').format(_endDate);

      final response = await supabase
          .from('appointment')
          .select('''
            book_id,
            booking_date,
            booking_start_time,
            booking_end_time,
            status,
            service:service_id (
              service_id,
              service_name,
              service_price
            ),
            client:client_id (
              first_name,
              last_name
            )
          ''')
          .eq('therapist_id', therapistId)
          .eq('status', 'Completed')
          .gte('booking_date', formattedStartDate)
          .lte('booking_date', formattedEndDate)
          .order('booking_date', ascending: false);

      final List<Map<String, dynamic>> appointments = List<Map<String, dynamic>>.from(response);

      double total = 0.0;
      final List<Map<String, dynamic>> processedData = [];

      for (final appointment in appointments) {
        final servicePrice = appointment['service']['service_price'] is int
            ? (appointment['service']['service_price'] as int).toDouble()
            : appointment['service']['service_price'] ?? 0.0;

        final double commission = servicePrice * commissionRate;
        total += commission;

        processedData.add({
          'appointment_id': appointment['book_id'],
          'date': appointment['booking_date'],
          'time': appointment['booking_start_time'],
          'service_name': appointment['service']['service_name'],
          'service_price': servicePrice,
          'client_name': '${appointment['client']['first_name']} ${appointment['client']['last_name']}',
          'commission_amount': commission,
          'commission_percentage': '${(commissionRate * 100).toStringAsFixed(0)}%',
        });
      }

      setState(() {
        _commissionData = processedData;
        _totalEarnings = total;
        _completedServices = appointments.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading commission data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateDateRange() {
    final DateTime now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Today':
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = now;
        break;
      case 'Last 7 Days':
        _startDate = now.subtract(Duration(days: 6));
        _endDate = now;
        break;
      case 'This Month':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
        break;
      case 'Last Month':
        final lastMonth = now.month == 1
            ? DateTime(now.year - 1, 12, 1)
            : DateTime(now.year, now.month - 1, 1);
        _startDate = lastMonth;
        _endDate = DateTime(lastMonth.year, lastMonth.month + 1, 0);
        break;
      case 'Custom':
        return;
    }

    _dateRangeText = '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}';
    _loadCommissionData();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _dateRangeText = '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}';
        _selectedPeriod = 'Custom';
      });

      _loadCommissionData();
    }
  }

  Widget _buildServiceEarningsChart() {
    Map<String, double> serviceCommissions = {};
    for (var item in _commissionData) {
      final serviceName = item['service_name'] as String;
      final commission = item['commission_amount'] as double;
      serviceCommissions[serviceName] = (serviceCommissions[serviceName] ?? 0.0) + commission;
    }

    double maxCommission = serviceCommissions.values.fold(0.0, (max, value) => value > max ? value : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text('Service Earnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        ...serviceCommissions.entries.map((entry) {
          final percentage = maxCommission > 0 ? entry.value / maxCommission : 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(flex: 7, child: Text(entry.key, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13))),
                    Expanded(
                      flex: 3,
                      child: Text('\$${entry.value.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Stack(
                  children: [
                    Container(height: 12, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6))),
                    FractionallySizedBox(
                      widthFactor: percentage.toDouble(),
                      child: Container(height: 12, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(6))),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 3,
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
              SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Commissions')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Commission Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Time Period',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              value: _selectedPeriod,
                              items: _periodOptions.map((String period) {
                                return DropdownMenuItem<String>(
                                  value: period,
                                  child: Text(period),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedPeriod = newValue;
                                  });
                                  if (newValue == 'Custom') {
                                    _selectDateRange(context);
                                  } else {
                                    _updateDateRange();
                                  }
                                }
                              },
                            ),
                          ),
                          if (_selectedPeriod == 'Custom')
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: ElevatedButton(
                                onPressed: () => _selectDateRange(context),
                                child: Icon(Icons.calendar_today),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text('Date Range: $_dateRangeText'),
                      SizedBox(height: 4),
                      Text('Commission Rate: ${(_commissionRate * 100).toStringAsFixed(0)}%'),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildStatCard('Earnings', '\$${_totalEarnings.toStringAsFixed(2)}', Colors.green),
                      SizedBox(width: 12),
                      _buildStatCard('Completed', '$_completedServices', Colors.blue),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildServiceEarningsChart(),
                ),

                SizedBox(height: 16),
              ],
            ),
    );
  }
}
