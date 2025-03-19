import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookAppointment extends StatefulWidget {
  final int serviceId;
  const BookAppointment({Key? key, required this.serviceId}) : super(key: key);

  @override
  _BookAppointmentState createState() => _BookAppointmentState();
}

class _BookAppointmentState extends State<BookAppointment> {
  final SupabaseClient supabase = Supabase.instance.client;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? clientId;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchClientId();
  }

  /// ✅ Fetch logged-in client's ID
  Future<void> _fetchClientId() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final response = await supabase
          .from('client')
          .select('client_id')
          .eq('email', user.email!)
          .single();
      setState(() {
        clientId = response['client_id'].toString();
      });
    }
  }

  /// ✅ Pick a date
  void _selectDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 30)),
    );
    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  /// ✅ Pick a time
  void _selectTime() async {
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() {
        selectedTime = pickedTime;
      });
    }
  }

  /// ✅ Book appointment after checking availability
  void _bookAppointment() async {
    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a date and time.")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    String formattedDate = "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";
    String formattedTime = "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00";

    // ✅ Check slot availability
    final checkSlot = await supabase
        .from('appointment')
        .select('appointment_id')
        .eq('appointment_date', "$formattedDate $formattedTime")
        .eq('service_id', widget.serviceId)
        .maybeSingle();

    if (checkSlot != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Selected slot is already booked. Choose a different time.")),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    // ✅ Insert new appointment
    final response = await supabase.from('appointment').insert({
      'client_id': clientId,
      'service_id': widget.serviceId,
      'appointment_date': "$formattedDate $formattedTime",
      'status': 'Pending',
      'created_at': DateTime.now().toIso8601String(),
    }).select();

    setState(() {
      isLoading = false;
    });

    if (response != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Appointment booked successfully!")),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to book appointment.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Book Appointment")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Select Date:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _selectDate,
                  child: Text(selectedDate == null ? "Pick a Date" : "${selectedDate!.toLocal()}".split(" ")[0]),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text("Select Time:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _selectTime,
                  child: Text(selectedTime == null ? "Pick a Time" : selectedTime!.format(context)),
                ),
              ],
            ),
            SizedBox(height: 24),
            isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _bookAppointment,
                    child: Text("Confirm Booking"),
                  ),
          ],
        ),
      ),
    );
  }
}
