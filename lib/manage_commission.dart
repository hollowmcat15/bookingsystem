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

class _ManageCommissionState extends State<ManageCommission> with SingleTickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  late TabController _tabController;
  final _pageController = PageController();
  List<Map<String, dynamic>> therapists = [];
  List<Map<String, dynamic>> receptionists = [];
  Map<int, List<Map<String, dynamic>>> therapistAppointments = {};
  Map<int, double> therapistCommissions = {};
  Map<int, List<Map<String, dynamic>>> receptionistAppointments = {};
  Map<int, double> receptionistCommissions = {};
  bool _isLoading = true;
  String? _error;
  int _currentTab = 0;
  
  // Selected date range for filtering
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Initialize TabController with 2 tabs
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentTab = _tabController.index;
          _pageController.jumpToPage(_currentTab);
        });
      }
    });
    _fetchStaff();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchStaff() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch therapists who work at this spa
      final therapistsResponse = await supabase
          .from('therapist')
          .select('*')
          .eq('spa_id', widget.spaId);

      if (therapistsResponse != null) {
        setState(() {
          therapists = List<Map<String, dynamic>>.from(therapistsResponse);
        });
        
        // Fetch appointments for each therapist
        for (var therapist in therapists) {
          await _fetchTherapistAppointments(therapist['therapist_id']);
          _calculateCommission(therapist['therapist_id']);
        }
      }

      // Fetch receptionists who work at this spa
      final receptionistsResponse = await supabase
          .from('receptionist')
          .select('*')
          .eq('spa_id', widget.spaId);

      if (receptionistsResponse != null) {
        setState(() {
          receptionists = List<Map<String, dynamic>>.from(receptionistsResponse);
        });
        
        // Fetch appointments for each receptionist
        for (var receptionist in receptionists) {
          await _fetchReceptionistAppointments(receptionist['receptionist_id']);
          _calculateReceptionistCommission(receptionist['receptionist_id']);
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

  Future<void> _fetchTherapistAppointments(int therapistId) async {
    try {
      final formattedStartDate = DateFormat('yyyy-MM-dd').format(_startDate);
      final formattedEndDate = DateFormat('yyyy-MM-dd').format(_endDate.add(const Duration(days: 1)));
      
      final response = await supabase
          .from('appointment')
          .select('*, service(*)')
          .eq('therapist_id', therapistId)
          .eq('status', 'Completed')
          .gte('booking_date', formattedStartDate)
          .lt('booking_date', formattedEndDate);

      if (response != null) {
        setState(() {
          therapistAppointments[therapistId] = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('Error fetching appointments for therapist $therapistId: $e');
    }
  }

  Future<void> _fetchReceptionistAppointments(int receptionistId) async {
    try {
      final formattedStartDate = DateFormat('yyyy-MM-dd').format(_startDate);
      final formattedEndDate = DateFormat('yyyy-MM-dd').format(_endDate.add(const Duration(days: 1)));
      
      print('Fetching appointments for receptionist $receptionistId from $formattedStartDate to $formattedEndDate');
      
      final response = await supabase
          .from('appointment')
          .select('*, service(*)')
          .eq('receptionist_id', receptionistId)
          .eq('status', 'Completed')  // Only completed appointments count
          .gte('booking_date', formattedStartDate)
          .lt('booking_date', formattedEndDate);

      if (response != null) {
        print('Found ${response.length} appointments for receptionist $receptionistId');
        setState(() {
          receptionistAppointments[receptionistId] = List<Map<String, dynamic>>.from(response);
        });
      } else {
        print('No appointments found for receptionist $receptionistId');
        setState(() {
          receptionistAppointments[receptionistId] = [];
        });
      }
      
      // Calculate commission after fetching appointments
      _calculateReceptionistCommission(receptionistId);
      
    } catch (e) {
      print('Error fetching appointments for receptionist $receptionistId: $e');
      setState(() {
        receptionistAppointments[receptionistId] = [];
      });
    }
  }

  void _calculateCommission(int therapistId) {
    double totalCommission = 0;
    
    // Find the therapist to get their commission rate
    final therapist = therapists.firstWhere(
      (t) => t['therapist_id'] == therapistId,
      orElse: () => {'commission_percentage': 30.0},
    );
    
    // Get the commission rate from the database or use default
    final commissionRate = (therapist['commission_percentage'] as num?)?.toDouble() ?? 30.0;
    final rateDecimal = commissionRate / 100; // Convert from percentage to decimal
    
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

  void _calculateReceptionistCommission(int receptionistId) {
    double totalCommission = 0.0;
    
    try {
      final receptionist = receptionists.firstWhere(
        (r) => r['receptionist_id'] == receptionistId,
        orElse: () => {'commission_percentage': 0.0},
      );
      
      final commissionRate = (receptionist['commission_percentage'] as num?)?.toDouble() ?? 0.0;
      print('Receptionist commission rate: $commissionRate%');
      
      final rateDecimal = commissionRate / 100;
      
      if (receptionistAppointments.containsKey(receptionistId)) {
        final appointments = receptionistAppointments[receptionistId]!;
        
        for (var appointment in appointments) {
          // Handle different types of service price safely
          var servicePrice = 0.0;
          if (appointment['service'] != null && appointment['service']['service_price'] != null) {
            final rawPrice = appointment['service']['service_price'];
            servicePrice = rawPrice is double ? rawPrice : 
                         rawPrice is int ? rawPrice.toDouble() : 
                         double.tryParse(rawPrice.toString()) ?? 0.0;
          }
          
          final appointmentCommission = servicePrice * rateDecimal;
          totalCommission += appointmentCommission;
          
          print('Appointment ID: ${appointment['book_id']}, Service: ${appointment['service']['service_name']}, ' +
                'Price: \$${servicePrice.toStringAsFixed(2)}, Commission: \$${appointmentCommission.toStringAsFixed(2)}');
        }
      }
      
      print('Total commission for receptionist $receptionistId: \$${totalCommission.toStringAsFixed(2)}');
      
      setState(() {
        receptionistCommissions[receptionistId] = totalCommission;
      });
    } catch (e) {
      print('Error calculating commission: $e');
      setState(() {
        receptionistCommissions[receptionistId] = 0.0;
      });
    }
  }

  Future<void> _updateCommissionRate(bool isTherapist, int staffId, double newRate) async {
    try {
      final table = isTherapist ? 'therapist' : 'receptionist';
      final idField = isTherapist ? 'therapist_id' : 'receptionist_id';
      
      await supabase
          .from(table)
          .update({'commission_percentage': newRate})
          .eq(idField, staffId);
      
      // Refresh data after update
      await _fetchStaff();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commission rate updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update commission rate: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        await _fetchTherapistAppointments(therapist['therapist_id']);
        _calculateCommission(therapist['therapist_id']);
      }
      
      for (var receptionist in receptionists) {
        await _fetchReceptionistAppointments(receptionist['receptionist_id']);
        _calculateReceptionistCommission(receptionist['receptionist_id']);
      }
    }
  }

  void _showTherapistDetails(BuildContext context, Map<String, dynamic> therapist) {
    final int therapistId = therapist['therapist_id'];
    final List<Map<String, dynamic>> appointments = therapistAppointments[therapistId] ?? [];
    final double commission = therapistCommissions[therapistId] ?? 0;
    final commissionRate = (therapist['commission_percentage'] as num?)?.toDouble() ?? 30.0;
    final commissionRateController = TextEditingController(text: commissionRate.toString());
    
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commissionRateController,
                        decoration: InputDecoration(
                          labelText: 'Commission Rate (%)',
                          border: OutlineInputBorder(),
                          suffixText: '%',
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      child: Text('Update Rate'),
                      onPressed: () {
                        // Parse and validate the new commission rate
                        final newRate = double.tryParse(commissionRateController.text);
                        if (newRate != null && newRate >= 0 && newRate <= 100) {
                          _updateCommissionRate(true, therapistId, newRate);
                          Navigator.of(context).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please enter a valid commission rate between 0 and 100'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
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
                            final appointmentCommission = servicePrice * (commissionRate / 100);
                            
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
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('\$${servicePrice.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text('Commission: \$${appointmentCommission.toStringAsFixed(2)}', style: TextStyle(color: Colors.green)),
                                  ],
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ),
                Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Services: ${appointments.length}', style: TextStyle(fontSize: 16)),
                          Text(
                            'Total Commission: \$${commission.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        child: Text('Recalculate'),
                        onPressed: () {
                          _calculateCommission(therapistId);
                          Navigator.of(context).pop();
                          _showTherapistDetails(context, therapist);
                        },
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

  void _showReceptionistDetails(BuildContext context, Map<String, dynamic> receptionist) {
    final int receptionistId = receptionist['receptionist_id'];
    final appointments = receptionistAppointments[receptionistId] ?? [];
    final commission = receptionistCommissions[receptionistId] ?? 0;
    final commissionRate = (receptionist['commission_percentage'] as num?)?.toDouble() ?? 0.0;
    final commissionRateController = TextEditingController(text: commissionRate.toString());
    
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
                      'Receptionist Details',
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
                      backgroundColor: Colors.green.shade100,
                      child: Text(
                        '${receptionist['first_name']?[0] ?? ''}${receptionist['last_name']?[0] ?? ''}',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${receptionist['first_name'] ?? ''} ${receptionist['last_name'] ?? ''}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Email: ${receptionist['email'] ?? 'N/A'}',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Shift: ${receptionist['shift'] ?? 'N/A'}',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Text(
                  'Commission Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commissionRateController,
                        decoration: InputDecoration(
                          labelText: 'Commission Rate (%)',
                          border: OutlineInputBorder(),
                          suffixText: '%',
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      child: Text('Update Rate'),
                      onPressed: () {
                        // Parse and validate the new commission rate
                        final newRate = double.tryParse(commissionRateController.text);
                        if (newRate != null && newRate >= 0 && newRate <= 100) {
                          _updateCommissionRate(false, receptionistId, newRate);
                          Navigator.of(context).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please enter a valid commission rate between 0 and 100'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Note: Receptionists receive commission based on their fixed percentage. Commission calculation for receptionists is based on all bookings they process.',
                  style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                ),
                Expanded(
                  child: appointments.isEmpty
                      ? Center(child: Text('No completed services in selected date range'))
                      : ListView.builder(
                          itemCount: appointments.length,
                          itemBuilder: (context, index) {
                            final appointment = appointments[index];
                            final servicePrice = appointment['service']['service_price'] is num ? 
                                (appointment['service']['service_price'] as num).toDouble() : 0.0;
                            final appointmentCommission = servicePrice * (commissionRate / 100);
                            
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                title: Text(appointment['service']['service_name'] ?? 'Unknown Service'),
                                subtitle: Text(DateFormat('MMM dd, yyyy').format(DateTime.parse(appointment['booking_date']))),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('\$${servicePrice.toStringAsFixed(2)}'),
                                    Text('Commission: \$${appointmentCommission.toStringAsFixed(2)}', 
                                         style: TextStyle(color: Colors.green)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Commission: \$${commission.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      ElevatedButton(
                        child: Text('Recalculate'),
                        onPressed: () {
                          _calculateReceptionistCommission(receptionistId);
                          Navigator.of(context).pop();
                          _showReceptionistDetails(context, receptionist);
                        },
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
                      final therapistId = therapist['therapist_id'];
                      final appointmentsCount = therapistAppointments[therapistId]?.length ?? 0;
                      final commission = therapistCommissions[therapistId] ?? 0;
                      final status = therapist['status'] ?? 'Unknown';
                      final commissionRate = (therapist['commission_percentage'] as num?)?.toDouble() ?? 30.0;
                      
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$${commission.toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                    Text(
                                      '${commissionRate.toStringAsFixed(1)}% rate',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 12),
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

  Widget _buildReceptionistsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Receptionist Commission',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (receptionists.isEmpty)
            Expanded(
              child: Center(child: Text('No receptionists found for this spa')),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: receptionists.length,
                itemBuilder: (context, index) {
                  final receptionist = receptionists[index];
                  final receptionistId = receptionist['receptionist_id'];
                  final appointmentsCount = receptionistAppointments[receptionistId]?.length ?? 0;
                  final commission = receptionistCommissions[receptionistId] ?? 0;
                  final commissionRate = (receptionist['commission_percentage'] as num?)?.toDouble() ?? 0.0;
                  
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      onTap: () => _showReceptionistDetails(context, receptionist),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.green.shade100,
                              child: Text(
                                '${receptionist['first_name']?[0] ?? ''}${receptionist['last_name']?[0] ?? ''}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${receptionist['first_name'] ?? ''} ${receptionist['last_name'] ?? ''}',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                  ),
                                  SizedBox(height: 4),
                                  Text('Shift: ${receptionist['shift'] ?? 'N/A'}'),
                                  Text('Bookings: $appointmentsCount'),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${commission.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.bold,
                                    color: commission > 0 ? Colors.green : Colors.grey
                                  ),
                                ),
                                Text(
                                  '${commissionRate.toStringAsFixed(1)}% rate',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            SizedBox(width: 12),
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
        title: Text('Manage Commissions'),
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
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Therapists', icon: Icon(Icons.spa)),
            Tab(text: 'Receptionists', icon: Icon(Icons.person)),
          ],
        ),
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
            : PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentTab = index;
                    _tabController.animateTo(index);
                  });
                },
                children: [
                  _buildTherapistsTab(),
                  _buildReceptionistsTab(),
                ],
              ),
    );
  }
}