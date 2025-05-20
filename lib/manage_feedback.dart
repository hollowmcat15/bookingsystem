import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'manage_notifications.dart';  // Add this import

class ManageFeedback extends StatefulWidget {
  final int spaId;

  const ManageFeedback({
    Key? key,
    required this.spaId,
  }) : super(key: key);

  @override
  _ManageFeedbackState createState() => _ManageFeedbackState();
}

class _ManageFeedbackState extends State<ManageFeedback> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _feedbackList = [];
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchFeedback();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _fetchFeedback() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch feedback for the spa with client information
      final response = await supabase
          .from('feedback')
          .select('''
            *,
            client (
              first_name,
              last_name
            ),
            service (
              service_name
            )
          ''')
          .eq('spa_id', widget.spaId)
          .order('created_at', ascending: false);

      setState(() {
        _feedbackList = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading feedback: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitReply(int feedbackId) async {
    if (_replyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply cannot be empty')),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Get the manager's ID from the authenticated user
      final User? user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get manager ID from the managers table
      final managerData = await supabase
          .from('manager')
          .select('manager_id')
          .eq('auth_id', user.id)
          .single();

      // Update feedback with response
      await supabase
          .from('feedback')
          .update({
            'response_text': _replyController.text,
            'manager_id': managerData['manager_id'],
            // 'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('feedback_id', feedbackId);

      // After successful reply, notify the manager
      final feedbackData = await supabase
          .from('feedback')
          .select('*, client(*), spa(*)')
          .eq('feedback_id', feedbackId)
          .single();

      // After successful reply, notify the client about the response
      if (feedbackData != null) {
        await NotificationManager.createFeedbackNotification(
          managerId: managerData['manager_id'].toString(),
          clientName: '${feedbackData['client']['first_name']} ${feedbackData['client']['last_name']}',
        );
      }

      // Clear the text field and refresh the feedback list
      _replyController.clear();
      _fetchFeedback();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply submitted successfully')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to submit reply: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit reply: ${e.toString()}')),
      );
    }
  }

  void _showReplyDialog(BuildContext context, Map<String, dynamic> feedback) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reply to Feedback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Original Feedback:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(feedback['feedback_text'] ?? ''),
              SizedBox(height: 16),
              TextField(
                controller: _replyController,
                decoration: InputDecoration(
                  hintText: 'Type your reply here...',
                  border: OutlineInputBorder(),
                ),
                minLines: 3,
                maxLines: 5,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _replyController.clear();
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _submitReply(feedback['feedback_id']);
              },
              child: Text('Submit Reply'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    final clientName = feedback['client'] != null
        ? "${feedback['client']['first_name']} ${feedback['client']['last_name']}"
        : "Unknown Client";
    
    final serviceName = feedback['service'] != null
        ? feedback['service']['service_name']
        : "Unknown Service";

    final formattedDate = feedback['created_at'] != null
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(feedback['created_at']))
        : "Unknown Date";

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        clientName.isNotEmpty ? clientName[0] : '?',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clientName,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          formattedDate,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(serviceName),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          SizedBox(width: 4),
                          Text('${feedback['rating'] ?? 0}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              feedback['feedback_title'] ?? 'No Title',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(feedback['feedback_text'] ?? 'No feedback text provided'),
            SizedBox(height: 16),
            if (feedback['response_text'] != null && feedback['response_text'].isNotEmpty)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Reply:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(feedback['response_text']),
                  ],
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: Icon(Icons.reply),
                  label: Text('Reply'),
                  onPressed: () {
                    _replyController.text = feedback['response_text'] ?? '';
                    _showReplyDialog(context, feedback);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Feedback'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchFeedback,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
              : _feedbackList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.feedback_outlined, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No feedback available',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _feedbackList.length,
                      itemBuilder: (context, index) {
                        return _buildFeedbackCard(_feedbackList[index]);
                      },
                    ),
    );
  }
}