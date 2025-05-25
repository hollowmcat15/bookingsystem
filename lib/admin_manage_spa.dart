import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminManageSpa extends StatefulWidget {
  const AdminManageSpa({super.key});

  @override
  _AdminManageSpaState createState() => _AdminManageSpaState();
}

class _AdminManageSpaState extends State<AdminManageSpa> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> spas = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSpas();
  }

  Future<void> _fetchSpas() async {
    try {
      setState(() => _isLoading = true);
      final response = await supabase
          .from('spa')
          .select('''
            *,
            manager:manager_id (
              staff_id,
              first_name,
              last_name,
              email,
              phonenumber
            ),
            service(
              service_id,
              service_name,
              service_price
            )
          ''')
          .order('created_at');

      setState(() {
        spas = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _approveSpa(int spaId, bool approved) async {
    try {
      await supabase
          .from('spa')
          .update({'approved': approved})
          .eq('spa_id', spaId);
      
      _fetchSpas(); // Refresh the list
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approved ? 'Spa approved' : 'Spa rejected')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating spa: ${e.toString()}')),
      );
    }
  }

  Widget _buildServicesList(List<Map<String, dynamic>> services) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Services:', style: TextStyle(fontWeight: FontWeight.bold)),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return ListTile(
              title: Text(service['service_name']),
              subtitle: Text(
                'Price: ₱${service['service_price'].toStringAsFixed(2)}',
              ),
              dense: true,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Spas'),
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
                        onPressed: _fetchSpas,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchSpas,
                  child: spas.isEmpty
                      ? Center(child: Text('No spas found'))
                      : ListView.builder(
                          itemCount: spas.length,
                          itemBuilder: (context, index) {
                            final spa = spas[index];
                            final manager = spa['staff'];
                            final services = List<Map<String, dynamic>>.from(spa['service']);
                            final bool isApproved = spa['approved'] ?? false;
                            
                            return Card(
                              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ExpansionTile(
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        spa['spa_name'],
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (!isApproved)
                                      Chip(
                                        label: Text(
                                          'Pending',
                                          style: TextStyle(
                                            color: Colors.orange[900],
                                            fontSize: 12,
                                          ),
                                        ),
                                        backgroundColor: Colors.orange[100],
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  spa['spa_address'],
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildInfoRow('Manager', '${manager?['first_name'] ?? 'No'} ${manager?['last_name'] ?? 'Manager'}'),
                                        _buildInfoRow('Phone', spa['spa_phonenumber']),
                                        _buildInfoRow('Postal Code', spa['postal_code']),
                                        _buildInfoRow('Description', spa['description']),
                                        SizedBox(height: 16),
                                        if (spa['image_url'] != null)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              spa['image_url'],
                                              height: 150,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Services',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Divider(),
                                        _buildServicesList(services),
                                        if (!isApproved) ...[
                                          SizedBox(height: 16),
                                          Divider(),
                                          Padding(
                                            padding: EdgeInsets.symmetric(vertical: 16),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: [
                                                ElevatedButton.icon(
                                                  icon: Icon(Icons.check, color: Colors.white),
                                                  label: Text(
                                                    'Approve',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green[600],
                                                    foregroundColor: Colors.white,
                                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                  ),
                                                  onPressed: () => _approveSpa(spa['spa_id'], true),
                                                ),
                                                ElevatedButton.icon(
                                                  icon: Icon(Icons.close, color: Colors.white),
                                                  label: Text(
                                                    'Reject',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red[600],
                                                    foregroundColor: Colors.white,
                                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                  ),
                                                  onPressed: () => _approveSpa(spa['spa_id'], false),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
