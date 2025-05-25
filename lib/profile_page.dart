import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_profile.dart';

class ProfilePage extends StatefulWidget {
  final String userRole;
  final Map<String, dynamic>? initialData; // Optional pre-loaded user data
  
  const ProfilePage({Key? key, required this.userRole, this.initialData}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final SupabaseClient supabase = Supabase.instance.client;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? error;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = supabase.auth.currentUser?.id;
    
    // Use pre-loaded data if available
    if (widget.initialData != null) {
      setState(() {
        userData = widget.initialData;
        isLoading = false;
      });
    } else {
      _fetchUserData();
    }
  }

  // Update the _fetchUserData() method in profile_page.dart to add support for receptionists
Future<void> _fetchUserData() async {
  try {
    setState(() {
      isLoading = true;
      error = null;
    });
    
    final String? userEmail = supabase.auth.currentUser?.email;
    final String? userId = supabase.auth.currentUser?.id;
    
    if (userEmail == null) {
      throw Exception("User email not found");
    }
    
    // Query based on user role
    switch (widget.userRole.toLowerCase()) {
      case 'admin':
        final response = await supabase
            .from('admin')
            .select()
            .eq('auth_id', userId!)  // Add non-null assertion since we check above
            .single();
            
        if (response != null) {
          setState(() {
            userData = response;
            isLoading = false;
          });
          return;
        }
        throw Exception("Admin profile not found");

      case 'manager':
        // Try both auth_id and email for staff table
        final response = await supabase
            .from('staff')
            .select('''
              *,
              spa:spa_id (
                spa_id,
                spa_name,
                spa_address
              )
            ''')
            .or('auth_id.eq.${userId},email.ilike.${userEmail}')
            .eq('role', 'Manager')
            .limit(1);
            
        if (response != null && response.isNotEmpty) {
          setState(() {
            userData = response[0];
            isLoading = false;
          });
          return;
        }
        throw Exception("Manager profile not found");

      case 'therapist':
      case 'receptionist':
        // All staff types are in the staff table
        final response2 = await supabase
            .from('staff')
            .select('''
              *,
              spa:spa_id (
                spa_id,
                spa_name,
                spa_address
              )
            ''')
            .eq('email', userEmail)
            .eq('role', widget.userRole.capitalize()) // Capitalize first letter to match DB enum
            .single(); // Use single() instead of limit(1)
            
        if (response2 != null) {
          setState(() {
            userData = response2;
            isLoading = false;
          });
          return;
        }
        
        // Fallback to auth_id if email lookup fails
        if (_userId != null) {
          final authResponse = await supabase
              .from('staff')
              .select('''
                *,
                spa:spa_id (
                  spa_id,
                  spa_name,
                  spa_address
                )
              ''')
              .eq('auth_id', _userId!)
              .eq('role', widget.userRole.capitalize())
              .single();
              
          if (authResponse != null) {
            setState(() {
              userData = authResponse;
              isLoading = false;
            });
            return;
          }
        }
        
        throw Exception("${widget.userRole} profile not found");

      case 'client':
        final response = await supabase
            .from('client')
            .select()
            .eq('email', userEmail)
            .limit(1);
            
        if (response != null && response.isNotEmpty) {
          setState(() {
            userData = response[0];
            isLoading = false;
          });
          return;
        }
        
        // Try case-insensitive email search
        final caseInsensitiveResponse = await supabase
            .from('client')
            .select()
            .ilike('email', userEmail)
            .limit(1);
            
        if (caseInsensitiveResponse != null && caseInsensitiveResponse.isNotEmpty) {
          setState(() {
            userData = caseInsensitiveResponse[0];
            isLoading = false;
          });
          return;
        }
        
        throw Exception("Client profile not found");

      default:
        throw Exception("Invalid user role: ${widget.userRole}");
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
    print("Error fetching user data: $e");
  }
}
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profile Settings")),
      body: isLoading 
        ? Center(child: CircularProgressIndicator())
        : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Error loading profile: $error", 
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchUserData,
                      child: Text('Retry'),
                    )
                  ],
                ),
              )
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Display user info card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundColor: _getRoleColor(),
                              child: Icon(_getRoleIcon(), size: 40, color: Colors.white),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${userData?['first_name'] ?? ''} ${userData?['last_name'] ?? ''}",
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    supabase.auth.currentUser?.email ?? '',
                                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    userData?['phonenumber'] ?? '',
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (widget.userRole.toLowerCase() == 'client' && userData?['address'] != null) ...[
                          SizedBox(height: 8),
                          Divider(),
                          Row(
                            children: [
                              Icon(Icons.home, color: _getRoleColor()),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  userData?['address'] ?? '',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if ((widget.userRole.toLowerCase() == 'manager' || 
                             widget.userRole.toLowerCase() == 'therapist') && 
                             userData?['spa_id'] != null) ...[
                          SizedBox(height: 8),
                          Divider(),
                          Row(
                            children: [
                              Icon(Icons.business, color: _getRoleColor()),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Spa ID: ${userData?['spa_id']}",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                        // Show therapist status if applicable
                        if (widget.userRole.toLowerCase() == 'therapist' && 
                            userData?['status'] != null) ...[
                          SizedBox(height: 8),
                          Divider(),
                          Row(
                            children: [
                              Icon(Icons.circle, color: _getStatusColor(userData?['status'])),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Status: ${userData?['status']}",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                        // Show receptionist shift if applicable
                        if (widget.userRole.toLowerCase() == 'receptionist' && 
                            userData?['shift'] != null) ...[
                          SizedBox(height: 8),
                          Divider(),
                          Row(
                            children: [
                              Icon(Icons.access_time, color: _getRoleColor()),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Shift: ${userData?['shift']}",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                _buildSectionTitle("Profile Settings"),
                _buildOptionTile(
                  context,
                  icon: Icons.person,
                  title: "Edit Profile",
                  subtitle: "Update your profile information, email, and password",
                  onTap: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => EditProfilePage(userRole: widget.userRole))
                  ).then((result) {
                    if (result == true) {
                      _fetchUserData();
                    }
                  }),
                ),
              ],
            ),
    );
  }

  /// Get color based on user role
  Color _getRoleColor() {
    switch (widget.userRole.toLowerCase()) {
      case 'manager': return Colors.blue;
      case 'therapist': return Colors.teal;
      case 'receptionist': return Colors.purple;
      case 'client': return Colors.green;
      default: return Colors.blue;
    }
  }

  /// Get icon based on user role  
  IconData _getRoleIcon() {
    switch (widget.userRole.toLowerCase()) {
      case 'manager': return Icons.admin_panel_settings;
      case 'therapist': return Icons.spa;
      case 'receptionist': return Icons.support_agent;
      case 'client': return Icons.person;
      default: return Icons.person;
    }
  }

  /// Get color based on therapist status
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Active': return Colors.green;
      case 'Busy': return Colors.orange;
      case 'Inactive': return Colors.red;
      default: return Colors.grey;
    }
  }

  /// ✅ Section Title Widget
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// ✅ Option Tile Widget
  Widget _buildOptionTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: _getRoleColor()),
        title: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }
}