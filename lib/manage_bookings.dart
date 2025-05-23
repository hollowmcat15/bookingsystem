import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ManageBookings extends StatefulWidget {
  final String userRole; // 'client' or 'manager'
  final int? userId; // Store actual integer ID of logged-in user

  const ManageBookings({super.key, required this.userRole, this.userId});

  @override
  _ManageBookingsState createState() => _ManageBookingsState();
}

class _ManageBookingsState extends State<ManageBookings> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> bookings = [];
  bool isLoading = true;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? selectedFilter = 'Upcoming'; // Changed default to Upcoming

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  /// Fetch bookings based on user role
  Future<void> _fetchBookings() async {
    try {
      // Adjusted to match your database schema
      final query = supabase.from('appointment').select('''
        book_id,
        spa_id,
        client_id,
        service_id,
        booking_date,
        booking_start_time,
        booking_end_time,
        status,
        created_at,
        updated_at,
        spa:spa(spa_id, spa_name),
        service:service(service_id, service_name, service_price),
        client:client(client_id, first_name, last_name, email)
      ''');

      // Inside _fetchBookings() method
      final response = widget.userRole == 'manager'
          ? await query // Managers see all bookings
          : widget.userId != null 
              ? await query.eq('client_id', widget.userId!) // Use non-null assertion when we know it's not null
              : []; // Empty array if no userId is provided

      if (mounted) {
        setState(() {
          bookings = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching bookings: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// Cancel Booking (for both roles)
  Future<void> _cancelBooking(int bookingId) async {
    try {
      await supabase.from('appointment').update({
        'status': 'Cancelled',
        'updated_at': DateFormat('yyyy-MM-dd').format(DateTime.now())
      }).eq('book_id', bookingId);
      _fetchBookings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled successfully')),
      );
    } catch (e) {
      print('Error cancelling booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to cancel booking')),
      );
    }
  }

  /// Approve Booking (only for managers)
  Future<void> _approveBooking(int bookingId) async {
    try {
      await supabase.from('appointment').update({
        'status': 'Scheduled',
        'updated_at': DateFormat('yyyy-MM-dd').format(DateTime.now())
      }).eq('book_id', bookingId);
      _fetchBookings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking approved successfully')),
      );
    } catch (e) {
      print('Error approving booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to approve booking')),
      );
    }
  }

  /// Mark Booking as Complete (only for managers)
  Future<void> _markBookingComplete(int bookingId) async {
    try {
      await supabase.from('appointment').update({
        'status': 'Completed',
        'updated_at': DateFormat('yyyy-MM-dd').format(DateTime.now())
      }).eq('book_id', bookingId);
      _fetchBookings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment marked as completed')),
      );
    } catch (e) {
      print('Error marking booking as complete: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to mark appointment as completed')),
      );
    }
  }

  /// Check for appointment conflicts
  Future<bool> _hasAppointmentConflict(DateTime newDateTime, int currentBookingId) async {
    try {
      final date = DateFormat('yyyy-MM-dd').format(newDateTime);
      final startTime = DateFormat('HH:mm:ss').format(newDateTime);
      final endTime = DateFormat('HH:mm:ss').format(newDateTime.add(const Duration(hours: 1)));

      final response = await supabase
          .from('appointment')
          .select('*, therapist:therapist(first_name, last_name)')
          .eq('booking_date', date)
          .eq('status', 'Scheduled')
          .neq('book_id', currentBookingId) // Exclude current booking
          .or('and(booking_start_time.lte.${endTime},booking_end_time.gt.${startTime}),and(booking_start_time.lt.${endTime},booking_end_time.gte.${startTime})');

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
            duration: Duration(seconds: 4),
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

  /// Reschedule appointment (for clients)
  Future<void> _rescheduleAppointment(int bookingId, DateTime newDateTime) async {
    // First check for conflicts
    bool hasConflict = await _hasAppointmentConflict(newDateTime, bookingId);
    if (hasConflict) return;

    try {
      // Updated to match schema - separating date and time
      final date = DateFormat('yyyy-MM-dd').format(newDateTime);
      final startTime = DateFormat('HH:mm:ss').format(newDateTime);
      final endTime = DateFormat('HH:mm:ss').format(newDateTime.add(const Duration(hours: 1)));
      
      await supabase.from('appointment').update({
        'booking_date': date,
        'booking_start_time': startTime,
        'booking_end_time': endTime,
        'status': 'Rescheduled',
        'updated_at': DateFormat('yyyy-MM-dd').format(DateTime.now())
      }).eq('book_id', bookingId);
      _fetchBookings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment rescheduled successfully')),
      );
    } catch (e) {
      print('Error rescheduling appointment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reschedule appointment')),
      );
    }
  }

  /// Change appointment time (for managers)
  Future<void> _changeAppointmentTime(int bookingId, DateTime newDateTime) async {
    // First check for conflicts
    bool hasConflict = await _hasAppointmentConflict(newDateTime, bookingId);
    if (hasConflict) return;

    try {
      // Updated to match schema - separating date and time
      final date = DateFormat('yyyy-MM-dd').format(newDateTime);
      final startTime = DateFormat('HH:mm:ss').format(newDateTime);
      final endTime = DateFormat('HH:mm:ss').format(newDateTime.add(const Duration(hours: 1)));
      
      await supabase.from('appointment').update({
        'booking_date': date,
        'booking_start_time': startTime,
        'booking_end_time': endTime,
        'updated_at': DateFormat('yyyy-MM-dd').format(DateTime.now())
      }).eq('book_id', bookingId);
      _fetchBookings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment time changed successfully')),
      );
    } catch (e) {
      print('Error changing appointment time: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to change appointment time')),
      );
    }
  }

  /// Show date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  /// Show time picker
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  /// Show dialog to reschedule
  void _showRescheduleDialog(BuildContext context, {required int bookingId}) {
    setState(() {
      selectedDate = null;
      selectedTime = null;
    });
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(widget.userRole == 'client' ? "Reschedule Appointment" : "Change Appointment Time"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text("Date: ${selectedDate != null ? DateFormat('yyyy-MM-dd').format(selectedDate!) : 'Not selected'}"),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context).then((_) {
                        setState(() {}); // Update StatefulBuilder state
                      }),
                    ),
                    ListTile(
                      title: Text("Time: ${selectedTime != null ? selectedTime!.format(context) : 'Not selected'}"),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _selectTime(context).then((_) {
                        setState(() {}); // Update StatefulBuilder state
                      }),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text("Confirm"),
                  onPressed: () {
                    if (selectedDate != null && selectedTime != null) {
                      final dateTime = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                      
                      if (widget.userRole == 'client') {
                        _rescheduleAppointment(bookingId, dateTime);
                      } else {
                        _changeAppointmentTime(bookingId, dateTime);
                      }
                      Navigator.of(context).pop();
                    } else {
                      // Show error that date and time must be selected
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select both date and time')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Get a date-time object from booking data
  DateTime? _getBookingDateTime(Map<String, dynamic> booking) {
    if (booking['booking_date'] == null || booking['booking_start_time'] == null) {
      return null;
    }
    
    final bookingDate = DateTime.parse(booking['booking_date']);
    final startTime = booking['booking_start_time'].toString();
    final timeParts = startTime.split(':');
    
    if (timeParts.length >= 2) {
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      return DateTime(
        bookingDate.year,
        bookingDate.month,
        bookingDate.day,
        hour,
        minute,
      );
    }
    
    return bookingDate;
  }

  /// Filter and sort appointments based on filter selection
  List<Map<String, dynamic>> _getFilteredBookings() {
    List<Map<String, dynamic>> filtered = [];
    final now = DateTime.now();
    
    switch (selectedFilter) {
      case 'Past':
        filtered = bookings.where((booking) {
          final bookingDateTime = _getBookingDateTime(booking);
          final status = booking['status'];
          return bookingDateTime != null && 
                 bookingDateTime.isBefore(now) &&
                 status != 'Cancelled' &&  // Exclude cancelled
                 status != 'Scheduled' &&  // Exclude upcoming
                 status != 'Rescheduled';  // Exclude rescheduled
        }).toList();
        break;
        
      case 'Upcoming':
        filtered = bookings.where((booking) {
          final bookingDateTime = _getBookingDateTime(booking);
          final status = booking['status'];
          return bookingDateTime != null &&
                 (bookingDateTime.isAfter(now) ||
                  _isSameDay(bookingDateTime, now)) &&
                 (status == 'Scheduled' || status == 'Rescheduled');
        }).toList();
        break;
        
      case 'Cancelled':
        filtered = bookings.where((booking) =>
          booking['status'] == 'Cancelled'
        ).toList();
        break;
        
      default:
        filtered = bookings;
    }

    // Sort based on date
    filtered.sort((a, b) {
      final dateTimeA = _getBookingDateTime(a);
      final dateTimeB = _getBookingDateTime(b);
      
      if (dateTimeA == null) return 1;
      if (dateTimeB == null) return -1;
      
      if (selectedFilter == 'Upcoming') {
        return dateTimeA.compareTo(dateTimeB); // Ascending for upcoming
      } else {
        return dateTimeB.compareTo(dateTimeA); // Descending for past/cancelled
      }
    });
    
    return filtered;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  
  @override
  Widget build(BuildContext context) {
    final filteredBookings = _getFilteredBookings();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Bookings"),
        actions: [
          // Filter dropdown
          DropdownButton<String>(
            value: selectedFilter,
            icon: const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.filter_list),
            ),
            onChanged: (String? newValue) {
              setState(() {
                selectedFilter = newValue;
              });
            },
            items: <String>['Upcoming', 'Past', 'Cancelled']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(value),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredBookings.isEmpty
              ? Center(
                  child: Text(
                    "No ${selectedFilter?.toLowerCase()} appointments found.",
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredBookings.length,
                  itemBuilder: (context, index) {
                    final booking = filteredBookings[index];
                    
                    // Combine date and start time for display
                    final bookingDate = booking['booking_date'] != null 
                        ? DateTime.parse("${booking['booking_date']}") 
                        : null;
                    
                    final startTime = booking['booking_start_time'];
                    
                    String formattedDate = "No date";
                    bool isPastAppointment = false;
                    
                    if (bookingDate != null && startTime != null) {
                      // Parse time string (assuming format like "14:30:00")
                      final timeParts = startTime.toString().split(':');
                      if (timeParts.length >= 2) {
                        final hour = int.parse(timeParts[0]);
                        final minute = int.parse(timeParts[1]);
                        
                        final fullDateTime = DateTime(
                          bookingDate.year,
                          bookingDate.month,
                          bookingDate.day,
                          hour,
                          minute,
                        );
                        
                        formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(fullDateTime);
                        isPastAppointment = fullDateTime.isBefore(DateTime.now());
                      }
                    }
                    
                    // Get client name
                    final clientFirstName = booking['client']?['first_name'] ?? '';
                    final clientLastName = booking['client']?['last_name'] ?? '';
                    final clientName = "$clientFirstName $clientLastName".trim();
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    booking['service']?['service_name'] ?? "Unknown Service",
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(booking['status']),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    booking['status'] ?? "Unknown",
                                    style: TextStyle(
                                      color: _getStatusTextColor(booking['status']),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text("Date: $formattedDate"),
                            if (widget.userRole == 'manager')
                              Text("Client: ${clientName.isNotEmpty ? clientName : 'Unknown'}"),
                            Text("Spa: ${booking['spa']?['spa_name'] ?? 'Unknown'}"),
                            if (booking['service']?['service_price'] != null)
                              Text("Price: \$${booking['service']['service_price']}"),
                            const SizedBox(height: 12),
                            
                            // Only show action buttons for non-completed/cancelled status
                            if (booking['status'] != 'Completed' && 
                                booking['status'] != 'Cancelled') 
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (widget.userRole == 'manager') ...[
                                    ElevatedButton(
                                      onPressed: () => _markBookingComplete(booking['book_id']),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                      ),
                                      child: const Text("Mark Complete"),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (widget.userRole == 'manager' && booking['status'] == 'Rescheduled') ...[
                                    ElevatedButton(
                                      onPressed: () => _approveBooking(booking['book_id']),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                      child: const Text("Approve"),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  ElevatedButton(
                                    onPressed: () => _showRescheduleDialog(
                                      context, 
                                      bookingId: booking['book_id'],
                                    ),
                                    child: Text(widget.userRole == 'client' ? "Reschedule" : "Change Time"),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _cancelBooking(booking['book_id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const Text("Cancel"),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
  
  // Helper method to get background color for status
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Scheduled':
        return Colors.green[100]!;
      case 'Completed': 
        return Colors.blue[100]!;
      case 'Rescheduled':
        return Colors.orange[100]!;
      case 'Cancelled':
        return Colors.red[100]!;
      default:
        return Colors.grey[100]!;
    }
  }
  
  // Helper method to get text color for status
  Color _getStatusTextColor(String? status) {
    switch (status) {
      case 'Scheduled':
        return Colors.green[800]!;
      case 'Completed': 
        return Colors.blue[800]!;
      case 'Rescheduled':
        return Colors.orange[800]!;
      case 'Cancelled':
        return Colors.red[800]!;
      default:
        return Colors.grey[800]!;
    }
  }
}