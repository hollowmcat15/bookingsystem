import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminViewCommission extends StatefulWidget {
  const AdminViewCommission({super.key});

  @override
  _AdminViewCommissionState createState() => _AdminViewCommissionState();
}

class _AdminViewCommissionState extends State<AdminViewCommission> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<Map<String, dynamic>> staffCommissions = [];

  @override
  void initState() {
    super.initState();
    _fetchCommissions();
  }

  Future<void> _fetchCommissions() async {
    try {
      setState(() => _isLoading = true);
      
      final response = await supabase
          .from('staff')
          .select('''
            staff_id,
            first_name,
            last_name,
            commission_percentage,
            role,
            spa:spa_id (
              spa_name
            )
          ''')
          .eq('role', 'Therapist');  // Keep only the therapist filter

      setState(() {
        staffCommissions = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading commissions: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Staff Commissions')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchCommissions,
              child: ListView.builder(
                itemCount: staffCommissions.length,
                itemBuilder: (context, index) {
                  final staff = staffCommissions[index];
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text('${staff['first_name']} ${staff['last_name']}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Role: ${staff['role']}'),
                          Text('Spa: ${staff['spa']?['spa_name'] ?? 'Not assigned'}'),
                        ],
                      ),
                      trailing: Text(
                        '${staff['commission_percentage']}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
