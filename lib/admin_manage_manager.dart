import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminManageManager extends StatefulWidget {
  const AdminManageManager({super.key});

  @override
  _AdminManageManagerState createState() => _AdminManageManagerState();
}

class _AdminManageManagerState extends State<AdminManageManager> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> managers = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchManagers();
  }

  Future<void> _fetchManagers() async {
    try {
      setState(() => _isLoading = true);
      
      // Fetch managers with their spa details
      final response = await supabase
          .from('staff')
          .select('''
            staff_id,
            first_name,
            last_name,
            email,
            phonenumber,
            spa:spa_id (
              spa_id,
              spa_name,
              spa_address,
              spa_phonenumber
            )
          ''')
          .eq('role', 'Manager');

      setState(() {
        managers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading managers: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View Managers'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      ElevatedButton(
                        onPressed: _fetchManagers,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchManagers,
                  child: managers.isEmpty
                      ? Center(child: Text('No managers found'))
                      : ListView.builder(
                          itemCount: managers.length,
                          itemBuilder: (context, index) {
                            final manager = managers[index];
                            final spa = manager['spa'];
                            
                            return Card(
                              margin: EdgeInsets.all(8),
                              child: ExpansionTile(
                                title: Text('${manager['first_name']} ${manager['last_name']}'),
                                subtitle: Text(manager['email']),
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Phone: ${manager['phonenumber']}'),
                                        if (spa != null) ...[
                                          SizedBox(height: 16),
                                          Text('Managing Spa:',
                                              style: TextStyle(fontWeight: FontWeight.bold)),
                                          SizedBox(height: 8),
                                          Text(spa['spa_name']),
                                          Text(spa['spa_address']),
                                          Text('Phone: ${spa['spa_phonenumber']}'),
                                        ] else
                                          Text('\nNo spa currently assigned',
                                              style: TextStyle(fontStyle: FontStyle.italic)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
