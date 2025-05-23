import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminViewClients extends StatefulWidget {
  @override
  _AdminViewClientsState createState() => _AdminViewClientsState();
}

class _AdminViewClientsState extends State<AdminViewClients> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> clients = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    try {
      setState(() => _isLoading = true);
      final response = await supabase
          .from('client')
          .select()
          .order('created_at');
      
      setState(() {
        clients = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredClients = clients.where((client) {
      final searchLower = _searchQuery.toLowerCase();
      return client['first_name'].toString().toLowerCase().contains(searchLower) ||
             client['last_name'].toString().toLowerCase().contains(searchLower) ||
             client['email'].toString().toLowerCase().contains(searchLower);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('View Clients'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchClients,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Search Clients',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : filteredClients.isEmpty
                      ? Center(child: Text('No clients found'))
                      : ListView.builder(
                          itemCount: filteredClients.length,
                          itemBuilder: (context, index) {
                            final client = filteredClients[index];
                            return Card(
                              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                title: Text('${client['first_name']} ${client['last_name']}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Email: ${client['email']}'),
                                    Text('Phone: ${client['phonenumber'] ?? 'N/A'}'),
                                    Text('Joined: ${DateTime.parse(client['created_at']).toString().split(' ')[0]}'),
                                  ],
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
