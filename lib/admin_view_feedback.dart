import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminViewFeedback extends StatefulWidget {
  const AdminViewFeedback({super.key});

  @override
  _AdminViewFeedbackState createState() => _AdminViewFeedbackState();
}

class _AdminViewFeedbackState extends State<AdminViewFeedback> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<Map<String, dynamic>> feedbacks = [];

  @override
  void initState() {
    super.initState();
    _fetchFeedback();
  }

  Future<void> _fetchFeedback() async {
    try {
      setState(() => _isLoading = true);
      
      final response = await supabase
          .from('feedback')
          .select('''
            *,
            client:client_id (first_name, last_name),
            spa:spa_id (spa_name),
            service:service_id (service_name)
          ''')
          .order('created_at', ascending: false);

      setState(() {
        feedbacks = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading feedback: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Customer Feedback'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchFeedback,
              child: ListView.builder(
                itemCount: feedbacks.length,
                itemBuilder: (context, index) {
                  final feedback = feedbacks[index];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  feedback['feedback_title'],
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Row(
                                children: List.generate(
                                  feedback['rating'],
                                  (index) => Icon(Icons.star, color: Colors.amber),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text('By: ${feedback['client']['first_name']} ${feedback['client']['last_name']}'),
                          Text('Spa: ${feedback['spa']['spa_name']}'),
                          Text('Service: ${feedback['service']['service_name']}'),
                          SizedBox(height: 8),
                          Text(feedback['feedback_text']),
                          if (feedback['response_text'] != null) ...[
                            Divider(),
                            Text(
                              'Response:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(feedback['response_text']),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
