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
            staff!manager_id(*),
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
                'Price: \$${service['service_price'].toStringAsFixed(2)}',
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
        title: Text('View Spas'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                  itemCount: spas.length,
                  itemBuilder: (context, index) {
                    final spa = spas[index];
                    final manager = spa['staff'];
                    final services = List<Map<String, dynamic>>.from(spa['service']);
                    
                    return Card(
                      margin: EdgeInsets.all(8),
                      child: ExpansionTile(
                        title: Text(spa['spa_name']),
                        subtitle: Text(spa['spa_address']),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Manager: ${manager?['first_name'] ?? 'No'} ${manager?['last_name'] ?? 'Manager'}'),
                                Text('Phone: ${spa['spa_phonenumber']}'),
                                Text('Postal Code: ${spa['postal_code']}'),
                                Text('Description: ${spa['description']}'),
                                SizedBox(height: 8),
                                if (spa['image_url'] != null)
                                  Image.network(
                                    spa['image_url'],
                                    height: 100,
                                    width: 100,
                                    fit: BoxFit.cover,
                                  ),
                                SizedBox(height: 16),
                                _buildServicesList(services),
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
