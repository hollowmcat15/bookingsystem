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
      // Load appointments
      final appointmentsResponse = await _supabase
          .from('appointment')
          .select('''
            *,
            client:client_id(client_id, first_name, last_name, email, phonenumber),
            service:service_id(service_id, service_name, service_price),
            therapist:therapist_id(therapist_id, first_name, last_name)
          ''')
          .eq('spa_id', widget.spaId)
          .order('booking_date', ascending: false);

      // Load therapists for this spa
      final therapistsResponse = await _supabase
          .from('therapist')
          .select('*')
          .eq('spa_id', widget.spaId);

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
                            final therapist = appointment['therapist'] ?? {};
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
                          },
                        ),
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

  @override
  void initState() {
    super.initState();
    _selectedTherapistId = widget.appointment['therapist_id'];
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
  }

  // Add this new method to check for conflicts
  Future<bool> _hasAppointmentConflict() async {
    final formattedStartTime = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';
    final formattedEndTime = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00';

    try {
      final response = await widget.supabase
          .from('appointment')
          .select('*, therapist:therapist(first_name, last_name)')
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
        const SnackBar(content: Text('Please select both therapist and service')),
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
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
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

    return AlertDialog(
      title: const Text('Appointment Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Client Information',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${client['first_name'] ?? 'Unknown'} ${client['last_name'] ?? ''}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email: ${client['email'] ?? 'N/A'}'),
                  Text('Phone: ${client['phonenumber'] ?? 'N/A'}'),
                ],
              ),
            ),
            const Divider(),
            const Text(
              'Appointment Details',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // Service selection
            DropdownButtonFormField<int?>(
              decoration: const InputDecoration(
                labelText: 'Service',
                border: OutlineInputBorder(),
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
            const SizedBox(height: 8),
            
            // Therapist selection
            DropdownButtonFormField<int?>(
              decoration: const InputDecoration(
                labelText: 'Therapist',
                border: OutlineInputBorder(),
              ),
              value: _selectedTherapistId,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Select a therapist'),
                ),
                ...widget.therapists.map((therapist) {
                  return DropdownMenuItem<int?>(
                    value: therapist['therapist_id'],
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
            const SizedBox(height: 8),
            
            // Status selection
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
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
            const SizedBox(height: 8),
            
            // Date picker
            InkWell(
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
            const SizedBox(height: 8),
            
            // Time pickers
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
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (picked != null) {
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
      actions: [
        if (_selectedStatus == 'Scheduled')
          TextButton(
            onPressed: _cancelBooking,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Booking'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateAppointment,
          child: _isUpdating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}