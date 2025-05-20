import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'change_password.dart';
import 'change_email.dart';
import 'edit_profile.dart'; // Separate screen for editing profile

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
    
    if (userEmail == null) {
      throw Exception("User email not found");
    }
    
    String tableName;
    
    // Determine which table to query based on user role
    switch (widget.userRole.toLowerCase()) {
      case 'manager':
        tableName = 'manager';
        
        // First try by email for manager
        final response = await supabase
            .from(tableName)
            .select()
            .eq('email', userEmail)
            .limit(1);
            
        if (response != null && response.isNotEmpty) {
          setState(() {
            userData = response[0];
            isLoading = false;
          });
        } else if (_userId != null) {
          // If email doesn't work, try by auth_id
          final authResponse = await supabase
              .from(tableName)
              .select()
              .eq('auth_id', _userId ?? '')
              .limit(1);
              
          if (authResponse != null && authResponse.isNotEmpty) {
            setState(() {
              userData = authResponse[0];
              isLoading = false;
            });
          } else {
            throw Exception("Manager profile not found");
          }
        } else {
          throw Exception("Manager profile not found");
        }
        break;

      case 'client':
  tableName = 'client';
  
  // For clients, we only search by email since there's no auth_id column
  final response = await supabase
      .from(tableName)
      .select()
      .eq('email', userEmail)
      .limit(1);
      
  if (response != null && response.isNotEmpty) {
    setState(() {
      userData = response[0];
      isLoading = false;
    });
  } else {
    // Add some helpful debugging in console
    print("Client not found with email: $userEmail");
    
    // Check if the client might exist but email casing is different (case sensitivity issue)
    try {
      final caseInsensitiveResponse = await supabase
          .from(tableName)
          .select()
          .ilike('email', userEmail ?? '')
          .limit(1);
          
      if (caseInsensitiveResponse != null && caseInsensitiveResponse.isNotEmpty) {
        setState(() {
          userData = caseInsensitiveResponse[0];
          isLoading = false;
        });
      } else {
        throw Exception("Client profile not found. Please ensure your account is properly registered.");
      }
    } catch (e) {
      throw Exception("Client profile not found. Please ensure your account is properly registered.");
    }
  }
  break;

      case 'therapist':
        tableName = 'therapist';
        
        // Try by email first
        final response = await supabase
            .from(tableName)
            .select()
            .eq('email', userEmail)
            .limit(1);
            
        if (response != null && response.isNotEmpty) {
          setState(() {
            userData = response[0];
            isLoading = false;
          });
        } else if (_userId != null) {
          // If email doesn't work, try by auth_id
          final authResponse = await supabase
              .from(tableName)
              .select()
              .eq('auth_id', _userId ?? '')
              .limit(1);
              
          if (authResponse != null && authResponse.isNotEmpty) {
            setState(() {
              userData = authResponse[0];
              isLoading = false;
            });
          } else {
            throw Exception("Therapist profile not found");
          }
        } else {
          throw Exception("Therapist profile not found");
        }
        break;

      case 'receptionist':
        tableName = 'receptionist';
        
        // Try by email first
        final response = await supabase
            .from(tableName)
            .select()
            .eq('email', userEmail)
            .limit(1);
            
        if (response != null && response.isNotEmpty) {
          setState(() {
            userData = response[0];
            isLoading = false;
          });
        } else if (_userId != null) {
          // If email doesn't work, try by auth_id
          final authResponse = await supabase
              .from(tableName)
              .select()
              .eq('auth_id', _userId ?? '')
              .limit(1);
              
          if (authResponse != null && authResponse.isNotEmpty) {
            setState(() {
              userData = authResponse[0];
              isLoading = false;
            });
          } else {
            throw Exception("Receptionist profile not found");
          }
        } else {
          throw Exception("Receptionist profile not found");
        }
        break;

      default:
        throw Exception("Invalid user role: ${widget.userRole}");
    }
    
  } catch (e) {
    setState(() {
      error = e.toString();
      isLoading = false;
    });
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
                // Display user info at the top
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
                _buildSectionTitle("User Profile Settings"),
                _buildOptionTile(
                    context,
                    icon: Icons.person,
                    title: "Edit Profile",
                    subtitle: "Update your personal information",
                    onTap: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => EditProfilePage(userRole: widget.userRole))
                    ).then((result) {
                      // Refresh data when returning from edit profile
                      if (result == true) {
                        _fetchUserData().then((_) {
                          // Return updated data to previous screen
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context, userData);
                          }
                        });
                      }
                    }),
                  ),
                SizedBox(height: 16),
                _buildSectionTitle("Email Settings"),
                _buildOptionTile(
                  context,
                  icon: Icons.email,
                  title: "Change Email",
                  subtitle: "Update your email address",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChangeEmailPage())),
                ),
                SizedBox(height: 16),
                _buildSectionTitle("Password Settings"),
                _buildOptionTile(
                  context,
                  icon: Icons.lock,
                  title: "Change Password",
                  subtitle: "Update your password",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChangePasswordPage())),
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