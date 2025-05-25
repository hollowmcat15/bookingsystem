import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'book_appointment.dart'; // Import BookAppointment class

// --- Models (Keep as they are) ---
class AppointmentModel {
  final int bookId;
  final int spaId;
  final int clientId;
  final int serviceId;
  final int? receptionistId; // Nullable
  final int? therapistId;    // Nullable
  final DateTime bookingDate;
  final TimeOfDay bookingStartTime;
  final TimeOfDay bookingEndTime;
  final String status;
  final String clientName;
  final String serviceName;
  final String therapistName;

  AppointmentModel({
    required this.bookId,
    required this.spaId,
    required this.clientId,
    required this.serviceId,
    this.receptionistId,   // Optional
    this.therapistId,      // Optional
    required this.bookingDate,
    required this.bookingStartTime,
    required this.bookingEndTime,
    required this.status,
    required this.clientName,
    required this.serviceName,
    required this.therapistName,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    // Add explicit checks and logging within fromJson
    try {
      // Validate required fields first
      if (json['book_id'] == null || json['spa_id'] == null ||
          json['client_id'] == null || json['service_id'] == null ||
          json['booking_date'] == null || json['booking_start_time'] == null ||
          json['booking_end_time'] == null || json['status'] == null) {
        print("[fromJson ERROR] Missing required field in data: $json");
        throw FormatException("Missing required field in appointment data for book_id: ${json['book_id'] ?? 'unknown'}");
      }

      // Debug timestamp parsing
      // print("[fromJson] Parsing booking_date: ${json['booking_date']}");
      DateTime bookingDate;
      try {
        bookingDate = DateTime.parse(json['booking_date']);
      } catch (e) {
        print("[fromJson ERROR] Failed to parse booking_date: ${json['booking_date']}. Error: $e");
        // Fallback to current date if date parsing fails
        bookingDate = DateTime.now();
      }

      // Process client data
      String clientNameStr = 'Unknown Client';
      if (json['client'] is Map<String, dynamic>) {
        final clientData = json['client'] as Map<String, dynamic>;
        clientNameStr = '${clientData['first_name'] ?? ''} ${clientData['last_name'] ?? ''}'.trim();
        if (clientNameStr.isEmpty) clientNameStr = 'Unknown Client';
      } else if (json.containsKey('client_name') && json['client_name'] != null) {
        clientNameStr = json['client_name'];
      }

      // Process service data
      String serviceNameStr = 'Unknown Service';
      if (json['service'] is Map<String, dynamic>) {
        final serviceData = json['service'] as Map<String, dynamic>;
        serviceNameStr = serviceData['service_name'] ?? 'Unknown Service';
      } else if (json.containsKey('service_name') && json['service_name'] != null) {
        serviceNameStr = json['service_name'];
      }

      // Process therapist data
      String therapistNameStr = 'Unassigned';
      if (json['therapist'] is Map<String, dynamic>) {
        final therapistData = json['therapist'] as Map<String, dynamic>;
        therapistNameStr = '${therapistData['first_name'] ?? ''} ${therapistData['last_name'] ?? ''}'.trim();
        if (therapistNameStr.isEmpty) therapistNameStr = 'Unassigned';
      } else if (json.containsKey('therapist_name') && json['therapist_name'] != null) {
        therapistNameStr = json['therapist_name'];
      }

      return AppointmentModel(
        bookId: json['book_id'],
        spaId: json['spa_id'],
        clientId: json['client_id'],
        serviceId: json['service_id'],
        receptionistId: json['receptionist_id'],
        therapistId: json['therapist_id'],
        bookingDate: bookingDate,
        bookingStartTime: _parseTimeString(json['booking_start_time']),
        bookingEndTime: _parseTimeString(json['booking_end_time']),
        status: json['status'],
        clientName: clientNameStr,
        serviceName: serviceNameStr,
        therapistName: therapistNameStr,
      );
    } catch (e, stackTrace) {
      print("[fromJson CRITICAL ERROR] Failed to parse appointment JSON: $e");
      print("[fromJson StackTrace] $stackTrace");
      print("[fromJson Raw Data] $json");
      rethrow;
    }
  }

  static TimeOfDay _parseTimeString(String? timeStr) {
    if (timeStr == null) {
      // print("[_parseTimeString Warning] Received null time string.");
      return const TimeOfDay(hour: 0, minute: 0);
    }
    try {
      // print("[_parseTimeString] Parsing: $timeStr");
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final minutePart = parts[1].split('.').first;
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(minutePart));
      } else {
        print("[_parseTimeString Warning] Unexpected time format: '$timeStr'");
        return const TimeOfDay(hour: 0, minute: 0);
      }
    } catch (e) {
      print("[_parseTimeString Error] Error parsing time string '$timeStr': $e");
      return const TimeOfDay(hour: 0, minute: 0); // Default on error
    }
  }
}

// Other model classes remain unchanged...
class ClientModel {
  final int clientId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phoneNumber;

  ClientModel({
    required this.clientId,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phoneNumber,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    if (json['client_id'] == null) throw FormatException("Missing client_id");
    return ClientModel(
      clientId: json['client_id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'],
      phoneNumber: json['phonenumber'],
    );
  }
}

class ServiceModel {
  final int serviceId;
  final int spaId;
  final String serviceName;
  final double servicePrice;

  ServiceModel({
    required this.serviceId,
    required this.spaId,
    required this.serviceName,
    required this.servicePrice,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    if (json['service_id'] == null || json['spa_id'] == null) throw FormatException("Missing service_id or spa_id");
    return ServiceModel(
      serviceId: json['service_id'],
      spaId: json['spa_id'],
      serviceName: json['service_name'] ?? 'Unknown Service',
      servicePrice: double.tryParse(json['service_price']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}

class TherapistModel {
  final int staffId;  // Changed from therapistId
  final String firstName;
  final String lastName;
  final String? email;
  final String? phoneNumber;
  final String status;

  TherapistModel({
    required this.staffId,  // Changed from therapistId
    required this.firstName,
    required this.lastName,
    this.email,
    this.phoneNumber,
    required this.status,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory TherapistModel.fromJson(Map<String, dynamic> json) {
    if (json['staff_id'] == null) throw FormatException("Missing staff_id");  // Changed from therapist_id
    return TherapistModel(
      staffId: json['staff_id'],  // Changed from therapist_id
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'],
      phoneNumber: json['phonenumber'],
      status: json['status'] ?? 'Unknown',
    );
  }
}
// -------------------------------------------------------------------------

class ReceptionistBookings extends StatefulWidget {
  final int receptionistId;
  final int spaId;

  const ReceptionistBookings({
    Key? key,
    required this.receptionistId,
    required this.spaId,
  }) : super(key: key);

  @override
  _ReceptionistBookingsState createState() => _ReceptionistBookingsState();
}

class _ReceptionistBookingsState extends State<ReceptionistBookings> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<AppointmentModel>> _upcomingAppointments;
  List<AppointmentModel> _pastAppointments = [];
  bool _isLoadingPast = false;
  bool _isLoadingClients = false;
  bool _isRefreshing = false;
  String _selectedFilter = 'All'; // Add this line
  final List<String> _filterOptions = ['All', 'Scheduled', 'Completed', 'Cancelled', 'Rescheduled'];

  @override
  void initState() {
    super.initState();
    print("--- ReceptionistBookings initState ---");
    print("Received spaId: ${widget.spaId}");
    print("Received receptionistId: ${widget.receptionistId}");
    _loadAppointments();
  }

  void _loadAppointments() {
    // Set a loading flag to show a refresh indicator
    if (mounted) {
      setState(() {
        _isRefreshing = true;
      });
    }

    // Create a new Future and assign it
    _upcomingAppointments = _fetchUpcomingAppointments().then((result) {
      // When fetch completes, update loading state
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
      return result;
    }).catchError((error) {
      // Handle errors
      print("[_loadAppointments] Error loading appointments: $error");
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing appointments: $error'), backgroundColor: Colors.red),
        );
      }
      // Return empty list on error
      return <AppointmentModel>[];
    });

    // Force UI update
    if (mounted) {
      setState(() {});
    }
  }

  // *** Enhanced _fetchUpcomingAppointments with detailed logging ***
  Future<List<AppointmentModel>> _fetchUpcomingAppointments() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIso = today.toIso8601String().split('T')[0]; // Format as YYYY-MM-DD

    print("[FetchUpcoming] Fetching upcoming appointments for spa ${widget.spaId} on or after $todayIso");
    // print("[FetchUpcoming] Current date/time: ${now.toIso8601String()}");

    try {
      // First try to debug if Supabase connection is working
      // final testResponse = await _supabase.from('spa').select('spa_id').limit(1);
      // print("[FetchUpcoming] Connection test: ${testResponse is List ? 'Success' : 'Failed'}");

      // Remove status filter from query to get all appointments
      final response = await _supabase
          .from('appointment')
          .select('''
            book_id, spa_id, client_id, service_id, therapist_id, receptionist_id,
            booking_date, booking_start_time, booking_end_time, status,
            client:client_id(first_name, last_name),
            service:service_id(service_name),
            therapist:therapist_id(first_name, last_name)
          ''')
          .eq('spa_id', widget.spaId)
          .gte('booking_date', todayIso)
          .order('booking_date', ascending: true)
          .order('booking_start_time', ascending: true);

      // Explicit type checking
      if (response is! List) {
        print("[FetchUpcoming] Error: Expected List but received ${response.runtimeType}");
        print("[FetchUpcoming] Response data: $response");
        throw Exception("Unexpected data format received from Supabase.");
      }

      final List<dynamic> responseData = response;
      print("[FetchUpcoming] Raw response count: ${responseData.length}");

      // Dump the first record for debugging if available
      // if (responseData.isNotEmpty) {
      //   print("[FetchUpcoming] Sample record: ${responseData[0]}");
      // }

      if (responseData.isEmpty) {
        print("[FetchUpcoming] No raw appointment data found matching criteria.");
        return []; // Return empty list early
      }

      final List<AppointmentModel> mappedAppointments = [];
      int mappingErrors = 0;

      for (var i = 0; i < responseData.length; i++) {
        final appointmentData = responseData[i];
        if (appointmentData is! Map<String, dynamic>) {
          print("[FetchUpcoming] Error: Item at index $i is not a Map: ${appointmentData.runtimeType}");
          mappingErrors++;
          continue; // Skip this item
        }

        try {
          // Attempt to map each appointment individually
          mappedAppointments.add(AppointmentModel.fromJson(appointmentData));
        } catch (e, stack) {
          print("[FetchUpcoming] Error mapping appointment at index $i: $e");
          print("[FetchUpcoming] Stack trace: $stack");
          mappingErrors++;
        }
      }

      print("[FetchUpcoming] Mapping attempt finished. Successfully mapped: ${mappedAppointments.length}, Errors: $mappingErrors");
      return mappedAppointments;

    } catch (e, stackTrace) {
      print("[FetchUpcoming] CRITICAL ERROR fetching/processing upcoming appointments: $e");
      print("[FetchUpcoming] Stack Trace: $stackTrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading upcoming appointments: $e'), backgroundColor: Colors.red),
        );
      }
      return []; // Return empty list on critical error
    }
  }

  // Rest of methods with minor improvements...
  Future<List<AppointmentModel>> _fetchPastAppointments() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIso = today.toIso8601String().split('T')[0];

    print("[FetchPast] Fetching past appointments for spa ${widget.spaId} before $todayIso");

    try {
      final response = await _supabase
          .from('appointment')
          .select('''
             book_id, spa_id, client_id, service_id, receptionist_id, therapist_id,
            booking_date, booking_start_time, booking_end_time, status,
            client:client_id(first_name, last_name),
            service:service_id(service_name),
            therapist:therapist_id(first_name, last_name)
          ''')
          .eq('spa_id', widget.spaId)
          .lt('booking_date', todayIso)
          .or('status.eq.Completed,status.eq.Cancelled') // Alternative syntax for filter
          .order('booking_date', ascending: false)
          .order('booking_start_time', ascending: false)
          .limit(50);

      if (response is! List) {
         print("[FetchPast] Error: Expected List but received ${response.runtimeType}");
         throw Exception("Unexpected data format received from Supabase.");
      }
      final List<dynamic> responseData = response;
      print("[FetchPast] Raw response count: ${responseData.length}");

       if (responseData.isEmpty) {
          print("[FetchPast] No raw past appointment data found.");
          return [];
       }

       List<AppointmentModel> mappedAppointments = [];
       int mappingErrors = 0;
       for (var i = 0; i < responseData.length; i++) {
          final appointmentData = responseData[i];
          if (appointmentData is! Map<String, dynamic>) {
             print("[FetchPast] Error: Item at index $i is not a Map: ${appointmentData.runtimeType}");
             mappingErrors++;
             continue;
          }
          try {
             mappedAppointments.add(AppointmentModel.fromJson(appointmentData));
          } catch (e) {
             mappingErrors++;
          }
       }
       print("[FetchPast] Mapping attempt finished. Successfully mapped: ${mappedAppointments.length}, Errors: $mappingErrors");
       return mappedAppointments;

    } catch (e, stackTrace) { // Catch stack trace
      print("[FetchPast] CRITICAL ERROR fetching/processing past appointments: $e");
      print("[FetchPast] Stack Trace: $stackTrace");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error loading past appointments: $e'), backgroundColor: Colors.red),
         );
      }
      return [];
    }
  }

  // Other methods remain unchanged...
  Future<void> _showPastAppointmentsDialog() async {
  setState(() { _isLoadingPast = true; });
  List<AppointmentModel> pastAppointmentsData = [];
  String? fetchError;
  try {
    pastAppointmentsData = await _fetchPastAppointments();
  } catch(e) {
    fetchError = e.toString();
  }

  if (!mounted) return;
  setState(() { _isLoadingPast = false; });

  if (fetchError != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading past bookings: $fetchError'), backgroundColor: Colors.red),
    );
    return;
  }

  if (pastAppointmentsData.isEmpty && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No past appointments found.')),
    );
    return;
  }

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Past Appointments'),
      content: SizedBox(
        width: double.maxFinite,
        child: pastAppointmentsData.isEmpty
          ? const Center(child: Text('No past appointments found.'))
          : ListView.builder(
              shrinkWrap: true,
              itemCount: pastAppointmentsData.length,
              itemBuilder: (context, index) {
                final appointment = pastAppointmentsData[index];
                // Show Mark Complete button for scheduled/rescheduled past appointments
                final showMarkComplete = appointment.status != 'Cancelled' && 
                                        appointment.status != 'Completed';
                return AppointmentCard(
                  appointment: appointment,
                  isPast: true,
                  onReschedule: (_) {}, // No action needed for past
                  onCancel: (_) {},     // No action needed for past
                  // UPDATED: Allow marking past appointments as complete if not cancelled
                  onMarkComplete: showMarkComplete ? _markAppointmentComplete : (_) {}, 
                );
              },
            ),
      ),
      actions: [ TextButton( onPressed: () => Navigator.of(context).pop(), child: const Text('Close'), ), ],
    ),
  );
}

  Future<void> _showCompletedAppointmentsDialog() async {
  setState(() { _isLoadingPast = true; });
  
  List<AppointmentModel> completedAppointments = [];
  String? fetchError;
  
  try {
    // Fetch only completed appointments
    final response = await _supabase
        .from('appointment')
        .select('''
           book_id, spa_id, client_id, service_id, receptionist_id, therapist_id,
          booking_date, booking_start_time, booking_end_time, status,
          client:client_id(first_name, last_name),
          service:service_id(service_name),
          therapist:therapist_id(first_name, last_name)
        ''')
        .eq('spa_id', widget.spaId)
        .eq('status', 'Completed') // Only show completed appointments
        .order('booking_date', ascending: false)
        .order('booking_start_time', ascending: false)
        .limit(50);

    if (response is! List) {
       print("[FetchCompleted] Error: Expected List but received ${response.runtimeType}");
       throw Exception("Unexpected data format received from Supabase.");
    }
    
    final List<dynamic> responseData = response;
    print("[FetchCompleted] Raw response count: ${responseData.length}");

    if (responseData.isEmpty) {
      print("[FetchCompleted] No completed appointments found.");
      completedAppointments = [];
    } else {
      List<AppointmentModel> mappedAppointments = [];
      int mappingErrors = 0;
      
      for (var i = 0; i < responseData.length; i++) {
        final appointmentData = responseData[i];
        if (appointmentData is! Map<String, dynamic>) {
          print("[FetchCompleted] Error: Item at index $i is not a Map: ${appointmentData.runtimeType}");
          mappingErrors++;
          continue;
        }
        
        try {
          mappedAppointments.add(AppointmentModel.fromJson(appointmentData));
        } catch (e) {
          mappingErrors++;
        }
      }
      
      print("[FetchCompleted] Mapping attempt finished. Successfully mapped: ${mappedAppointments.length}, Errors: $mappingErrors");
      completedAppointments = mappedAppointments;
    }
  } catch (e, stackTrace) {
    print("[FetchCompleted] CRITICAL ERROR fetching completed appointments: $e");
    print("[FetchCompleted] Stack Trace: $stackTrace");
    fetchError = e.toString();
  }

  if (!mounted) return;
  setState(() { _isLoadingPast = false; });

  if (fetchError != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading completed appointments: $fetchError'), backgroundColor: Colors.red),
    );
    return;
  }

  if (completedAppointments.isEmpty && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No completed appointments found.')),
    );
    return;
  }

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Completed Appointments'),
      content: SizedBox(
        width: double.maxFinite,
        child: completedAppointments.isEmpty
          ? const Center(child: Text('No completed appointments found.'))
          : ListView.builder(
              shrinkWrap: true,
              itemCount: completedAppointments.length,
              itemBuilder: (context, index) {
                return AppointmentCard(
                  appointment: completedAppointments[index],
                  isPast: true,
                  onReschedule: (_) {}, // No action needed
                  onCancel: (_) {},     // No action needed
                  onMarkComplete: (_) {}, // No action needed
                );
              },
            ),
      ),
      actions: [ TextButton( onPressed: () => Navigator.of(context).pop(), child: const Text('Close'), ), ],
    ),
  );
}

  Future<void> _showNewAppointmentDialog() async {
    setState(() { _isLoadingClients = true; });

    List<ClientModel> clients = [];
    String? fetchError;
    try { clients = await _fetchClientsForSelection(); }
    catch (e) { fetchError = e.toString(); print('[NewApptDialog] Error fetching clients: $e'); }

    if (!mounted) return;
    setState(() { _isLoadingClients = false; });

    if (fetchError != null) {
       ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Error loading clients: $fetchError'), backgroundColor: Colors.red), );
       return;
    }
     if (clients.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('No clients found to book for.')), );
       return;
    }

    final ClientModel? selectedClient = await showDialog<ClientModel>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Client to Book For'),
          contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
          content: SizedBox(
             width: double.maxFinite,
             height: MediaQuery.of(context).size.height * 0.5,
             child: ListView.builder(
                shrinkWrap: true,
                itemCount: clients.length,
                itemBuilder: (context, index) {
                   final client = clients[index];
                   return ListTile(
                      title: Text(client.fullName),
                      onTap: () { Navigator.pop(context, client); },
                   );
                },
             ),
          ),
           actions: <Widget>[
             TextButton(
                child: const Text('Cancel'),
                onPressed: () { Navigator.of(context).pop(null); },
             ),
          ],
        );
      },
    );

    if (selectedClient != null) {
      print("[NewApptDialog] Navigating to BookAppointment for client: ${selectedClient.fullName} (ID: ${selectedClient.clientId})");
      // Ensure we use the context that is still valid
      final navContext = context;
      final result = await Navigator.of(navContext).push(
        MaterialPageRoute(
          builder: (context) => BookAppointment(
            spaId: widget.spaId,
            clientIdForBooking: selectedClient.clientId,
          ),
        ),
      );
      // Check mounted status again after async navigation
      if (mounted && result == true) {
          print("[NewApptDialog] Booking successful, reloading appointments.");
          _loadAppointments();
       }
    } else { print("[NewApptDialog] Client selection cancelled."); }
  }

  Future<List<ClientModel>> _fetchClientsForSelection() async {
    print("[FetchClients] Attempting to fetch clients for selection...");
    try {
      final response = await _supabase
          .from('client')
          .select('client_id, first_name, last_name, email, phonenumber')
          .order('first_name', ascending: true)
          .order('last_name', ascending: true);

       if (response is! List) {
         print("[FetchClients] Error: Expected List but received ${response.runtimeType}");
         throw Exception("Unexpected data format received from Supabase.");
      }
      print("[FetchClients] Fetched ${response.length} clients.");
      return response.map((client) => ClientModel.fromJson(client)).toList();
    } catch (e, stackTrace) {
      print('[FetchClients] CRITICAL ERROR fetching clients: $e');
      print('[FetchClients] Stack Trace: $stackTrace');
      // Rethrow to be caught by the dialog function
      throw Exception('Failed to load clients: $e');
    }
  }

  Future<void> _showRescheduleDialog(AppointmentModel appointment) async {
    if (appointment.status != 'Scheduled' && appointment.status != 'Rescheduled') {
       if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only Scheduled or Rescheduled appointments can be modified.')));
       }
      return;
    }
    // Ensure we use the context that is still valid
    final navContext = context;
    final result = await Navigator.of(navContext).push(
      MaterialPageRoute(builder: (context) => RescheduleAppointmentPage(appointment: appointment)),
    );
     // Check mounted status again after async navigation
    if (mounted && result == true) {
        print("[Reschedule] Reschedule successful, reloading appointments.");
        _loadAppointments();
     }
  }

  Future<void> _showCancelConfirmation(AppointmentModel appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: Text(
          'Are you sure you want to cancel the appointment for ${appointment.clientName} on ${DateFormat('MMM d, yyyy').format(appointment.bookingDate)}?\n\nThis action cannot be undone.'
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
      await _cancelAppointment(appointment);
    }
  }

  Future<void> _cancelAppointment(AppointmentModel appointment) async {
    print("[CancelAppt] Attempting to cancel appointment ID: ${appointment.bookId}");
    try {
      await _supabase
          .from('appointment')
          .update({
            'status': 'Cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('book_id', appointment.bookId);
      // Check mounted before showing snackbar and reloading
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Appointment for ${appointment.clientName} cancelled.'),
              backgroundColor: Colors.orange // Changed color for cancel
            ),
          );
          _loadAppointments(); // Reload list after successful cancel
       }
    } catch (e) {
      print('[CancelAppt] Error cancelling appointment ID ${appointment.bookId}: $e');
       if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text('Error cancelling appointment: $e'),
               backgroundColor: Colors.red
             ),
           );
        }
    }
  }

  // --- NEW: Function to mark an appointment as complete ---
  Future<void> _markAppointmentComplete(AppointmentModel appointment) async {
    print("[MarkComplete] Attempting to complete appointment ID: ${appointment.bookId}");

    // Optional: Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Completion'),
        content: Text('Mark the appointment for ${appointment.clientName} on ${DateFormat('MMM d, yyyy').format(appointment.bookingDate)} as Completed?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Complete'),
          ),
        ],
      ),
    );

    if (mounted && confirmed == true) {
      try {
        await _supabase
            .from('appointment')
            .update({
              'status': 'Completed', // Set the status to Completed
              'updated_at': DateTime.now().toIso8601String(),
              // Optionally update receptionist_id if needed
              // 'receptionist_id': widget.receptionistId,
            })
            .eq('book_id', appointment.bookId);

        // Check mounted before showing snackbar and reloading
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Appointment for ${appointment.clientName} marked as completed.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadAppointments(); // Reload the list to reflect the change
        }
      } catch (e) {
        print('[MarkComplete] Error completing appointment ID ${appointment.bookId}: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error completing appointment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      print("[MarkComplete] Completion cancelled by user.");
    }
  }
  // --- END NEW FUNCTION ---

  // Add filter state and update UI elements:
  List<AppointmentModel> _getFilteredAppointments(List<AppointmentModel> appointments) {
    if (_selectedFilter == 'All') return appointments;
    
    // Apply the filter
    return appointments.where((appointment) {
      switch (_selectedFilter) {
        case 'Scheduled':
          return appointment.status == 'Scheduled';
        case 'Completed':
          return appointment.status == 'Completed';
        case 'Cancelled':
          return appointment.status == 'Cancelled';
        case 'Rescheduled':
          return appointment.status == 'Rescheduled';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Appointments', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 1,
        actions: [
          // Add filter dropdown with consistent styling
          DropdownButton<String>(
            value: _selectedFilter,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.black87, fontSize: 16),
            underline: Container(),
            icon: const Icon(Icons.filter_list, color: Colors.black87),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            items: _filterOptions.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() => _selectedFilter = newValue);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _isRefreshing ? null : _loadAppointments,
            tooltip: 'Refresh Appointments',
          ),
        ],
      ),
      body: Column(
        children: [
          // New Booking button section - UPDATED
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Fix the New Booking Button
                ElevatedButton.icon(
                  icon: _isLoadingClients
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                      )
                    : const Icon(Icons.add, color: Colors.white),
                  label: const Text('New', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoadingClients ? null : _showNewAppointmentDialog,
                ),
              ],
            ),
          ),
          // Future Builder section
          Expanded(
            child: FutureBuilder<List<AppointmentModel>>(
              key: ValueKey(_isRefreshing),
              future: _upcomingAppointments,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !_isRefreshing) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error loading upcoming appointments: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)
                      ),
                    )
                  );
                }

                if (!snapshot.hasData || snapshot.data == null) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No upcoming appointments data available.',
                        style: TextStyle(fontSize: 16, color: Colors.grey)
                      ),
                    )
                  );
                }

                final appointments = _getFilteredAppointments(snapshot.data!);

                if (appointments.isEmpty) {
                  return Center(
                    child: Text(
                      _selectedFilter == 'All' 
                        ? 'No appointments found.'
                        : 'No ${_selectedFilter.toLowerCase()} appointments found.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _loadAppointments();
                    await _upcomingAppointments;
                  },
                  child: ListView.builder(
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      final appointment = appointments[index];
                      return AppointmentCard(
                        appointment: appointment,
                        isPast: false,
                        onReschedule: _showRescheduleDialog,
                        onCancel: _showCancelConfirmation,
                        onMarkComplete: _markAppointmentComplete,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Remove the floating action button - we already have a New button in the top section
    );
  }
}

// --- UPDATED AppointmentCard widget ---
class AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final bool isPast;
  final Function(AppointmentModel) onReschedule;
  final Function(AppointmentModel) onCancel;
  // --- NEW: Add callback for marking complete ---
  final Function(AppointmentModel) onMarkComplete;
  // --- END NEW ---

  const AppointmentCard({
    Key? key,
    required this.appointment,
    required this.isPast,
    required this.onReschedule,
    required this.onCancel,
    // --- NEW: Add to constructor ---
    required this.onMarkComplete,
    // --- END NEW ---
  }) : super(key: key);

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    // Use format method from context for locale-aware formatting
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
    final format = DateFormat.jm(); // Use appropriate format (e.g., 'h:mm a')
    return format.format(dt);
    // Original simple formatting:
    // final hour = timeOfDay.hour.toString().padLeft(2, '0');
    // final minute = timeOfDay.minute.toString().padLeft(2, '0');
    // return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM d, yyyy').format(appointment.bookingDate);
    final startTime = _formatTimeOfDay(appointment.bookingStartTime);
    final endTime = _formatTimeOfDay(appointment.bookingEndTime);

    // Different card color based on status
    Color cardColor = Colors.white;
    Color statusColor = Colors.black;

    switch (appointment.status) {
      case 'Scheduled':
        cardColor = Colors.blue.shade50;
        statusColor = Colors.blue.shade800;
        break;
      case 'Rescheduled':
        cardColor = Colors.orange.shade50; // Changed color slightly
        statusColor = Colors.orange.shade900;
        break;
      case 'Completed':
        cardColor = Colors.green.shade50;
        statusColor = Colors.green.shade800;
        break;
      case 'Cancelled':
        cardColor = Colors.grey.shade200; // Changed color slightly
        statusColor = Colors.grey.shade600;
        break;
    }

    // Determine if we show the Mark Complete button
    final showMarkComplete = (appointment.status == 'Scheduled' || 
                            appointment.status == 'Rescheduled');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: cardColor,
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.clientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment.serviceName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    appointment.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16, thickness: 0.5),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(formattedDate),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text('$startTime - $endTime'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  'Therapist: ${appointment.therapistName}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
            // Action buttons area - UPDATED to handle past appointments too
            if (showMarkComplete)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  alignment: WrapAlignment.end,
                  children: [
                    // Mark Complete Button - always show if appointment is not cancelled/completed
                    TextButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Mark Complete'),
                      style: TextButton.styleFrom(foregroundColor: Colors.green.shade700),
                      onPressed: () => onMarkComplete(appointment),
                    ),
                    
                    // Only show these buttons for upcoming appointments (not past)
                    if (!isPast) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                        label: const Text('Reschedule'),
                        style: TextButton.styleFrom(foregroundColor: Colors.orange.shade800),
                        onPressed: () => onReschedule(appointment),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                        onPressed: () => onCancel(appointment),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
// --- END UPDATED AppointmentCard ---


// Add the RescheduleAppointmentPage widget that was referenced but not implemented
class RescheduleAppointmentPage extends StatefulWidget {
  final AppointmentModel appointment;

  const RescheduleAppointmentPage({
    Key? key,
    required this.appointment,
  }) : super(key: key);

  @override
  _RescheduleAppointmentPageState createState() => _RescheduleAppointmentPageState();
}

class _RescheduleAppointmentPageState extends State<RescheduleAppointmentPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedStartTime;  // Changed to nullable
  TimeOfDay? _selectedEndTime;    // Changed to nullable
  List<TherapistModel> _availableTherapists = [];
  TherapistModel? _selectedTherapist;
  bool _isLoading = false;
  bool _isSubmitting = false;
  TimeOfDay? spaOpeningTime;
  TimeOfDay? spaClosingTime;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.appointment.bookingDate;
    _selectedStartTime = widget.appointment.bookingStartTime;
    _selectedEndTime = widget.appointment.bookingEndTime;
    _loadAvailableTherapists();
    _fetchSpaHours(); // Add this line
  }

  // Add this method to fetch spa hours
  Future<void> _fetchSpaHours() async {
    try {
      final response = await _supabase
          .from('spa')
          .select('opening_time, closing_time')
          .eq('spa_id', widget.appointment.spaId)
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

  // Add helper method to convert TimeOfDay to minutes
  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  // Add validation method for spa hours
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

  // Modify the date selection method
  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        // Reset times when date changes to today
        if (pickedDate.year == now.year && 
            pickedDate.month == now.month && 
            pickedDate.day == now.day) {
          _selectedStartTime = spaOpeningTime;  // Use spa opening time or null
          _selectedEndTime = null;
        }
      });
    }
  }

  // Modify the start time selection method
  Future<void> _selectStartTime(BuildContext context) async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a date first'))
      );
      return;
    }

    final now = DateTime.now();
    final isToday = _selectedDate!.year == now.year && 
                    _selectedDate!.month == now.month && 
                    _selectedDate!.day == now.day;

    TimeOfDay minimumTime = isToday 
        ? TimeOfDay.now() 
        : spaOpeningTime ?? TimeOfDay(hour: 9, minute: 0);

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime ?? minimumTime,
    );

    if (pickedTime != null) {
      // Validate against minimum time for today
      if (isToday && _timeToMinutes(pickedTime) < _timeToMinutes(minimumTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot select a time in the past'))
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

      setState(() {
        _selectedStartTime = pickedTime;
        _selectedEndTime = null; // Reset end time
      });
    }
  }

  // Modify the end time selection method
  Future<void> _selectEndTime(BuildContext context) async {
    if (_selectedStartTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a start time first'))
      );
      return;
    }

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime ?? TimeOfDay(
        hour: (_selectedStartTime!.hour + 1) % 24,
        minute: _selectedStartTime!.minute
      ),
    );

    if (pickedTime != null) {
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

      // Validate end time is after start time
      if (_timeToMinutes(pickedTime) <= _timeToMinutes(_selectedStartTime!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('End time must be after start time'))
        );
        return;
      }

      setState(() => _selectedEndTime = pickedTime);
    }
  }

  // Add new method to check for conflicts
  Future<bool> _hasAppointmentConflict() async {
    if (_selectedStartTime == null || _selectedEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both start and end times.'),
          backgroundColor: Colors.red,
        ),
      );
      return true;
    }

    final startTimeStr = '${_selectedStartTime!.hour.toString().padLeft(2, '0')}:${_selectedStartTime!.minute.toString().padLeft(2, '0')}:00';
    final endTimeStr = '${_selectedEndTime!.hour.toString().padLeft(2, '0')}:${_selectedEndTime!.minute.toString().padLeft(2, '0')}:00';
    final dateStr = _selectedDate.toIso8601String().split('T')[0];

    try {
      final response = await _supabase
          .from('appointment')
          .select('*, therapist:therapist_id(first_name, last_name)')
          .eq('booking_date', dateStr)
          .eq('status', 'Scheduled')
          .neq('book_id', widget.appointment.bookId) // Exclude current appointment
          .or('and(booking_start_time.lte.${endTimeStr},booking_end_time.gt.${startTimeStr}),and(booking_start_time.lt.${endTimeStr},booking_end_time.gte.${startTimeStr})');

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

  // Modify _submitReschedule to handle null safely
  Future<void> _submitReschedule() async {
    if (_selectedStartTime == null || _selectedEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both start and end times.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedTherapist == null && _availableTherapists.isNotEmpty) {
       if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('Please select a therapist.'),
               backgroundColor: Colors.red,
             ),
           );
       }
       return;
     }
     if (_selectedTherapist == null && _availableTherapists.isEmpty) {
         if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                 content: Text('Cannot reschedule without available therapists.'),
                 backgroundColor: Colors.red,
               ),
             );
         }
         return;
       }

    if (mounted) {
      setState(() {
        _isSubmitting = true;
      });
    }

    // Add conflict check before proceeding
    if (await _hasAppointmentConflict()) {
      return;
    }

    try {
      // Format the time values as expected by Supabase (HH:MM:SS)
      final startTimeStr = '${_selectedStartTime!.hour.toString().padLeft(2, '0')}:${_selectedStartTime!.minute.toString().padLeft(2, '0')}:00';
      final endTimeStr = '${_selectedEndTime!.hour.toString().padLeft(2, '0')}:${_selectedEndTime!.minute.toString().padLeft(2, '0')}:00';
      final dateStr = _selectedDate.toIso8601String().split('T')[0]; // YYYY-MM-DD

      print("[RescheduleSubmit] Updating Book ID: ${widget.appointment.bookId}");
      print("[RescheduleSubmit] New Date: $dateStr");
      print("[RescheduleSubmit] New Start Time: $startTimeStr");
      print("[RescheduleSubmit] New End Time: $endTimeStr");
      print("[RescheduleSubmit] New Therapist ID: ${_selectedTherapist!.staffId}");


      await _supabase
          .from('appointment')
          .update({
            'booking_date': dateStr,
            'booking_start_time': startTimeStr,
            'booking_end_time': endTimeStr,
            'therapist_id': _selectedTherapist!.staffId,
            // Change this line to use staff_id from the parent appointment
            'receptionist_id': widget.appointment.receptionistId,
            'status': 'Rescheduled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('book_id', widget.appointment.bookId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment successfully rescheduled.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('[RescheduleAppointment] Error rescheduling appointment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rescheduling appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    } finally {
      // Ensure submitting state is reset even if mounted check fails after await
      if (_isSubmitting && mounted) {
        setState(() { _isSubmitting = false; });
      }
    }
  }

  Future<void> _loadAvailableTherapists() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // Updated query to use staff table
      final response = await _supabase
          .from('staff')
          .select('staff_id, first_name, last_name, email, phonenumber, status')
          .eq('spa_id', widget.appointment.spaId)
          .eq('role', 'Therapist')  // Add role filter
          .eq('is_active', true)    // Check if staff is active
          .eq('status', 'Active');  // Check therapist status

      if (!mounted) return;

      if (response is! List) {
        throw Exception("Unexpected data format received from Supabase.");
      }

      final therapists = response
          .map((therapist) => TherapistModel.fromJson(therapist))
          .toList();

      setState(() {
        _availableTherapists = therapists;

        // Try to pre-select the current therapist if they exist and are active
        if (_availableTherapists.isNotEmpty) {
          _selectedTherapist = _availableTherapists.firstWhere(
            (t) => t.staffId == widget.appointment.therapistId,  // Changed from therapistId
            orElse: () {
              print("[Reschedule] Current therapist ${widget.appointment.therapistId} not found or inactive in available list. Selecting first available.");
              return _availableTherapists.first;
            }
          );
        } else {
          print("[Reschedule] No active therapists found for spa ${widget.appointment.spaId}.");
          _selectedTherapist = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('[RescheduleAppointment] Error loading therapists: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading therapists: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reschedule Appointment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reschedule for ${widget.appointment.clientName}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Service: ${widget.appointment.serviceName}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),

            // Date Selection
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(_selectedDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              leading: const Icon(Icons.calendar_today_outlined, color: Colors.teal),
              trailing: const Icon(Icons.chevron_right),
              onTap: _isSubmitting ? null : () => _selectDate(context),
            ),
            const Divider(height: 1),

            // Time Selection Row
             Row(
               children: [
                 Expanded(
                   child: ListTile(
                     contentPadding: const EdgeInsets.only(left: 0, right: 4),
                     title: const Text('Start Time'),
                     subtitle: Text(
                       _selectedStartTime?.format(context) ?? 'Select Start Time', 
                       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
                     ),
                     leading: const Icon(Icons.access_time_outlined, color: Colors.teal),
                     trailing: const Icon(Icons.chevron_right),
                     onTap: _isSubmitting ? null : () => _selectStartTime(context),
                   ),
                 ),
                 Expanded(
                   child: ListTile(
                     contentPadding: const EdgeInsets.only(left: 4, right: 0),
                     title: const Text('End Time'),
                     subtitle: Text(
                       _selectedEndTime?.format(context) ?? 'Select End Time',
                       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
                     ),
                     leading: const Icon(Icons.access_time_filled_outlined, color: Colors.teal),
                     trailing: const Icon(Icons.chevron_right),
                     onTap: _isSubmitting || _selectedStartTime == null 
                       ? null 
                       : () => _selectEndTime(context),
                   ),
                 ),
               ],
             ),
             const Divider(height: 1),


            // Therapist Selection
            const SizedBox(height: 24),
            Text(
              'Assign Therapist',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_availableTherapists.isEmpty)
              const Padding(
                 padding: EdgeInsets.symmetric(vertical: 8.0),
                 child: Text('No active therapists found for this spa.', style: TextStyle(color: Colors.red)),
              )
            else
              DropdownButtonFormField<TherapistModel>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                ),
                value: _selectedTherapist,
                hint: const Text('Select therapist'),
                isExpanded: true,
                items: _availableTherapists.map((therapist) {
                  return DropdownMenuItem<TherapistModel>(
                    value: therapist,
                    child: Text(therapist.fullName),
                  );
                }).toList(),
                onChanged: _isSubmitting ? null : (TherapistModel? newValue) {
                  if (mounted) {
                      setState(() {
                          _selectedTherapist = newValue;
                      });
                  }
                },
                validator: (value) => value == null ? 'Please select a therapist' : null,
              ),

            const SizedBox(height: 32),
            // Replace the existing buttons with this new section
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.teal),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || _selectedStartTime == null || _selectedEndTime == null) 
                      ? null 
                      : _submitReschedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.grey,
                      disabledForegroundColor: Colors.white70,
                    ),
                    child: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Confirm',
                          style: TextStyle(fontSize: 16),
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}