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
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // State variables
  Map<String, dynamic>? _spa;
  List<dynamic> _services = [];
  List<dynamic> _reviews = [];
  bool _userHasReview = false;
  int? _userReviewId;
  bool _isLoading = true;
  int? _currentClientId;
  Map<int, bool> _bookmarkedServices = {};  // Track bookmarked status for each service

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
        _fetchBookmarks(),  // Add this
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
          .select('spa_name, spa_address, spa_phonenumber, description, image_url, opening_time, closing_time')  // Add times
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

  /// Fetch bookmarks
  Future<void> _fetchBookmarks() async {
    final clientId = _currentClientId;
    if (clientId == null) return;

    try {
      final response = await _supabase
          .from('bookmark')
          .select('service_id')
          .eq('client_id', clientId.toString()); // Convert to string for comparison

      if (mounted) {
        setState(() {
          _bookmarkedServices = Map.fromEntries(
            response.map<MapEntry<int, bool>>((bookmark) => 
              MapEntry(bookmark['service_id'], true)
            ),
          );
        });
      }
    } catch (e) {
      print('Error fetching bookmarks: $e');
    }
  }

  /// Submit a review
  Future<void> _submitReview(int rating, String feedbackTitle, String feedbackText, int serviceId) async {
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
          .eq('client_id', clientId)
          .single();
      
      final clientName = "${clientData['first_name']} ${clientData['last_name']}";

      // Submit the feedback
      await _supabase.from('feedback').insert({
        'client_id': clientId,
        'spa_id': widget.spaId,
        'service_id': serviceId,
        'feedback_title': feedbackTitle,
        'feedback_text': feedbackText,
        'rating': rating,
        'created_at': DateTime.now().toIso8601String(),
      });

      await _fetchReviews();
      _showSuccessSnackBar("Review submitted successfully!");
    } on PostgrestException catch (error) {
      _showErrorSnackBar('Failed to submit review: ${error.message}');
    }
  }

  /// Toggle bookmark status
  Future<void> _toggleBookmark(int serviceId) async {
    final clientId = _currentClientId;
    if (clientId == null) {
      _showLoginPrompt();
      return;
    }

    try {
      final isCurrentlyBookmarked = _bookmarkedServices[serviceId] ?? false;

      if (isCurrentlyBookmarked) {
        // Remove bookmark
        await _supabase
            .from('bookmark')
            .delete()
            .eq('client_id', clientId.toString()) // Convert to string
            .eq('service_id', serviceId);
      } else {
        // Add bookmark
        await _supabase.from('bookmark').insert({
          'client_id': clientId.toString(), // Convert to string
          'service_id': serviceId,
        });
      }

      if (mounted) {
        setState(() {
          _bookmarkedServices[serviceId] = !isCurrentlyBookmarked;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCurrentlyBookmarked 
            ? 'Service removed from bookmarks' 
            : 'Service added to bookmarks'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Error updating bookmark: ${e.toString()}');
    }
  }

  /// Calculate average rating
  double _calculateAverageRating() {
    if (_reviews.isEmpty) return 0.0;
    double total = _reviews.fold(0, (sum, review) => sum + (review['rating'] as int));
    return double.parse((total / _reviews.length).toStringAsFixed(1));
  }

  /// Show review submission dialog
  void _showReviewDialog() {
    // Prevent multiple reviews
    if (_userHasReview) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have already submitted a review'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int selectedRating = 5;
    int? selectedServiceId;
    TextEditingController titleController = TextEditingController();
    TextEditingController reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 400, // Fixed maximum width
                  maxHeight: MediaQuery.of(context).size.height * 0.8, // 80% of screen height
                ),
                child: AlertDialog(
                  contentPadding: EdgeInsets.all(24),
                  title: Text("Leave a Review"),
                  content: Container(
                    width: 400, // Fixed width
                    child: SingleChildScrollView(
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
                          ),
                          SizedBox(height: 16),
                          TextField(
                            controller: titleController,
                            decoration: InputDecoration(labelText: "Review Title"),
                          ),
                          TextField(
                            controller: reviewController,
                            decoration: InputDecoration(labelText: "Write your review..."),
                            maxLines: 3,
                          ),
                          SizedBox(height: 24),
                          Text(
                            "Rate your experience:",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 8),
                          // Google Play Store style rating
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedRating = index + 1;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    index < selectedRating 
                                      ? Icons.star_rate_rounded 
                                      : Icons.star_border_rounded,
                                    size: 40,
                                    color: index < selectedRating 
                                      ? Colors.amber
                                      : Colors.grey[400],
                                  ),
                                ),
                              );
                            }),
                          ),
                          Text(
                            _getRatingDescription(selectedRating),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (titleController.text.isEmpty || 
                            reviewController.text.isEmpty || 
                            selectedServiceId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Please fill in all fields"),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        _submitReview(
                          selectedRating,
                          titleController.text,
                          reviewController.text,
                          selectedServiceId!,
                        );
                        Navigator.pop(context);
                      },
                      child: Text("Submit"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getRatingDescription(int rating) {
    switch (rating) {
      case 1:
        return "Poor";
      case 2:
        return "Fair";
      case 3:
        return "Good";
      case 4:
        return "Very Good";
      case 5:
        return "Excellent";
      default:
        return "";
    }
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

  // Update the services section in the build method
  Widget _buildServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Services",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        _services.isEmpty
            ? Text("No services available")
            : Column(
                children: _services.map((service) {
                  final isBookmarked = _bookmarkedServices[service['service_id']] ?? false;
                  return ListTile(
                    title: Text(service['service_name']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₱${service['service_price']}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(
                            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: isBookmarked ? Colors.blue : null,
                          ),
                          onPressed: () => _toggleBookmark(service['service_id']),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  // Update the build method to use the new services section
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
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 16, color: Colors.grey[700]),
                                SizedBox(width: 8),
                                Text(
                                  "Hours: ${_formatTime(_spa?['opening_time'])} - ${_formatTime(_spa?['closing_time'])}",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),

                            // Services Section
                            _buildServicesSection(), // Replace the old services section
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
                                                      review['client_id'].toString() == _currentClientId.toString();
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

  // Add this helper method to format time
  String _formatTime(String? timeString) {
    if (timeString == null) return 'N/A';
    try {
      final parts = timeString.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    } catch (e) {
      return timeString;
    }
  }
}