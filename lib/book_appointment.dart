import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // For date and number formatting

// --- db.txt Schema Summary (Relevant Parts) ---
// TABLE client: client_id (PK), email
// TABLE receptionist: receptionist_id (PK), auth_id (FK to auth.users)
// TABLE appointment: book_id (PK), spa_id, client_id, service_id, receptionist_id, therapist_id, booking_date, booking_start_time, booking_end_time, status, created_at, updated_at
// TABLE therapist: therapist_id (PK), spa_id, first_name, last_name
// TABLE service: service_id (PK), spa_id, service_name, service_price
// ---------------------------------------------

class BookAppointment extends StatefulWidget {
  final int spaId;
  // This ID is provided ONLY when a receptionist is booking FOR a client.
  // It will be NULL if a client is booking for themselves.
  final int? clientIdForBooking;

  const BookAppointment({
    Key? key,
    required this.spaId,
    this.clientIdForBooking, // Optional: Used by receptionists
  }) : super(key: key);

  @override
  _BookAppointmentState createState() => _BookAppointmentState();
}

class _BookAppointmentState extends State<BookAppointment> {
  final SupabaseClient supabase = Supabase.instance.client;
  DateTime? selectedDate;
  TimeOfDay? selectedStartTime;
  TimeOfDay? selectedEndTime;
  int? selectedServiceId;
  // Remove the private variable and its references
  int? selectedTherapistId; // Change back to public and keep it simple

  List<dynamic> services = [];
  List<dynamic> therapists = []; // State for therapist list
  bool isLoading = false;

  // Custom Color using the specified RGB
  final Color primaryPurple = Color.fromRGBO(70, 53, 177, 1);
  final Color lightPurple = Color.fromRGBO(70, 53, 177, 0.7);
  final Color darkPurple = Color.fromRGBO(70, 53, 177, 0.9);

  // Add these variables at the top of the class
  TimeOfDay? spaOpeningTime;
  TimeOfDay? spaClosingTime;

  @override
  void initState() {
    super.initState();
    // Fetch data needed for the dropdowns
    _fetchServices();
    _fetchTherapists();
    _fetchSpaHours(); // Add this line
  }

  // --- Data Fetching Functions ---

  Future<void> _fetchServices() async {
    try {
      final response = await supabase
          .from('service')
          .select('service_id, service_name, service_price')
          .eq('spa_id', widget.spaId)
          .order('service_name', ascending: true); // Optional: Order services alphabetically

      if (mounted) {
        setState(() {
          services = response;
        });
      }
    } catch (e) {
      print("Error fetching services: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching services: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _fetchTherapists() async {
    try {
      final response = await supabase
          .from('therapist')
          .select('therapist_id, first_name, last_name')
          .eq('spa_id', widget.spaId)
          // Optionally filter by status if needed: .eq('status', 'Active')
          .order('first_name', ascending: true) // Optional: Order therapists
          .order('last_name', ascending: true);

      if (mounted) {
        setState(() {
          therapists = response;
        });
      }
    } catch (e) {
      print("Error fetching therapists: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching therapists: ${e.toString()}")),
        );
      }
    }
  }

  // Add this new method to fetch spa hours
  Future<void> _fetchSpaHours() async {
    try {
      final response = await supabase
          .from('spa')
          .select('opening_time, closing_time')
          .eq('spa_id', widget.spaId)
          .single();

      if (response != null) {
        setState(() {
          // Convert time strings to TimeOfDay objects
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

  // --- Date & Time Picker Functions ---

  void _selectDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(Duration(days: 1)), // Allow today
      lastDate: DateTime.now().add(Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryPurple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
      });
      // Remove the _findNextAvailableSlot call
    }
  }

  void _selectStartTime() async {
    TimeOfDay initialTime = selectedStartTime ?? (spaOpeningTime ?? TimeOfDay(hour: 9, minute: 0));
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryPurple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            timePickerTheme: TimePickerThemeData(),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      // Validate against spa hours
      if (!_validateSpaHours(pickedTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Selected time must be within spa operating hours: "
              "${spaOpeningTime!.format(context)} - ${spaClosingTime!.format(context)}"
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        selectedStartTime = pickedTime;
        // Reset end time if start time changes or if end time is now invalid
        if (selectedEndTime != null) {
          final startMinutes = selectedStartTime!.hour * 60 + selectedStartTime!.minute;
          final endMinutes = selectedEndTime!.hour * 60 + selectedEndTime!.minute;
          if (endMinutes <= startMinutes) {
             selectedEndTime = null; // Force re-selection
          }
        }
         // Suggest end time only if start time is set and end time isn't
         if (selectedStartTime != null && selectedEndTime == null) {
             final suggestedEndHour = (selectedStartTime!.hour + 1) % 24; // Add 1 hour, handle midnight wrap
             selectedEndTime = TimeOfDay(hour: suggestedEndHour, minute: selectedStartTime!.minute);
         }
      });
    }
  }

  void _selectEndTime() async {
    if (selectedStartTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Please select a start time first."),
            backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    // Suggest an initial end time 1 hour after start time, or use existing end time
    TimeOfDay initialTime = selectedEndTime ?? TimeOfDay(hour: (selectedStartTime!.hour + 1) % 24, minute: selectedStartTime!.minute);
    final startMinutes = selectedStartTime!.hour * 60 + selectedStartTime!.minute;
    final initialEndMinutes = initialTime.hour * 60 + initialTime.minute;

    // Ensure initial time for picker is after start time
    if (initialEndMinutes <= startMinutes) {
      initialTime = TimeOfDay(hour: (selectedStartTime!.hour + 1) % 24, minute: selectedStartTime!.minute);
    }


    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryPurple,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      // Validate against spa hours
      if (!_validateSpaHours(pickedTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Selected time must be within spa operating hours: "
              "${spaOpeningTime!.format(context)} - ${spaClosingTime!.format(context)}"
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final endMinutes = pickedTime.hour * 60 + pickedTime.minute;

      // Validate that end time is strictly after start time
      if (endMinutes > startMinutes) {
        setState(() {
          selectedEndTime = pickedTime;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("End time must be after start time."),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // --- Core Booking Logic ---

  /// Core booking logic with validation and summary
  void _bookAppointment() async {
    // 1. Perform validations first
    if (!_validateBooking()) return;

    // 2. Show booking summary and get confirmation
    bool proceed = await _showBookingSummary();
    if (!proceed) return;

    // 3. Check for conflicts
    bool hasConflict = await _hasAppointmentConflict();
    if (hasConflict) return;

    setState(() {
      isLoading = true;
    });

    try {
      // 4. Format date and time
      final String startTime = "${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}:00";
      final String endTime = "${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}:00";
      final String appointmentDate = DateFormat('yyyy-MM-dd').format(selectedDate!);
      final String nowTimestamp = DateTime.now().toIso8601String();

      // 5. Identify User and Determine IDs
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception("User not logged in. Please log in to book.");
      }

      int? bookingClientId;      // The client receiving the service
      int? bookingReceptionistId; // The receptionist making the booking (if applicable)

      // Check if the logged-in user is a Receptionist by matching their auth_id
      final receptionistResponse = await supabase
          .from('receptionist')
          .select('receptionist_id')
          .eq('auth_id', user.id) // Compare Supabase Auth user ID with receptionist.auth_id
          .maybeSingle(); // Use maybeSingle as the user might not be a receptionist

      if (receptionistResponse != null && receptionistResponse['receptionist_id'] != null) {
        // --- Scenario: Logged-in user IS a Receptionist ---
        print("User identified as Receptionist.");
        bookingReceptionistId = receptionistResponse['receptionist_id'];

        // For a receptionist booking, the client ID MUST be provided via the widget argument
        if (widget.clientIdForBooking == null) {
          // This is a crucial error: The receptionist is using the form but didn't specify WHO it's for.
          throw Exception("Receptionist booking flow error: Client ID was not provided to the booking form.");
        }
        bookingClientId = widget.clientIdForBooking;
        print("Booking FOR Client ID: $bookingClientId BY Receptionist ID: $bookingReceptionistId");

      } else {
        // --- Scenario: Logged-in user is NOT a Receptionist (Assume Client) ---
        print("User identified as Client (or other non-receptionist role).");

        // Clients book for themselves. Fetch their client_id using their email.
        if (user.email == null) {
          // Email is needed to link auth user to client table as per schema description
          throw Exception("Cannot find client record: Logged-in user has no email address.");
        }

        final clientResponse = await supabase
            .from('client')
            .select('client_id')
            .eq('email', user.email!)
            .maybeSingle(); // Use maybeSingle in case the email isn't in the client table yet

        if (clientResponse == null || clientResponse['client_id'] == null) {
          // This could happen if a user authenticated but their record isn't in the 'client' table.
          // Consider adding logic here to CREATE a client record if desired, or provide clearer instructions.
          throw Exception("Client profile not found for email: ${user.email}. Please complete your profile or contact support.");
        }
        bookingClientId = clientResponse['client_id'];
        bookingReceptionistId = null; // Client is booking for themselves, receptionist is not involved in this action.
        print("Booking by Client ID: $bookingClientId");
      }

      // 4. --- Final Check & Prepare Data for Insertion ---
      if (bookingClientId == null) {
        // Safety check - this should not be reachable if the logic above is correct
        throw Exception("Fatal booking error: Could not determine the client for the appointment.");
      }

      final Map<String, dynamic> bookingData = {
        'spa_id': widget.spaId,
        'client_id': bookingClientId,        // Determined above based on role
        'service_id': selectedServiceId,
        'receptionist_id': bookingReceptionistId, // Determined above based on role (null for client bookings)
        'therapist_id': selectedTherapistId,   // Optional selection from the form
        'booking_date': appointmentDate,
        'booking_start_time': startTime,
        'booking_end_time': endTime,
        'status': 'Scheduled',                 // Default status for new bookings
        'created_at': nowTimestamp,
        'updated_at': nowTimestamp,            // Set updated_at on creation as well
      };

      print("Attempting to insert booking data: $bookingData"); // Helpful for debugging

      // 5. --- Insert into Database ---
      final response = await supabase
          .from('appointment')
          .insert(bookingData)
          .select(); // select() can help verify insertion with RLS

      // Simplified success handling without notifications
      if (response.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            .showSnackBar(
              const SnackBar(
                content: Text("Appointment booked successfully!"),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            )
            .closed
            .then((_) {
              if (mounted) {
                Navigator.pop(context, true);
              }
            });
        }
      } else {
        print("Warning: Booking insert response was empty. RLS might be blocking select, or insert failed silently.");
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
               content: Text("Booking submitted, confirmation pending."),
               backgroundColor: Colors.orange),
        );
        Navigator.pop(context, true);
      }

    } catch (error) {
      // 7. --- Handle Errors ---
      print("❌ Booking Error: $error"); // Log the full error for debugging
      String errorMessage = "Failed to book appointment."; // Default user message
      if (error is PostgrestException) {
        errorMessage += " (DB Error: ${error.message} [Code: ${error.code}])"; // Provide DB details
        // Add specific messages for common errors
        if (error.code == '23503') { // Foreign key violation
            errorMessage += "\nPossible invalid selection or missing linked record (Client/Service/Therapist?).";
        } else if (error.code == '23505') { // Unique constraint violation
            errorMessage += "\nThis time slot might conflict with another booking or constraint.";
        } else if (error.code == '42501') { // RLS policy violation
            errorMessage += "\nYou may not have permission to perform this action.";
        }
      } else {
        errorMessage += " (${error.toString()})"; // Generic error message
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 6), // Longer duration for errors
        ),
      );
    } finally {
      // 8. --- Cleanup ---
      if (mounted) {
          setState(() {
              isLoading = false; // Ensure loading indicator stops
          });
      }
    }
  }

  // Replace the old _bookAppointment method with this updated version
  void _processBooking() {
    // Perform validations
    if (!_validateBooking()) return;

    // Show booking summary and get confirmation
    _showBookingSummary().then((proceed) {
      if (proceed) {
        setState(() => isLoading = true);
        _bookAppointment();  // Remove await since _bookAppointment is void
      }
    });
  }

  // --- Appointment Conflict Management ---

  // Function to check for appointment conflicts
  Future<bool> _hasAppointmentConflict() async {
    if (selectedDate == null || selectedStartTime == null || selectedEndTime == null) {
      return false;
    }

    final String startTime = "${selectedStartTime!.hour.toString().padLeft(2, '0')}:${selectedStartTime!.minute.toString().padLeft(2, '0')}:00";
    final String endTime = "${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}:00";
    final String appointmentDate = DateFormat('yyyy-MM-dd').format(selectedDate!);

    try {
      final response = await supabase
          .from('appointment')
          .select()
          .eq('spa_id', widget.spaId)
          .eq('booking_date', appointmentDate)
          .eq('status', 'Scheduled')
          .or('therapist_id.is.null,therapist_id.eq.${selectedTherapistId ?? 'null'}')
          .not('status', 'eq', 'Cancelled')
          .or(
            'and(booking_start_time.lte.${endTime},booking_end_time.gt.${startTime}), '
            'and(booking_start_time.lt.${endTime},booking_end_time.gte.${startTime})'
          );

      if (response.length > 0) {
        // Get conflicting appointment details
        final conflictingApp = response[0];
        final therapistData = selectedTherapistId != null ? await supabase
            .from('therapist')
            .select('first_name, last_name')
            .eq('therapist_id', conflictingApp['therapist_id'])
            .single() : null;

        String conflictMessage = "Time slot conflict: ";
        conflictMessage += "There is already an appointment scheduled from "
            "${TimeOfDay(hour: int.parse(conflictingApp['booking_start_time'].split(':')[0]), minute: int.parse(conflictingApp['booking_start_time'].split(':')[1])).format(context)} to "
            "${TimeOfDay(hour: int.parse(conflictingApp['booking_end_time'].split(':')[0]), minute: int.parse(conflictingApp['booking_end_time'].split(':')[1])).format(context)}";
        
        if (therapistData != null) {
          conflictMessage += "\nTherapist: ${therapistData['first_name']} ${therapistData['last_name']}";
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(conflictMessage),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      print("Error checking appointment conflicts: $e");
      return false;
    }
  }

  /// Show booking summary dialog
  Future<bool> _showBookingSummary() async {
    final service = services.firstWhere(
      (s) => s['service_id'] == selectedServiceId,
      orElse: () => null,
    );
    final therapist = therapists.firstWhere(
      (t) => t['therapist_id'] == selectedTherapistId,
      orElse: () => null,
    );

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Booking Summary"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _summaryItem("Date", DateFormat('MMM dd, yyyy').format(selectedDate!)),
              _summaryItem("Time", "${selectedStartTime!.format(context)} - ${selectedEndTime!.format(context)}"),
              _summaryItem("Service", "${service?['service_name'] ?? 'N/A'}"),
              _summaryItem("Price", "₱${service?['service_price'] ?? 0}"),
              if (therapist != null)
                _summaryItem("Therapist", "${therapist['first_name']} ${therapist['last_name']}"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Book Now"),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPurple,
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _summaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text("$label:", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Helper for section titles
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkPurple, // Using the darker purple shade
        ),
      ),
    );
  }

  // Helper for Date Selector UI
  Widget _buildDateSelector(DateFormat formatter) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade400),
         color: Colors.grey[50], // Light background
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _selectDate,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate == null
                    ? "Choose a date"
                    : formatter.format(selectedDate!), // Use formatter
                  style: TextStyle(
                    fontSize: 16,
                    color: selectedDate == null ? Colors.grey.shade600 : Colors.black87
                  ),
                ),
                Icon(Icons.calendar_today, color: primaryPurple),
              ],
            ),
          ),
        ),
      ),
    );
  }

 // Helper for Time Slot Selector UI (Row of two time pickers)
  Widget _buildTimeSlotSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildTimePicker(
            label: "Start Time",
            time: selectedStartTime,
            onTap: _selectStartTime,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildTimePicker(
            label: "End Time",
            time: selectedEndTime,
            onTap: _selectEndTime,
            enabled: selectedStartTime != null, // Enable only after start time is chosen
          ),
        ),
      ],
    );
  }

  // Helper for individual Time Picker UI
  Widget _buildTimePicker({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    MaterialLocalizations localizations = MaterialLocalizations.of(context); // For time formatting
    return Container(
       decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: enabled ? Colors.grey.shade400 : Colors.grey.shade300),
         color: enabled ? Colors.grey[50] : Colors.grey[200], // Different color when disabled
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null, // Disable tap if not enabled
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  // Use MaterialLocalizations to format time respecting locale/12-24hr settings
                  time == null ? label : localizations.formatTimeOfDay(time, alwaysUse24HourFormat: false),
                  style: TextStyle(
                    fontSize: 16,
                    color: time == null
                        ? (enabled ? Colors.grey.shade600 : Colors.grey.shade500)
                        : (enabled ? Colors.black87 : Colors.grey.shade600),
                  ),
                ),
                Icon(Icons.access_time, color: enabled ? primaryPurple : Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for Service Dropdown UI
  Widget _buildServiceDropdown() {
    return Container(
      width: double.infinity, // Take full width
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade400),
        color: Colors.grey[50],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedServiceId,
          hint: Text(
            "Choose a Service",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16)
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: primaryPurple),
          style: TextStyle(fontSize: 16, color: Colors.black87), // Default text style for items
          dropdownColor: Colors.white, // Background color of the dropdown menu
          items: services.map<DropdownMenuItem<int>>((service) {
            // Format price for display using intl package
            final priceString = NumberFormat.currency(locale: 'en_PH', symbol: '₱').format(service['service_price'] ?? 0.0);
            return DropdownMenuItem<int>(
              value: service['service_id'],
              child: Text(
                "${service['service_name']} - $priceString", // Combine name and formatted price
                overflow: TextOverflow.ellipsis, // Prevent long text overflow
                style: TextStyle(color: Colors.black87),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                selectedServiceId = value;
              });
            }
          },
        ),
      ),
    );
  }

  // Helper for Therapist Dropdown UI
  Widget _buildTherapistDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade400),
         color: Colors.grey[50],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>( // Use nullable int (int?) for value and items
          value: selectedTherapistId,
          hint: Text(
            "Any Available Therapist", // Descriptive hint
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16)
          ),
          isExpanded: true,
          icon: Icon(Icons.person_outline, color: primaryPurple), // Therapist icon
          style: TextStyle(fontSize: 16, color: Colors.black87),
          dropdownColor: Colors.white,
          // Add the "Any" option explicitly as the first item
          items: [
            DropdownMenuItem<int?>(
              value: null, // Null value represents "Any" or "No Preference"
              child: Text(
                "Any Available Therapist",
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade700),
              ),
            ),
            // Map the fetched therapists to the rest of the dropdown items
            ...therapists.map<DropdownMenuItem<int?>>((therapist) {
              return DropdownMenuItem<int?>(
                value: therapist['therapist_id'],
                child: Text(
                  // Combine first and last name safely, handling potential nulls
                  "${therapist['first_name'] ?? ''} ${therapist['last_name'] ?? ''}".trim(),
                   style: TextStyle(color: Colors.black87),
                ),
              );
            }),
          ],
          onChanged: (value) {
            // Update the selected therapist ID (can be null)
            setState(() {
              selectedTherapistId = value;  // Update to use private variable
            });
            // Remove the _findNextAvailableSlot call
          },
        ),
      ),
    );
  }

  // Helper for the main Booking Button UI
  Widget _buildBookingButton() {
    return SizedBox(
      width: double.infinity, // Make button take full width
      child: ElevatedButton(
        // Disable button when loading, otherwise call _bookAppointment
        onPressed: isLoading ? null : _processBooking,  // Updated to use _processBooking
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple, // Main button color
          foregroundColor: Colors.white, // Text color
          padding: EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // Rounded corners
          ),
          textStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
          elevation: 3, // Subtle shadow
        ).copyWith(
           // Handle disabled state color
           backgroundColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.disabled)) {
                return lightPurple.withOpacity(0.5); // Lighter purple when disabled
              }
              return primaryPurple; // Normal color
            },
          ),
        ),
        child: isLoading
          ? SizedBox( // Show loading indicator when processing
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white, // White spinner on purple background
                strokeWidth: 3,
              ),
            )
          : Text("Confirm Booking"), // Button text
      ),
    );
  }

  // Add this new validation method
  bool _validateSpaHours(TimeOfDay time) {
    if (spaOpeningTime == null || spaClosingTime == null) return true;

    // Convert TimeOfDay to minutes since midnight for easier comparison
    int timeInMinutes = time.hour * 60 + time.minute;
    int openingInMinutes = spaOpeningTime!.hour * 60 + spaOpeningTime!.minute;
    int closingInMinutes = spaClosingTime!.hour * 60 + spaClosingTime!.minute;

    return timeInMinutes >= openingInMinutes && timeInMinutes <= closingInMinutes;
  }

  // Update the existing _validateBooking method
  bool _validateBooking() {
    if (selectedDate == null) {
      _showError("Please select a date.");
      return false;
    }

    // Validate date is not in the past
    if (selectedDate!.isBefore(DateTime.now().subtract(Duration(days: 1)))) {
      _showError("Cannot book appointments for past dates.");
      return false;
    }

    if (selectedStartTime == null || selectedEndTime == null) {
      _showError("Please select both start and end times.");
      return false;
    }

    // Convert times to DateTime for comparison
    final now = DateTime.now();
    final startDateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedStartTime!.hour,
      selectedStartTime!.minute,
    );

    // If booking for today, ensure time is in the future
    if (selectedDate!.day == now.day &&
        selectedDate!.month == now.month &&
        selectedDate!.year == now.year &&
        startDateTime.isBefore(now)) {
      _showError("Cannot book appointments for past times.");
      return false;
    }

    if (selectedServiceId == null) {
      _showError("Please select a service.");
      return false;
    }

    // Add spa hours validation
    if (spaOpeningTime != null && spaClosingTime != null) {
      if (!_validateSpaHours(selectedStartTime!) || !_validateSpaHours(selectedEndTime!)) {
        _showError(
          "Booking time must be within spa operating hours: "
          "${spaOpeningTime!.format(context)} - ${spaClosingTime!.format(context)}"
        );
        return false;
      }
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormatter = DateFormat('EEE, MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.clientIdForBooking == null
              ? "Book Your Appointment"
              : "Book Appointment for Client",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: primaryPurple,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Select Date"),
              _buildDateSelector(dateFormatter),
              SizedBox(height: 20),

              _buildSectionTitle("Select Time Slot"),
              _buildTimeSlotSelector(),
              SizedBox(height: 20),

              _buildSectionTitle("Select Service"),
              _buildServiceDropdown(),
              SizedBox(height: 20),

              _buildSectionTitle("Select Preferred Therapist (Optional)"),
              _buildTherapistDropdown(),
              SizedBox(height: 30),

              _buildBookingButton(),
            ],
          ),
        ),
      ),
    );
  }
}