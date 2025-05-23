import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'spa_details.dart';
import 'manage_bookings.dart';
import 'profile_page.dart';
import 'login.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class ClientDashboard extends StatefulWidget {
  @override
  _ClientDashboardState createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _spas = [];

  // Add new state variables for filtering
  String _searchQuery = '';
  RangeValues _priceRange = RangeValues(0, 10000);  // Adjust max as needed
  double _minRating = 0;
  Set<String> _selectedServiceTypes = {};
  TimeOfDay? _preferredTime;
  bool _showFilterPanel = false;
  List<String> _serviceTypes = [];
  double _maxPrice = 10000;

  @override
  void initState() {
    super.initState();
    _fetchSpas();
    _fetchServiceTypes();
  }

  /// Fetch unique service types
  Future<void> _fetchServiceTypes() async {
    try {
      final response = await supabase
          .from('service')
          .select('service_name')
          .order('service_name');
      
      if (mounted) {
        setState(() {
          _serviceTypes = List<String>.from(
            response.map((s) => s['service_name'] as String).toSet()
          );
        });
      }
    } catch (e) {
      print('Error fetching service types: $e');
    }
  }

  /// Enhanced spa fetching with ratings and services
  Future<void> _fetchSpas() async {
    try {
      final response = await supabase
          .from('spa')
          .select('''
            *,
            services:service(*),
            feedback:feedback(rating)
          ''')
          .order('spa_name');

      if (mounted) {
        setState(() {
          _spas = List<Map<String, dynamic>>.from(response);
          // Calculate max price for range slider
          _maxPrice = _spas.fold(0.0, (max, spa) {
            final services = List<Map<String, dynamic>>.from(spa['services'] ?? []);
            final spaMaxPrice = services.fold(0.0, (p, service) => 
              math.max(p, (service['service_price'] ?? 0).toDouble()));
            return math.max(max, spaMaxPrice);
          });
          _priceRange = RangeValues(0, _maxPrice);
        });
      }
    } catch (e) {
      print('Error fetching spas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading spas. Please check your connection.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _fetchSpas,
            ),
          ),
        );
        setState(() {
          _spas = [];
        });
      }
    }
  }

  /// ✅ Logout function
Future<void> _logout() async {
  // First check if the widget is still mounted
  if (!mounted) return;
  // Store context in a local variable before the async operation
  final navigatorContext = context;
  // Perform the logout
  await supabase.auth.signOut();
  // Check mounted again after the async operation
  if (mounted) {
    Navigator.pushReplacement(navigatorContext, MaterialPageRoute(builder: (context) => LoginPage()));
  }
}

  /// Filter spas based on criteria
  List<Map<String, dynamic>> _getFilteredSpas() {
    return _spas.where((spa) {
      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          spa['spa_name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          spa['spa_address'].toString().toLowerCase().contains(_searchQuery.toLowerCase());

      // Price range filter
      final services = List<Map<String, dynamic>>.from(spa['services'] ?? []);
      final hasServiceInPriceRange = services.any((service) {
        final price = (service['service_price'] ?? 0).toDouble();
        return price >= _priceRange.start && price <= _priceRange.end;
      });

      // Rating filter - Fix type error by explicitly handling int values
      final ratings = List<Map<String, dynamic>>.from(spa['feedback'] ?? []);
      final averageRating = ratings.isEmpty ? 0.0 :
          ratings.fold<int>(0, (sum, item) => sum + (item['rating'] as int)) / ratings.length;
      final meetsRatingCriteria = averageRating >= _minRating;

      // Service type filter
      final hasSelectedServices = _selectedServiceTypes.isEmpty ||
          services.any((service) => _selectedServiceTypes.contains(service['service_name']));

      return matchesSearch && 
             hasServiceInPriceRange && 
             meetsRatingCriteria && 
             hasSelectedServices;
    }).toList();
  }

  /// Build filter panel
  Widget _buildFilterPanel() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      height: _showFilterPanel ? null : 0,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Price Range'),
              RangeSlider(
                values: _priceRange,
                min: 0,
                max: _maxPrice,
                divisions: 20,
                labels: RangeLabels(
                  '₱${_priceRange.start.toStringAsFixed(0)}',
                  '₱${_priceRange.end.toStringAsFixed(0)}'
                ),
                onChanged: (values) => setState(() => _priceRange = values),
              ),
              
              Text('Minimum Rating'),
              Slider(
                value: _minRating,
                min: 0,
                max: 5,
                divisions: 5,
                label: '${_minRating.toStringAsFixed(1)} ★',
                onChanged: (value) => setState(() => _minRating = value),
              ),
              
              Text('Service Types'),
              Wrap(
                spacing: 8,
                children: _serviceTypes.map((type) => FilterChip(
                  label: Text(type),
                  selected: _selectedServiceTypes.contains(type),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedServiceTypes.add(type);
                      } else {
                        _selectedServiceTypes.remove(type);
                      }
                    });
                  },
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredSpas = _getFilteredSpas();
    
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.person, color: Colors.white, size: 50),
                  SizedBox(height: 8),
                  Text(
                    "Client Menu",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
  leading: Icon(Icons.account_circle),
  title: Text("Profile Settings"),
  onTap: () {
    Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => ProfilePage(userRole: 'Client')),
);

  },
),
            ListTile(
  leading: Icon(Icons.calendar_today),
  title: Text("Manage Appointments"),
  onTap: () async {
    final userEmail = Supabase.instance.client.auth.currentUser?.email;

    if (userEmail != null) {
      final client = await Supabase.instance.client
          .from('client')
          .select('client_id')
          .eq('email', userEmail)
          .maybeSingle();

      if (client != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ManageBookings(
              userRole: 'client',
              userId: client['client_id'],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Client data not found.')),
        );
      }
    }
  },
),
            ListTile(
              leading: Icon(Icons.exit_to_app),
              title: Text("Logout"),
              onTap: _logout,
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text("Client Dashboard"),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search spas...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            
            // Filter toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Available Spas",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: Icon(_showFilterPanel ? Icons.expand_less : Icons.expand_more),
                  label: Text("Filters"),
                  onPressed: () => setState(() => _showFilterPanel = !_showFilterPanel),
                ),
              ],
            ),
            
            // Filter panel
            _buildFilterPanel(),
            
            // Results count
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${filteredSpas.length} results found',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            
            // Spa list
            Expanded(
              child: filteredSpas.isEmpty
                  ? Center(child: Text("No spas match your criteria"))
                  : ListView.builder(
                      itemCount: filteredSpas.length,
                      itemBuilder: (context, index) {
                        final spa = filteredSpas[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8),
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                                child: spa['image_url'] != null
                                    ? Image.network(spa['image_url'], width: double.infinity, height: 150, fit: BoxFit.cover)
                                    : Container(
                                        width: double.infinity,
                                        height: 150,
                                        color: Colors.grey[300],
                                        child: Icon(Icons.image, size: 50, color: Colors.grey[700]),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(spa['spa_name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    SizedBox(height: 4),
                                    Text(spa['spa_address'] ?? "No location provided"),
                                    SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => SpaDetails(spaId: spa['spa_id']),
                                            ),
                                          );
                                        },
                                        child: Text("View Details"),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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