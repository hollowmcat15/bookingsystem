import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'book_appointment.dart';

class SpaDetails extends StatefulWidget {
  final int spaId;
  const SpaDetails({Key? key, required this.spaId}) : super(key: key);

  @override
  _SpaDetailsState createState() => _SpaDetailsState();
}

class _SpaDetailsState extends State<SpaDetails> {
  final SupabaseClient supabase = Supabase.instance.client;
  Map<String, dynamic>? spa;
  List<dynamic> services = [];
  List<dynamic> reviews = [];

  @override
  void initState() {
    super.initState();
    _fetchSpaDetails();
    _fetchServices();
    _fetchReviews();
  }

  /// ✅ Fetch spa details
  Future<void> _fetchSpaDetails() async {
    final response = await supabase
        .from('spa')
        .select('spa_name, spa_address, description')
        .eq('spa_id', widget.spaId)
        .single();

    setState(() {
      spa = response;
    });
  }

  /// ✅ Fetch services offered at this spa
  Future<void> _fetchServices() async {
    final response = await supabase
        .from('service')
        .select('service_id, service_name, service_price')
        .eq('spa_id', widget.spaId);

    setState(() {
      services = response;
    });
  }

  /// ✅ Fetch reviews for this spa
  Future<void> _fetchReviews() async {
    final response = await supabase
        .from('feedback')
        .select('feedback_text, created_at')
        .eq('spa_id', widget.spaId)
        .order('created_at', ascending: false);

    setState(() {
      reviews = response;
    });
  }

  /// ✅ Allows clients to submit a review
  void _submitReview(String feedbackText) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("You must be logged in to leave a review.")));
      return;
    }

    final client = await supabase.from('client').select('client_id').eq('email', user.email!).single();

    await supabase.from('feedback').insert({
      'client_id': client['client_id'],
      'spa_id': widget.spaId,
      'feedback_text': feedbackText,
      'created_at': DateTime.now().toIso8601String(),
    });

    _fetchReviews(); // Refresh reviews
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(spa?['spa_name'] ?? "Loading...")),
      body: spa == null
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(spa!['description'], style: TextStyle(fontSize: 16)),
                  SizedBox(height: 16),
                  Text("Location: ${spa!['spa_address']}"),
                  SizedBox(height: 16),
                  Text("Available Services", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  services.isEmpty
                      ? Text("No services available.")
                      : Expanded(
                          child: ListView.builder(
                            itemCount: services.length,
                            itemBuilder: (context, index) {
                              final service = services[index];
                              return ListTile(
                                title: Text(service['service_name']),
                                subtitle: Text("Price: PHP ${service['service_price']}"),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => BookAppointment(serviceId: service['service_id']),
                                      ),
                                    );
                                  },
                                  child: Text("Book"),
                                ),
                              );
                            },
                          ),
                        ),
                  SizedBox(height: 16),
                  Text("Client Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  reviews.isEmpty
                      ? Text("No reviews yet.")
                      : Expanded(
                          child: ListView.builder(
                            itemCount: reviews.length,
                            itemBuilder: (context, index) {
                              final review = reviews[index];
                              return ListTile(
                                title: Text(review['feedback_text']),
                                subtitle: Text("Posted on: ${review['created_at']}"),
                              );
                            },
                          ),
                        ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          TextEditingController reviewController = TextEditingController();
                          return AlertDialog(
                            title: Text("Leave a Review"),
                            content: TextField(
                              controller: reviewController,
                              decoration: InputDecoration(hintText: "Write your review here..."),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  _submitReview(reviewController.text);
                                  Navigator.pop(context);
                                },
                                child: Text("Submit"),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Text("Write a Review"),
                  ),
                ],
              ),
            ),
    );
  }
}
