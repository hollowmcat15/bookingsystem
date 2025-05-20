import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'book_appointment.dart';
import 'manage_notifications.dart';

class SpaDetails extends StatefulWidget {
  final int spaId;
  const SpaDetails({Key? key, required this.spaId}) : super(key: key);

  @override
  _SpaDetailsState createState() => _SpaDetailsState();
}

class _SpaDetailsState extends State<SpaDetails> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // State variables
  Map<String, dynamic>? _spa;
  List<dynamic> _services = [];
  List<dynamic> _reviews = [];
  bool _userHasReview = false;
  int? _userReviewId;
  bool _isLoading = true;
  int? _currentClientId;

  @override
  void initState() {
    super.initState();
    _fetchAllDetails();
  }

  /// Fetch all spa-related details in parallel
  Future<void> _fetchAllDetails() async {
    try {
      // First, check if user is logged in and get client_id
      await _fetchCurrentClientId();
      
      // Then fetch all other data
      await Future.wait([
        _fetchSpaDetails(),
        _fetchServices(),
        _fetchReviews(),
      ]);
    } catch (e) {
      _showErrorSnackBar('Failed to load spa details: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Get current client_id based on logged in user
  Future<void> _fetchCurrentClientId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final client = await _supabase
          .from('client')
          .select('client_id')
          .eq('email', user.email!)
          .maybeSingle();

      if (client != null && mounted) {
        setState(() {
          _currentClientId = client['client_id'];
        });
      }
    } catch (e) {
      // Silently handle - user might not have a client profile yet
    }
  }

  /// Fetch spa details with improved error handling
  Future<void> _fetchSpaDetails() async {
    try {
      final response = await _supabase
          .from('spa')
          .select('spa_name, spa_address, spa_phonenumber, description, image_url')
          .eq('spa_id', widget.spaId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _spa = response;
        });
      }
    } on PostgrestException catch (error) {
      _showErrorSnackBar('Error fetching spa details: ${error.message}');
    }
  }

  /// Fetch available services
  Future<void> _fetchServices() async {
    try {
      final response = await _supabase
          .from('service')
          .select('service_id, service_name, service_price')
          .eq('spa_id', widget.spaId);
      
      if (mounted) {
        setState(() {
          _services = response;
        });
      }
    } on PostgrestException catch (error) {
      _showErrorSnackBar('Error fetching services: ${error.message}');
    }
  }

  /// Fetch reviews with detailed information
  // Add this to your _fetchReviews method to join with service table
Future<void> _fetchReviews() async {
  try {
    final response = await _supabase
        .from('feedback')
        .select('feedback_id, client_id, feedback_title, feedback_text, rating, created_at, service_id, service!inner(service_name), response_text')
        .eq('spa_id', widget.spaId)
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        _reviews = response;
        
        // Check if current user has a review
        if (_currentClientId != null) {
          for (var review in _reviews) {
            if (review['client_id'] == _currentClientId) {
              _userHasReview = true;
              _userReviewId = review['feedback_id'];
              break;
            }
          }
        }
      });
    }
  } on PostgrestException catch (error) {
    _showErrorSnackBar('Error fetching reviews: ${error.message}');
  }
}

  /// Submit a review
  Future<void> _submitReview(int rating, String feedbackTitle, String feedbackText, int serviceId) async {
    // Store _currentClientId in a local variable to enable type promotion
    final clientId = _currentClientId;
    if (clientId == null) {
      _showErrorSnackBar("You must be logged in to leave a review.");
      return;
    }

    try {
      // Get spa's manager ID and client name before submitting feedback
      final spaData = await _supabase
          .from('spa')
          .select('manager_id')
          .eq('spa_id', widget.spaId)
          .single();

      final clientData = await _supabase
          .from('client')
          .select('first_name, last_name')
          .eq('client_id', clientId)  // Use local variable
          .single();
      
      final clientName = "${clientData['first_name']} ${clientData['last_name']}";

      // Submit the feedback
      await _supabase.from('feedback').insert({
        'client_id': clientId,  // Use local variable
        'spa_id': widget.spaId,
        'service_id': serviceId,
        'feedback_title': feedbackTitle,
        'feedback_text': feedbackText,
        'rating': rating,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Send notification to manager
      await NotificationManager.createFeedbackNotification(
        managerId: spaData['manager_id']?.toString() ?? '',  // Add null safety
        clientName: clientName,
        feedbackSummary: feedbackText,
      );

      await _fetchReviews();
      _showSuccessSnackBar("Review submitted successfully!");
    } on PostgrestException catch (error) {
      _showErrorSnackBar('Failed to submit review: ${error.message}');
    }
  }

  /// Delete a review with confirmation
  Future<void> _deleteReview(int reviewId) async {
    try {
      final confirmDelete = await _showDeleteConfirmation();
      if (!confirmDelete) return;

      await _supabase.from('feedback').delete().eq('feedback_id', reviewId);
      
      setState(() {
        _userHasReview = false;
        _userReviewId = null;
      });
      
      await _fetchReviews();
      _showSuccessSnackBar("Review deleted successfully!");
    } on PostgrestException catch (error) {
      _showErrorSnackBar('Failed to delete review: ${error.message}');
    }
  }

  /// Calculate average rating
  double _calculateAverageRating() {
    if (_reviews.isEmpty) return 0.0;
    double total = _reviews.fold(0, (sum, review) => sum + (review['rating'] as int));
    return double.parse((total / _reviews.length).toStringAsFixed(1));
  }

  /// Show delete confirmation dialog
  Future<bool> _showDeleteConfirmation() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Confirm Delete"),
            content: Text("Are you sure you want to delete your review?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("Delete"),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Show review submission dialog
  void _showReviewDialog() {
  int selectedRating = 5;
  int? selectedServiceId;
  TextEditingController titleController = TextEditingController();
  TextEditingController reviewController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text("Leave a Review"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Service selection dropdown
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(labelText: "Select a Service"),
                    value: selectedServiceId,
                    hint: Text("Select a service to review"),
                    items: _services.map((service) {
                      return DropdownMenuItem<int>(
                        value: service['service_id'],
                        child: Text(service['service_name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedServiceId = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? "Please select a service" : null,
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: "Review Title"),
                  ),
                  TextField(
                    controller: reviewController,
                    decoration: InputDecoration(labelText: "Write your review..."),
                    maxLines: 3,
                  ),
                  SizedBox(height: 10),
                  Text("Select Rating:"),
                  DropdownButton<int>(
                    value: selectedRating,
                    items: [1, 2, 3, 4, 5].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text("$value ★"),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedRating = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty && 
                      reviewController.text.isNotEmpty && 
                      selectedServiceId != null) {
                    _submitReview(
                      selectedRating, 
                      titleController.text, 
                      reviewController.text,
                      selectedServiceId!
                    );
                    Navigator.pop(context);
                  } else {
                    _showErrorSnackBar("Please fill in all fields and select a service");
                  }
                },
                child: Text("Submit"),
              ),
            ],
          );
        },
      );
    },
  );
}

  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Show success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Show login prompt dialog
  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Login Required"),
        content: Text("You need to be logged in to leave a review."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_spa?['spa_name'] ?? "Spa Details"),
        actions: [
          // Book Now action with icon and text
          TextButton.icon(
            icon: Icon(Icons.calendar_today, color: const Color.fromARGB(255, 0, 0, 0)),
            label: Text(
              "Book Now", 
              style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0)),
            ),
            onPressed: () async {  // Make onPressed async
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookAppointment(spaId: widget.spaId),
                ),
              );

              // Show success message if booking was successful
              if (result == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Appointment booked successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
                // Refresh spa details
                _fetchAllDetails();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _spa == null
              ? Center(child: Text("Spa not found"))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Spa Image
                      _spa?['image_url'] != null
                          ? Image.network(
                              _spa!['image_url'],
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: double.infinity,
                                  height: 200,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.image_not_supported, size: 80, color: Colors.grey[700]),
                                );
                              },
                            )
                          : Container(
                              width: double.infinity,
                              height: 200,
                              color: Colors.grey[300],
                              child: Icon(Icons.image, size: 80, color: Colors.grey[700]),
                            ),

                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Spa Description
                            Text(
                              _spa?['description'] ?? "No description available",
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 16),

                            // Contact Information
                            Text(
                              "Contact",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Address: ${_spa?['spa_address'] ?? 'N/A'}",
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              "Phone: ${_spa?['spa_phonenumber'] ?? 'N/A'}",
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 16),

                            // Services Section
                            Text(
                              "Services",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            _services.isEmpty
                                ? Text("No services available")
                                : Column(
                                    children: _services.map((service) {
                                      return ListTile(
                                        title: Text(service['service_name']),
                                        trailing: Text(
                                          '₱${service['service_price']}',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                            SizedBox(height: 16),

                            // Ratings & Reviews Section
                            Text(
                              "Ratings & Reviews",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),

                            // Average Rating
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 20),
                                SizedBox(width: 5),
                                Text(
                                  "${_calculateAverageRating()} ★ (${_reviews.length} reviews)",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),

                            // Reviews List
                            _reviews.isEmpty
                                ? Text("No reviews yet.")
                                : Column(
                                    children: _reviews.map((review) {
                                      bool isUserReview = _currentClientId != null && 
                                                          review['client_id'] == _currentClientId;
                                      return Card(
                                        margin: EdgeInsets.symmetric(vertical: 8),
                                        elevation: 3,
                                        child: ListTile(
                                          title: Text(
                                            review['feedback_title'],
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: List.generate(
                                                  review['rating'],
                                                  (index) => Icon(Icons.star, color: Colors.amber, size: 16),
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(review['feedback_text']),
                                              Text(
                                                "Service: ${review['service']['service_name']}",
                                                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                              ),
                                              Text(
                                                "Posted on: ${review['created_at'].split('T')[0]}",
                                                style: TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                              if (review['response_text'] != null && review['response_text'].toString().isNotEmpty) ...[
                                                SizedBox(height: 8),
                                                Container(
                                                  padding: EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[100],
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        "Manager's Response:",
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                          color: Colors.grey[700],
                                                        ),
                                                      ),
                                                      SizedBox(height: 4),
                                                      Text(
                                                        review['response_text'],
                                                        style: TextStyle(fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          trailing: isUserReview
                                              ? PopupMenuButton<String>(
                                                  onSelected: (value) {
                                                    if (value == "delete") _deleteReview(review['feedback_id']);
                                                  },
                                                  itemBuilder: (context) => [
                                                    PopupMenuItem<String>(
                                                      value: "delete",
                                                      child: Text("Delete"),
                                                    ),
                                                  ],
                                                )
                                              : null,
                                        ),
                                      );
                                    }).toList(),
                                  ),

                            SizedBox(height: 10),

                            // Add Review Button (greyed out if user already has a review)
                            Center(
                              child: ElevatedButton(
                                onPressed: _currentClientId == null 
                                    ? _showLoginPrompt 
                                    : (_userHasReview) 
                                        ? null  // Disabled when user already has a review
                                        : _showReviewDialog,
                                style: ElevatedButton.styleFrom(
                                  // This will give a greyed out appearance when disabled
                                  disabledBackgroundColor: Colors.grey[300],
                                  disabledForegroundColor: Colors.grey[600],
                                ),
                                child: Text(_userHasReview ? "Already Reviewed" : "Add Review"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}