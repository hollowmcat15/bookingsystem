import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TherapistReportsPage extends StatefulWidget {
  @override
  _TherapistReportsPageState createState() => _TherapistReportsPageState();
}

class _TherapistReportsPageState extends State<TherapistReportsPage> {
  final supabase = Supabase.instance.client;
  String selectedReport = 'Sales Report';
  DateTimeRange? selectedDateRange;

  int totalBookings = 0;
  double totalRevenue = 0.0;
  List<Map<String, dynamic>> topServices = [];

  bool isLoading = true;
  bool hasData = true;

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    setState(() {
      isLoading = true;
      hasData = true;
    });

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        isLoading = false;
        hasData = false;
      });
      return;
    }

    // First, we need to get the therapist_id from the auth_id
    final therapistResponse = await supabase
        .from('therapist')
        .select('therapist_id')
        .eq('auth_id', userId)
        .single();
    
    if (therapistResponse == null) {
      setState(() {
        isLoading = false;
        hasData = false;
      });
      return;
    }
    
    final therapistId = therapistResponse['therapist_id'];
    
    DateTime start = selectedDateRange?.start ?? DateTime.now().subtract(Duration(days: 7));
    DateTime end = selectedDateRange?.end ?? DateTime.now();
    
    // Format dates for database query
    final startDate = DateFormat('yyyy-MM-dd').format(start);
    final endDate = DateFormat('yyyy-MM-dd').format(end.add(Duration(days: 1)));

    try {
      if (selectedReport == 'Sales Report') {
        final response = await supabase
            .from('appointment')
            .select('''
              book_id,
              booking_date,
              status,
              service:service_id (
                service_name,
                service_price
              )
            ''')
            .eq('therapist_id', therapistId)
            .eq('status', 'Completed')
            .gte('booking_date', startDate)
            .lte('booking_date', endDate);

        final data = response as List<dynamic>;

        if (data.isEmpty) {
          setState(() {
            isLoading = false;
            hasData = false;
          });
          return;
        }

        totalBookings = data.length;
        totalRevenue = data.fold(0.0, (sum, item) => 
          sum + (double.tryParse(item['service']['service_price'].toString()) ?? 0.0));

        setState(() {
          isLoading = false;
          hasData = true;
        });
      } else if (selectedReport == 'Frequently Availed Services') {
        final response = await supabase
            .from('appointment')
            .select('''
              service_id,
              service:service_id (
                service_name
              )
            ''')
            .eq('therapist_id', therapistId)
            .eq('status', 'Completed')
            .gte('booking_date', startDate)
            .lte('booking_date', endDate);

        final data = response as List<dynamic>;

        if (data.isEmpty) {
          setState(() {
            isLoading = false;
            hasData = false;
            topServices = [];
          });
          return;
        }

        final Map<int, int> serviceCount = {};
        final Map<int, String> serviceNames = {};

        for (var item in data) {
          final id = item['service_id'];
          final name = item['service']['service_name'] ?? 'Unknown';
          serviceCount[id] = (serviceCount[id] ?? 0) + 1;
          serviceNames[id] = name;
        }

        final sorted = serviceCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        topServices = sorted
            .map((entry) => {
                  'service_name': serviceNames[entry.key],
                  'count': entry.value,
                })
            .toList();

        setState(() {
          isLoading = false;
          hasData = true;
        });
      }
    } catch (e) {
      print('Error fetching report data: $e');
      setState(() {
        isLoading = false;
        hasData = false;
      });
    }
  }

  void _selectDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDateRange = picked;
      });
      _fetchReportData();
    }
  }

  Widget _buildReportContent() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (!hasData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No reports available for the selected date range',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (selectedReport == 'Sales Report') {
      return Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.calendar_today, size: 40, color: Colors.blue),
                        SizedBox(height: 8),
                        Text(
                          '$totalBookings',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text('Total Bookings'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.attach_money, size: 40, color: Colors.green),
                        SizedBox(height: 8),
                        Text(
                          '₱${totalRevenue.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text('Total Revenue'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (selectedReport == 'Frequently Availed Services') {
      return ListView.builder(
        itemCount: topServices.length,
        itemBuilder: (context, index) {
          final service = topServices[index];
          return Card(
            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              leading: CircleAvatar(
                child: Text('${index + 1}'),
                backgroundColor: index == 0 ? Colors.amber : 
                                index == 1 ? Colors.grey : 
                                index == 2 ? Colors.brown : Colors.blue,
              ),
              title: Text(service['service_name'] ?? 'Unknown'),
              trailing: Text('${service['count']} bookings'),
            ),
          );
        }
      );
    }

    return SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    final dateText = selectedDateRange == null
        ? 'Last 7 days'
        : '${DateFormat.yMMMd().format(selectedDateRange!.start)} - ${DateFormat.yMMMd().format(selectedDateRange!.end)}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Therapist Reports'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButton<String>(
                      value: selectedReport,
                      isExpanded: true,
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedReport = newValue!;
                        });
                        _fetchReportData();
                      },
                      items: <String>['Sales Report', 'Frequently Availed Services']
                          .map<DropdownMenuItem<String>>((String value) =>
                              DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Text('Date Range: $dateText'),
                        Spacer(),
                        ElevatedButton.icon(
                          onPressed: _selectDateRange,
                          icon: Icon(Icons.date_range),
                          label: Text('Select Date'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(child: _buildReportContent()),
          ],
        ),
      ),
    );
  }
}