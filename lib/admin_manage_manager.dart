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
  List<Map<String, dynamic>> allSpas = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchManagers();
    _fetchSpas();
  }

  Future<void> _fetchManagers() async {
    try {
      setState(() => _isLoading = true);
      final response = await supabase
          .from('staff')
          .select('*, spa(*)')
          .eq('role', 'Manager');
      setState(() {
        managers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSpas() async {
    try {
      final response = await supabase.from('spa').select();
      setState(() {
        allSpas = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching spas: $e');
    }
  }

  Future<void> _assignSpaToManager(int managerId, int? spaId) async {
    try {
      await supabase
          .from('staff')
          .update({'spa_id': spaId})
          .eq('staff_id', managerId);
      if (mounted) {
        _fetchManagers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning spa: $e')),
        );
      }
    }
  }

  Future<void> _deleteManager(int managerId) async {
    try {
      await supabase
          .from('staff')
          .delete()
          .eq('staff_id', managerId);
      _fetchManagers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting manager: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Managers'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                  itemCount: managers.length,
                  itemBuilder: (context, index) {
                    final manager = managers[index];
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
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButton<int?>(
                                        value: manager['spa_id'],
                                        hint: Text('Assign Spa'),
                                        isExpanded: true,
                                        items: [
                                          DropdownMenuItem<int?>(
                                            value: null,
                                            child: Text('No Spa Assigned'),
                                          ),
                                          ...allSpas.map((spa) {
                                            return DropdownMenuItem<int?>(
                                              value: spa['spa_id'],
                                              child: Text(spa['spa_name']),
                                            );
                                          }).toList(),
                                        ],
                                        onChanged: (spaId) {
                                          _assignSpaToManager(manager['staff_id'], spaId);
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text('Delete Manager'),
                                            content: Text('Are you sure you want to delete this manager?'),
                                            actions: [
                                              TextButton(
                                                child: Text('Cancel'),
                                                onPressed: () => Navigator.pop(context),
                                              ),
                                              TextButton(
                                                child: Text('Delete'),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _deleteManager(manager['staff_id']);
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
