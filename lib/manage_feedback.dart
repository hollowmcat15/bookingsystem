import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchFeedback();
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
                      'Manager Response:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(feedback['response_text']),
                  ],
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