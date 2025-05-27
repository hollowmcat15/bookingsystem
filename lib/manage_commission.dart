import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ManageCommission extends StatefulWidget {
  final int spaId;

  const ManageCommission({
    Key? key,
    required this.spaId,
  }) : super(key: key);

  @override
  _ManageCommissionState createState() => _ManageCommissionState();
}

class _ManageCommissionState extends State<ManageCommission> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> therapists = [];
  Map<int, List<Map<String, dynamic>>> therapistAppointments = {};
  Map<int, double> therapistCommissions = {};
  bool _isLoading = true;
  String? _error;
  
  // Selected date range for filtering
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch only therapists from staff table
      final therapistsResponse = await supabase
          .from('staff')
          .select('*')
          .eq('spa_id', widget.spaId)
          .eq('role', 'Therapist')
          .eq('is_active', true);  // Only get active therapists

      if (therapistsResponse != null) {
        setState(() {
          therapists = List<Map<String, dynamic>>.from(therapistsResponse);
        });
        
        // Fetch appointments for each therapist
        for (var therapist in therapists) {
          await _fetchTherapistAppointments(therapist['staff_id']);
          _calculateCommission(therapist['staff_id']);
        }
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

  Future<void> _fetchTherapistAppointments(int staffId) async {
    try {
      final formattedStartDate = DateFormat('yyyy-MM-dd').format(_startDate);
      final formattedEndDate = DateFormat('yyyy-MM-dd').format(_endDate.add(const Duration(days: 1)));
      
      final response = await supabase
          .from('appointment')
          .select('*, service(*)')
          .eq('therapist_id', staffId)  // Changed from staff_id to therapist_id
          .eq('status', 'Completed')
          .gte('booking_date', formattedStartDate)
          .lt('booking_date', formattedEndDate);

      if (response != null) {
        setState(() {
          therapistAppointments[staffId] = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('Error fetching appointments for therapist $staffId: $e');
    }
  }

  void _calculateCommission(int therapistId) {
    double totalCommission = 0;
    final commissionRate = 25.0; // Fixed at 25%
    final rateDecimal = commissionRate / 100;
    
    if (therapistAppointments.containsKey(therapistId)) {
      for (var appointment in therapistAppointments[therapistId]!) {
        // Calculate commission for this appointment
        final servicePrice = appointment['service']['service_price'] as double? ?? 
            (appointment['service']['service_price'] is int ? 
                (appointment['service']['service_price'] as int).toDouble() : 0.0);
                
        totalCommission += servicePrice * rateDecimal;
      }
    }
    
    setState(() {
      therapistCommissions[therapistId] = totalCommission;
    });
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
      });
      
      // Refetch data with new date range
      for (var therapist in therapists) {
        await _fetchTherapistAppointments(therapist['staff_id']);
        _calculateCommission(therapist['staff_id']);
      }
    }
  }

  void _showTherapistDetails(BuildContext context, Map<String, dynamic> therapist) {
    final int therapistId = therapist['staff_id'];
    final List<Map<String, dynamic>> appointments = therapistAppointments[therapistId] ?? [];
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(maxWidth: 600, maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Therapist Details',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        '${therapist['first_name']?[0] ?? ''}${therapist['last_name']?[0] ?? ''}',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${therapist['first_name'] ?? ''} ${therapist['last_name'] ?? ''}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Email: ${therapist['email'] ?? 'N/A'}',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Divider(height: 32),
                Text(
                  'Completed Services',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Expanded(
                  child: appointments.isEmpty
                      ? Center(child: Text('No completed services in selected date range'))
                      : ListView.builder(
                          itemCount: appointments.length,
                          itemBuilder: (context, index) {
                            final appointment = appointments[index];
                            final servicePrice = appointment['service']['service_price'] as double? ?? 
                                (appointment['service']['service_price'] is int ? 
                                    (appointment['service']['service_price'] as int).toDouble() : 0.0);
                            
                            // Format booking time
                            String bookingTime = '';
                            if (appointment['booking_start_time'] != null && appointment['booking_end_time'] != null) {
                              bookingTime = '${appointment['booking_start_time']} - ${appointment['booking_end_time']}';
                            }
                            
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                title: Text(appointment['service']['service_name'] ?? 'Unknown Service'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(appointment['booking_date']))}'),
                                    if (bookingTime.isNotEmpty) Text('Time: $bookingTime'),
                                    Text('Appointment ID: ${appointment['book_id']}'),
                                  ],
                                ),
                                trailing: Text(
                                  '₱${servicePrice.toStringAsFixed(2)}', 
                                  style: TextStyle(fontWeight: FontWeight.bold)
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
                Divider(),
                // Add commission calculation summary
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Commission Calculation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Service Value:'),
                            Text(
                              '₱${appointments.fold<double>(0, (sum, item) => sum + (item['service']['service_price'] as num).toDouble()).toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Commission Rate:'),
                            Text(
                              '25%',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(  // Changed from Row to Column
                    crossAxisAlignment: CrossAxisAlignment.stretch,  // Make buttons full width
                    children: [
                      Text(
                        'Total Services: ${appointments.length}', 
                        style: TextStyle(fontSize: 16)
                      ),
                      SizedBox(height: 8),  // Add spacing between text and buttons
                      ElevatedButton.icon(
                        icon: Icon(Icons.calculate, color: Colors.white),  // Ensure icon is white
                        label: Text(
                          'Calculate Commission',
                          style: TextStyle(color: Colors.white),  // Ensure text is white
                        ),
                        onPressed: () {
                          final total = appointments.fold<double>(
                            0, 
                            (sum, item) => sum + (item['service']['service_price'] as num).toDouble()
                          );
                          final commission = total * 0.25;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Total Services: ₱${total.toStringAsFixed(2)}\n'
                                'Commission (25%): ₱${commission.toStringAsFixed(2)}'
                              ),
                              duration: Duration(seconds: 5),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,  // Ensure all text/icons are white
                        ),
                      ),
                      SizedBox(height: 8),  // Add spacing between buttons
                      ElevatedButton(
                        child: Text('Close'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTherapistsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Therapist Commission',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: therapists.isEmpty
                ? Center(child: Text('No therapists found for this spa'))
                : ListView.builder(
                    itemCount: therapists.length,
                    itemBuilder: (context, index) {
                      final therapist = therapists[index];
                      final therapistId = therapist['staff_id'];
                      final appointmentsCount = therapistAppointments[therapistId]?.length ?? 0;
                      final status = therapist['status'] ?? 'Unknown';
                      
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () => _showTherapistDetails(context, therapist),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(
                                    '${therapist['first_name']?[0] ?? ''}${therapist['last_name']?[0] ?? ''}',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${therapist['first_name'] ?? ''} ${therapist['last_name'] ?? ''}',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text('Services: $appointmentsCount'),
                                          SizedBox(width: 12),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              'Commission: 25%',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue.shade800,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: status == 'Active' ? Colors.green.shade100 : 
                                                    status == 'Busy' ? Colors.orange.shade100 : Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: status == 'Active' ? Colors.green.shade800 : 
                                                      status == 'Busy' ? Colors.orange.shade800 : Colors.grey.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 16),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Therapist Commissions'),
        actions: [
          IconButton(
            icon: Icon(Icons.date_range),
            onPressed: () => _selectDateRange(context),
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchStaff,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
            : _buildTherapistsTab(),
    );
  }
}