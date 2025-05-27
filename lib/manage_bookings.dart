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
  TimeOfDay? selectedEndTime; // Add this variable
  String? selectedFilter = 'Upcoming'; // Changed default to Upcoming

  // Add these variables for spa hours
  TimeOfDay? spaOpeningTime;
  TimeOfDay? spaClosingTime;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
    _fetchSpaHours(); // Add this line
  }

  /// Fetch bookings based on user role
  Future<void> _fetchBookings() async {
    try {
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
        client:client(client_id, first_name, last_name, email),
        therapist:therapist_id(first_name, last_name)
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

  // Add spa hours fetching method
  Future<void> _fetchSpaHours() async {
    try {
      final response = await supabase
          .from('spa')
          .select('opening_time, closing_time')
          .eq('spa_id', widget.userId ?? 1) // Using default value 1 if userId is null
          .single();

      if (response != null) {
        setState(() {
          final openingTimeParts = response['opening_time'].split(':');
          final closingTimeParts = response['closing_time'].split(':');
          
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

  /// Cancel Booking (for both roles)
  Future<void> _cancelBooking(int bookingId) async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Appointment?'),
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
        );
      },
    );

    // Only proceed if user confirmed
    if (confirmed == true) {
      try {
        await supabase.from('appointment').update({
          'status': 'Cancelled',
          'updated_at': DateFormat('yyyy-MM-dd').format(DateTime.now())
        }).eq('book_id', bookingId);
        
        _fetchBookings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking cancelled successfully')),
          );
        }
      } catch (e) {
        print('Error cancelling booking: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to cancel booking')),
          );
        }
      }
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
    // First validate the selected time
    final selectedTime = TimeOfDay.fromDateTime(newDateTime);
    
    // Check if the time is in the past
    final now = DateTime.now();
    if (newDateTime.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot reschedule to a past time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate spa hours
    if (!_validateSpaHours(selectedTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selected time must be within spa operating hours: ' +
            '${spaOpeningTime!.format(context)} - ${spaClosingTime!.format(context)}'
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check for conflicts
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
    final now = TimeOfDay.now();
    final DateTime today = DateTime.now();
    final isToday = selectedDate?.year == today.year && 
                    selectedDate?.month == today.month && 
                    selectedDate?.day == today.day;

    TimeOfDay minimumTime = isToday 
        ? now 
        : spaOpeningTime ?? TimeOfDay(hour: 9, minute: 0);

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? minimumTime,
    );

    if (pickedTime != null) {
      // Validate against minimum time for today
      if (isToday && _timeToMinutes(pickedTime) < _timeToMinutes(minimumTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot select a time in the past'))
        );
        return;
      }

      // Validate against spa hours
      if (!_validateSpaHours(pickedTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            'Selected time must be within spa operating hours: ' +
            '${spaOpeningTime!.format(context)} - ${spaClosingTime!.format(context)}'
          ))
        );
        return;
      }

      setState(() => selectedTime = pickedTime);
    }
  }

  /// Show dialog to reschedule
  void _showRescheduleDialog(BuildContext context, {required int bookingId}) {
    setState(() {
      selectedDate = null;
      selectedTime = null;
      selectedEndTime = null; // Add this line
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
                        setState(() {}); 
                      }),
                    ),
                    ListTile(
                      title: Text("Start Time: ${selectedTime != null ? selectedTime!.format(context) : 'Not selected'}"),
                      trailing: const Icon(Icons.access_time),
                      onTap: () => _selectTime(context).then((_) {
                        setState(() {
                          // When start time changes, automatically set end time 1 hour later
                          if (selectedTime != null) {
                            selectedEndTime = TimeOfDay(
                              hour: (selectedTime!.hour + 1) % 24,
                              minute: selectedTime!.minute,
                            );
                          }
                        });
                      }),
                    ),
                    ListTile(
                      title: Text("End Time: ${selectedEndTime != null ? selectedEndTime!.format(context) : 'Not selected'}"),
                      trailing: const Icon(Icons.access_time),
                      enabled: selectedTime != null,
                      onTap: selectedTime == null ? null : () => _selectEndTime(context).then((_) {
                        setState(() {});
                      }),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text("Confirm"),
                  onPressed: () {
                    if (selectedDate != null && selectedTime != null && selectedEndTime != null) {
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select date, start time, and end time')),
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

  // Add method to select end time
  Future<void> _selectEndTime(BuildContext context) async {
    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start time first')),
      );
      return;
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedEndTime ?? TimeOfDay(
        hour: (selectedTime!.hour + 1) % 24,
        minute: selectedTime!.minute,
      ),
    );

    if (picked != null) {
      // Validate end time is after start time
      final startMinutes = selectedTime!.hour * 60 + selectedTime!.minute;
      final endMinutes = picked.hour * 60 + picked.minute;

      if (endMinutes <= startMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time')),
        );
        return;
      }

      setState(() => selectedEndTime = picked);
    }
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

  // Add time validation helpers
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

  void _showBookingDetails(Map<String, dynamic> booking) {
    final bookingDateTime = _getBookingDateTime(booking);
    if (bookingDateTime == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Booking Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.spa, color: Theme.of(context).primaryColor),
                title: Text('Service'),
                subtitle: Text(booking['service']['service_name']),
              ),
              ListTile(
                leading: Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                title: Text('Date'),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(bookingDateTime)),
              ),
              ListTile(
                leading: Icon(Icons.access_time, color: Theme.of(context).primaryColor),
                title: Text('Time'),
                subtitle: Text('${booking['booking_start_time']} - ${booking['booking_end_time']}'),
              ),
              ListTile(
                leading: Icon(Icons.person, color: Theme.of(context).primaryColor),
                title: Text('Therapist'),
                subtitle: Text(
                  booking['therapist'] != null 
                    ? '${booking['therapist']['first_name']} ${booking['therapist']['last_name']}'
                    : 'Not assigned'
                ),
              ),
              ListTile(
                leading: Icon(Icons.attach_money, color: Theme.of(context).primaryColor),
                title: Text('Total'),
                subtitle: Text('₱${booking['service']['service_price'].toString()}'),
              ),
              ListTile(
                leading: Icon(Icons.info_outline, color: _getStatusTextColor(booking['status'])),
                title: Text('Status'),
                subtitle: Text(
                  booking['status'],
                  style: TextStyle(
                    color: _getStatusTextColor(booking['status']),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Bookings'),
        actions: [
          DropdownButton<String>(
            value: selectedFilter,
            items: ['All', 'Upcoming', 'Past', 'Cancelled'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  selectedFilter = newValue;
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBookings,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : bookings.isEmpty
              ? const Center(child: Text('No bookings found'))
              : ListView.builder(
                  itemCount: _getFilteredBookings().length,
                  padding: const EdgeInsets.all(8.0),
                  itemBuilder: (context, index) {
                    final booking = _getFilteredBookings()[index];
                    final bookingDateTime = _getBookingDateTime(booking);
                    if (bookingDateTime == null) return Container();

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      color: _getStatusColor(booking['status']),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text('Service: ${booking['service']['service_name']}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date: ${DateFormat('MMM dd, yyyy').format(bookingDateTime)}'),
                                Text('Time: ${DateFormat('hh:mm a').format(bookingDateTime)}'),
                                Text('Status: ${booking['status']}',
                                    style: TextStyle(color: _getStatusTextColor(booking['status']))),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                            child: Row(
                              children: [
                                TextButton.icon(
                                  icon: Icon(Icons.visibility),
                                  label: Text('View Details'),
                                  onPressed: () => _showBookingDetails(booking),
                                ),
                                Spacer(),
                                if (booking['status'] == 'Scheduled' || booking['status'] == 'Rescheduled')
                                  PopupMenuButton(
                                    itemBuilder: (context) => [
                                      if (widget.userRole == 'client')
                                        PopupMenuItem(
                                          child: const Text('Reschedule'),
                                          onTap: () => _showRescheduleDialog(
                                              context, bookingId: booking['book_id']),
                                        ),
                                      if (widget.userRole == 'manager')
                                        PopupMenuItem(
                                          child: const Text('Change Time'),
                                          onTap: () => _showRescheduleDialog(
                                              context, bookingId: booking['book_id']),
                                        ),
                                      PopupMenuItem(
                                        child: const Text('Cancel'),
                                        onTap: () => _cancelBooking(booking['book_id']),
                                      ),
                                      if (widget.userRole == 'manager')
                                        PopupMenuItem(
                                          child: const Text('Mark Complete'),
                                          onTap: () =>
                                              _markBookingComplete(booking['book_id']),
                                        ),
                                    ],
                                  )
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}