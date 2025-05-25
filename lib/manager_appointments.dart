import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerAppointmentsPage extends StatefulWidget {
  final int managerId;
  final int spaId;

  const ManagerAppointmentsPage({
    Key? key,
    required this.managerId,
    required this.spaId,
  }) : super(key: key);

  @override
  _ManagerAppointmentsPageState createState() => _ManagerAppointmentsPageState();
}

class _ManagerAppointmentsPageState extends State<ManagerAppointmentsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _filteredAppointments = [];
  List<Map<String, dynamic>> _therapists = [];
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;
  String _filterStatus = 'All';
  DateTime? _filterDate;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load appointments with correct joins
      final appointmentsResponse = await _supabase
          .from('appointment')
          .select('''
            *,
            client:client_id(client_id, first_name, last_name, email, phonenumber),
            service:service_id(service_id, service_name, service_price),
            staff!therapist_id(staff_id, first_name, last_name)
          ''')
          .eq('spa_id', widget.spaId)
          .order('booking_date', ascending: false)  // newest first
          .order('booking_start_time', ascending: false);  // if same date, show latest time first

      // Load therapists from staff table
      final therapistsResponse = await _supabase
          .from('staff')
          .select('staff_id, first_name, last_name')
          .eq('spa_id', widget.spaId)
          .eq('role', 'Therapist')
          .eq('is_active', true);

      // Load services for this spa
      final servicesResponse = await _supabase
          .from('service')
          .select('*')
          .eq('spa_id', widget.spaId);

      setState(() {
        _appointments = List<Map<String, dynamic>>.from(appointmentsResponse);
        _filteredAppointments = _appointments;
        _therapists = List<Map<String, dynamic>>.from(therapistsResponse);
        _services = List<Map<String, dynamic>>.from(servicesResponse);
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredAppointments = _appointments.where((appointment) {
        // Filter by status
        if (_filterStatus != 'All' && appointment['status'] != _filterStatus) {
          return false;
        }

        // Filter by date
        if (_filterDate != null) {
          final bookingDate = DateTime.parse(appointment['booking_date']);
          if (bookingDate.year != _filterDate!.year ||
              bookingDate.month != _filterDate!.month ||
              bookingDate.day != _filterDate!.day) {
            return false;
          }
        }

        // Search by client name or appointment ID
        if (_searchController.text.isNotEmpty) {
          final searchQuery = _searchController.text.toLowerCase();
          final client = appointment['client'] ?? {};
          final clientFirstName = client['first_name']?.toString().toLowerCase() ?? '';
          final clientLastName = client['last_name']?.toString().toLowerCase() ?? '';
          final bookingId = appointment['book_id']?.toString() ?? '';

          return clientFirstName.contains(searchQuery) ||
              clientLastName.contains(searchQuery) ||
              bookingId.contains(searchQuery);
        }

        return true;
      }).toList();
    });
  }

  Future<void> _updateAppointmentStatus(int bookId, String newStatus) async {
    try {
      await _supabase.from('appointment').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String().split('T')[0],
      }).eq('book_id', bookId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appointment status updated to $newStatus')),
      );

      // Refresh appointments
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating appointment: $e')),
      );
    }
  }

  void _showAppointmentDetails(Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (context) => AppointmentDetailsDialog(
        appointment: appointment,
        therapists: _therapists,
        services: _services,
        onUpdate: _loadData,
        supabase: _supabase,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter Appointments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search by client name or booking ID',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => _applyFilters(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _filterStatus,
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Status')),
                              DropdownMenuItem(value: 'Scheduled', child: Text('Scheduled')),
                              DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                              DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                              DropdownMenuItem(value: 'Rescheduled', child: Text('Rescheduled')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _filterStatus = value!;
                                _applyFilters();
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today),
                              label: Text(_filterDate == null
                                  ? 'Filter by Date'
                                  : DateFormat('MMM dd, yyyy').format(_filterDate!)),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _filterDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _filterDate = picked;
                                    _applyFilters();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _filterDate = null;
                                _filterStatus = 'All';
                                _searchController.clear();
                                _filteredAppointments = _appointments;
                              });
                            },
                            child: const Text('Clear Filters'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredAppointments.isEmpty
                      ? const Center(child: Text('No appointments found'))
                      : ListView.builder(
                          itemCount: _filteredAppointments.length,
                          itemBuilder: (context, index) {
                            final appointment = _filteredAppointments[index];
                            final client = appointment['client'] ?? {};
                            final service = appointment['service'] ?? {};
                            final therapist = appointment['staff'] ?? {}; // Changed from 'therapist' to 'staff'
                            final bookingDate = DateTime.parse(appointment['booking_date']);
                            final startTime = appointment['booking_start_time'];
                            final status = appointment['status'];

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                title: Text(
                                  '${client['first_name'] ?? 'Unknown'} ${client['last_name'] ?? ''} - ${service['service_name'] ?? 'Unknown Service'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${DateFormat('MMM dd, yyyy').format(bookingDate)} at $startTime',
                                    ),
                                    Text(
                                      'Therapist: ${therapist['first_name'] ?? 'Unknown'} ${therapist['last_name'] ?? ''}',
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        status,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _showAppointmentDetails(appointment),
                                    ),
                                    if (status == 'Scheduled')
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          _updateAppointmentStatus(appointment['book_id'], value);
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'Completed',
                                            child: Text('Mark as Completed'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'Cancelled',
                                            child: Text('Cancel Appointment'),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                onTap: () => _showAppointmentDetails(appointment),
                              ),
                            );
                          }),
                ),
              ],
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

class AppointmentDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final List<Map<String, dynamic>> therapists;
  final List<Map<String, dynamic>> services;
  final Function onUpdate;
  final SupabaseClient supabase;

  const AppointmentDetailsDialog({
    Key? key,
    required this.appointment,
    required this.therapists,
    required this.services,
    required this.onUpdate,
    required this.supabase,
  }) : super(key: key);

  @override
  _AppointmentDetailsDialogState createState() => _AppointmentDetailsDialogState();
}

class _AppointmentDetailsDialogState extends State<AppointmentDetailsDialog> {
  late int? _selectedTherapistId;
  late int? _selectedServiceId;
  late String _selectedStatus;
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isUpdating = false;
  TimeOfDay? spaOpeningTime;
  TimeOfDay? spaClosingTime;

  @override
  void initState() {
    super.initState();
    // Fix therapist_id mapping
    _selectedTherapistId = widget.appointment['therapist_id']; // Changed from staff_id to therapist_id
    _selectedServiceId = widget.appointment['service_id'];
    _selectedStatus = widget.appointment['status'];
    _selectedDate = DateTime.parse(widget.appointment['booking_date']);
    
    // Parse time strings with null safety
    try {
      final startTimeParts = widget.appointment['booking_start_time']?.split(':');
      _startTime = startTimeParts != null ? TimeOfDay(
        hour: int.parse(startTimeParts[0]),
        minute: int.parse(startTimeParts[1]),
      ) : TimeOfDay.now();
      
      final endTimeParts = widget.appointment['booking_end_time']?.split(':');
      _endTime = endTimeParts != null ? TimeOfDay(
        hour: int.parse(endTimeParts[0]),
        minute: int.parse(endTimeParts[1]),
      ) : TimeOfDay.now();
    } catch (e) {
      _startTime = TimeOfDay.now();
      _endTime = TimeOfDay.now();
    }

    _fetchSpaHours();
  }

  Future<void> _fetchSpaHours() async {
    try {
      final response = await widget.supabase
          .from('spa')
          .select('opening_time, closing_time')
          .eq('spa_id', widget.appointment['spa_id'])
          .single();

      if (response != null) {
        setState(() {
          final openingTimeParts = response['opening_time'].split(':');
          final closingTimeParts = response['closing_time'].split('');
          
          spaOpeningTime = TimeOfDay(
            hour: int.parse(openingTimeParts[0]),
            minute: int.parse(openingTimeParts[1])
          );
          
          spaClosingTime = TimeOfDay(
            hour: int.parse(closingTimeParts[0]),
            minute: int.parse(closingTimeParts[1])
          );
        });
      }
    } catch (e) {
      print("Error fetching spa hours: $e");
    }
  }

  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  bool _validateSpaHours(TimeOfDay time) {
    if (spaOpeningTime == null || spaClosingTime == null) return true;

    int timeInMinutes = _timeToMinutes(time);
    int openingInMinutes = _timeToMinutes(spaOpeningTime!);
    int closingInMinutes = _timeToMinutes(spaClosingTime!);

    if (closingInMinutes < openingInMinutes) {
      closingInMinutes += 24 * 60;
      if (timeInMinutes < openingInMinutes) {
        timeInMinutes += 24 * 60;
      }
    }

    return timeInMinutes >= openingInMinutes && timeInMinutes <= closingInMinutes;
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final now = TimeOfDay.now();
    final isToday = _selectedDate.year == DateTime.now().year &&
                    _selectedDate.month == DateTime.now().month &&
                    _selectedDate.day == DateTime.now().day;

    // Set minimum time based on current time for today's appointments
    TimeOfDay minimumTime = isToday 
        ? now 
        : spaOpeningTime ?? const TimeOfDay(hour: 9, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              dayPeriodTextColor: Theme.of(context).primaryColor,
              hourMinuteTextColor: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Past time validation
      if (_selectedDate.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot schedule appointments in the past'),
            backgroundColor: Colors.red,
          )
        );
        return;
      }

      if (isToday && _timeToMinutes(picked) < _timeToMinutes(now)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot select a time in the past'),
            backgroundColor: Colors.red,
          )
        );
        return;
      }

      // Spa hours validation
      if (!_validateSpaHours(picked)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Selected time must be within spa operating hours: ' +
              '${spaOpeningTime!.format(context)} - ${spaClosingTime!.format(context)}'
            ),
            backgroundColor: Colors.red,
          )
        );
        return;
      }

      setState(() {
        _startTime = picked;
        // Automatically set end time 1 hour after start time
        _endTime = TimeOfDay(
          hour: (_startTime.hour + 1) % 24,
          minute: _startTime.minute,
        );
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );

    if (picked != null) {
      // Validate against spa hours
      if (!_validateSpaHours(picked)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            'Selected time must be within spa operating hours: ' +
            '${spaOpeningTime!.format(context)} - ${spaClosingTime!.format(context)}'
          ))
        );
        return;
      }

      // Validate end time is after start time
      if (_timeToMinutes(picked) <= _timeToMinutes(_startTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time'))
        );
        return;
      }

      setState(() {
        _endTime = picked;
      });
    }
  }

  // Add this new method to check for conflicts
  Future<bool> _hasAppointmentConflict() async {
    final formattedStartTime = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';
    final formattedEndTime = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00';

    try {
      final response = await widget.supabase
          .from('appointment')
          .select('*, staff!therapist_id(first_name, last_name)') // Updated join
          .eq('booking_date', _selectedDate.toIso8601String().split('T')[0])
          .eq('status', 'Scheduled')
          .neq('book_id', widget.appointment['book_id']) // Exclude current appointment
          .or('and(booking_start_time.lte.${formattedEndTime},booking_end_time.gt.${formattedStartTime}),and(booking_start_time.lt.${formattedEndTime},booking_end_time.gte.${formattedStartTime})');

      if (response.length > 0) {
        final conflictingApp = response[0];
        String conflictMessage = "Cannot reschedule: Time slot conflict\n";
        conflictMessage += "There is already an appointment scheduled from "
            "${TimeOfDay(hour: int.parse(conflictingApp['booking_start_time'].split(':')[0]), minute: int.parse(conflictingApp['booking_start_time'].split(':')[1])).format(context)} to "
            "${TimeOfDay(hour: int.parse(conflictingApp['booking_end_time'].split(':')[0]), minute: int.parse(conflictingApp['booking_end_time'].split(':')[1])).format(context)}";

        if (conflictingApp['therapist'] != null) {
          conflictMessage += "\nTherapist: ${conflictingApp['therapist']['first_name']} ${conflictingApp['therapist']['last_name']}";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(conflictMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return true;
      }
      return false;
    } catch (e) {
      print("Error checking appointment conflicts: $e");
      return false;
    }
  }

  // Modify the _updateAppointment method to include conflict check
  Future<void> _updateAppointment() async {
    if (_isUpdating) return;

    // Validate required fields
    if (_selectedTherapistId == null || _selectedServiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both therapist and service'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate date is not in the past
    if (_isDateInPast(_selectedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot schedule appointments in the past'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if selected times are within spa hours
    if (!_validateSpaHours(_startTime) || !_validateSpaHours(_endTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selected times must be within spa operating hours: ' +
            '${spaOpeningTime!.format(context)} - ${spaClosingTime!.format(context)}'
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check for conflicts before proceeding
    if (await _hasAppointmentConflict()) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      // Format times
      final formattedStartTime = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';
      final formattedEndTime = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00';

      // Confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save changes?'),
          content: const Text('Are you sure you want to save these changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await widget.supabase.from('appointment').update({
          'therapist_id': _selectedTherapistId,
          'service_id': _selectedServiceId,
          'status': _selectedStatus,
          'booking_date': _selectedDate.toIso8601String().split('T')[0],
          'booking_start_time': formattedStartTime,
          'booking_end_time': formattedEndTime,
          'updated_at': DateTime.now().toIso8601String().split('T')[0],
        }).eq('book_id', widget.appointment['book_id']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully.')),
        );

        Navigator.pop(context);
        widget.onUpdate();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating appointment: $e')),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text(
          'Are you sure you want to cancel this appointment? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            child: const Text('No, Keep It'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.supabase.from('appointment').update({
          'status': 'Cancelled',
          'updated_at': DateTime.now().toIso8601String().split('T')[0],
        }).eq('book_id', widget.appointment['book_id']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking successfully canceled.')),
        );

        Navigator.pop(context);
        widget.onUpdate();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error canceling booking: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.appointment['client'] ?? {};
    final servicePrice = widget.services.firstWhere(
      (service) => service['service_id'] == widget.appointment['service_id'],
      orElse: () => {'service_price': 0},
    )['service_price'];

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          width: 500, // Fixed width
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.edit_calendar, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Appointment Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Client Information Card
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Client Information',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Text(
                                '${client['first_name'] ?? 'Unknown'} ${client['last_name'] ?? ''}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text('Email: ${client['email'] ?? 'N/A'}'),
                              Text('Phone: ${client['phonenumber'] ?? 'N/A'}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Appointment Details Section
                      // ...existing form fields code remains the same...

                      // Add some styling to the dropdowns and input decorators
                      Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: InputDecorationTheme(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        child: Column(
                          children: [
                            // Service selection
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: DropdownButtonFormField<int?>(
                                decoration: const InputDecoration(
                                  labelText: 'Service',
                                  prefixIcon: Icon(Icons.spa),
                                ),
                                value: _selectedServiceId,
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Select a service'),
                                  ),
                                  ...widget.services.map((service) {
                                    return DropdownMenuItem<int?>(
                                      value: service['service_id'],
                                      child: Text('${service['service_name']} - ₱${service['service_price']}'),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedServiceId = value;
                                  });
                                },
                              ),
                            ),
                            // Therapist selection
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: DropdownButtonFormField<int?>(
                                decoration: const InputDecoration(
                                  labelText: 'Therapist',
                                  prefixIcon: Icon(Icons.person),
                                ),
                                value: _selectedTherapistId,
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Select a therapist'),
                                  ),
                                  ...widget.therapists.map((therapist) {
                                    return DropdownMenuItem<int?>(
                                      value: therapist['staff_id'], // Changed from therapist_id
                                      child: Text('${therapist['first_name']} ${therapist['last_name']}'),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedTherapistId = value;
                                  });
                                },
                              ),
                            ),
                            // Status selection
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  prefixIcon: Icon(Icons.schedule),
                                ),
                                value: _selectedStatus,
                                items: const [
                                  DropdownMenuItem(value: 'Scheduled', child: Text('Scheduled')),
                                  DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                                  DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                                  DropdownMenuItem(value: 'Rescheduled', child: Text('Rescheduled')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedStatus = value!;
                                  });
                                },
                              ),
                            ),
                            // Date picker
                            Container(
                              margin: const EdgeInsets.only(bottom: 24), // Increased bottom margin
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _selectedDate = picked;
                                    });
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Date',
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(Icons.calendar_today),
                                  ),
                                  child: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                                ),
                              ),
                            ),
                            // Time pickers with section header
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'Appointment Time',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: _startTime,
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _startTime = picked;
                                          // Automatically set end time 1 hour later
                                          _endTime = TimeOfDay(
                                            hour: (_startTime.hour + 1) % 24,
                                            minute: _startTime.minute,
                                          );
                                        });
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Start Time',
                                        border: OutlineInputBorder(),
                                        suffixIcon: Icon(Icons.access_time),
                                      ),
                                      child: Text(_startTime.format(context)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      if (_timeToMinutes(_endTime) <= _timeToMinutes(_startTime)) {
                                        // Set initial time to 1 hour after start time
                                        _endTime = TimeOfDay(
                                          hour: (_startTime.hour + 1) % 24,
                                          minute: _startTime.minute,
                                        );
                                      }

                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: _endTime,
                                      );

                                      if (picked != null) {
                                        // Validate end time is after start time
                                        if (_timeToMinutes(picked) <= _timeToMinutes(_startTime)) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('End time must be after start time')),
                                          );
                                          return;
                                        }
                                        setState(() {
                                          _endTime = picked;
                                        });
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'End Time',
                                        border: OutlineInputBorder(),
                                        suffixIcon: Icon(Icons.access_time),
                                      ),
                                      child: Text(_endTime.format(context)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Service Fee: ₱${servicePrice.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_selectedStatus == 'Scheduled')
                      TextButton.icon(
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel Booking'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _cancelBooking,
                      ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Back'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: _isUpdating 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isUpdating ? 'Saving...' : 'Save Changes'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isUpdating ? null : _updateAppointment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add this helper method to check if a date is in the past
  bool _isDateInPast(DateTime date) {
    final now = DateTime.now();
    return date.isBefore(DateTime(now.year, now.month, now.day));
  }
}