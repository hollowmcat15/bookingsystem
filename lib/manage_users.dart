import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ManageUsers extends StatefulWidget {
  final int spaId;

  const ManageUsers({
    Key? key,
    required this.spaId,
  }) : super(key: key);

  @override
  _ManageUsersState createState() => _ManageUsersState();
}

class _ManageUsersState extends State<ManageUsers> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _therapists = [];
  List<Map<String, dynamic>> _receptionists = [];
  String _searchQuery = '';
  String _currentFilter = 'All';
  List<String> _filterOptions = ['All', 'Therapists', 'Receptionists'];

  // Form controllers for creating new user
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedUserType = 'Therapist';
  DateTime _selectedBirthday = DateTime.now().subtract(Duration(days: 365 * 25)); // Default to 25 years ago
  String _selectedShift = 'Morning'; // For receptionists
  String _selectedStatus = 'Active'; // For therapists
  bool _accountCreated = false;
  String? _pendingEmail;
  String? _pendingAuthId;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch therapists
      final therapistsResponse = await supabase
          .from('therapist')
          .select('*')
          .eq('spa_id', widget.spaId);

      // Fetch receptionists
      final receptionistsResponse = await supabase
          .from('receptionist')
          .select('*')
          .eq('spa_id', widget.spaId);

      setState(() {
        _therapists = List<Map<String, dynamic>>.from(therapistsResponse);
        _receptionists = List<Map<String, dynamic>>.from(receptionistsResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading users: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    List<Map<String, dynamic>> users = [];
    
    if (_currentFilter == 'All' || _currentFilter == 'Therapists') {
      // Add therapists with a type identifier
      users.addAll(_therapists.map((therapist) => {
        ...therapist,
        'user_type': 'Therapist',
      }));
    }
    
    if (_currentFilter == 'All' || _currentFilter == 'Receptionists') {
      // Add receptionists with a type identifier
      users.addAll(_receptionists.map((receptionist) => {
        ...receptionist,
        'user_type': 'Receptionist',
      }));
    }
    
    // Apply search if query exists
    if (_searchQuery.isNotEmpty) {
      return users.where((user) {
        final String firstName = user['first_name']?.toString().toLowerCase() ?? '';
        final String lastName = user['last_name']?.toString().toLowerCase() ?? '';
        final String email = user['email']?.toString().toLowerCase() ?? '';
        return firstName.contains(_searchQuery.toLowerCase()) || 
               lastName.contains(_searchQuery.toLowerCase()) ||
               email.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    return users;
  }

 Future<void> _createUser() async {
  // Validate fields
  if (_firstNameController.text.isEmpty ||
      _lastNameController.text.isEmpty ||
      _emailController.text.isEmpty ||
      _phoneController.text.isEmpty ||
      _passwordController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill up the required fields')),
    );
    return;
  }

  // Email validation
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  if (!emailRegex.hasMatch(_emailController.text)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter a valid email address')),
    );
    return;
  }

  // Phone validation
  if (_phoneController.text.length < 10) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter a valid phone number')),
    );
    return;
  }

  try {
    setState(() {
      _isLoading = true;
    });

    // Method 1: Create the user in database WITHOUT auth_id first
    final userData = {
      'spa_id': widget.spaId,
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phonenumber': _phoneController.text.trim(),
      'birthday': _selectedBirthday.toIso8601String(),
      'password': _passwordController.text.trim(), // Storing hashed password for legacy support
      'created_at': DateTime.now().toIso8601String(),
    };

    // Insert into appropriate table WITHOUT auth_id
    dynamic insertResponse;
    if (_selectedUserType == 'Therapist') {
      insertResponse = await supabase.from('therapist').insert({
        ...userData,
        'status': _selectedStatus,
        // No auth_id field here
      }).select().single();
    } else {
      insertResponse = await supabase.from('receptionist').insert({
        ...userData,
        'shift': _selectedShift,
        // No auth_id field here
      }).select().single();
    }

    // In your _createUser() method, modify the auth signup part to explicitly request email confirmation:
    final authResponse = await supabase.auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      emailRedirectTo: 'https://qhqvnyefgqzzwovastnz.supabase.co/auth/callback', // You can specify a redirect URL if needed
    );

    if (authResponse.user == null) {
      throw Exception('Failed to create auth user');
    }

    // Store auth info for verification
    setState(() {
      _accountCreated = true;
      _pendingEmail = _emailController.text.trim();
      _pendingAuthId = authResponse.user!.id;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created! A verification email has been sent.')),
    );

    // Show OTP verification dialog
    _showOtpVerificationDialog();
    
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to create account: ${e.toString()}')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

// Add a new function to link the verified auth ID to the user record
Future<void> _linkAuthIdToUser(String email, String authId) async {
  try {
    if (_selectedUserType == 'Therapist') {
      await supabase.from('therapist')
        .update({
          'auth_id': authId,
          'is_verified': true
        })
        .eq('email', email);
    } else {
      await supabase.from('receptionist')
        .update({
          'auth_id': authId,
          'is_verified': true
        })
        .eq('email', email);
    }
    
    // Refresh user list
    _fetchUsers();
    
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to link account: ${e.toString()}')),
    );
  }
}

  void _showCreateUserDialog() {
    // Reset form fields
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _selectedUserType = 'Therapist';
    _selectedShift = 'Morning';
    _selectedStatus = 'Active';
    _selectedBirthday = DateTime.now().subtract(Duration(days: 365 * 25));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Create New Account'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'User Type'),
                      value: _selectedUserType,
                      items: ['Therapist', 'Receptionist']
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedUserType = value!;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        helperText: 'Will be used for Supabase Auth',
                      ),
                      obscureText: true,
                    ),
                    SizedBox(height: 16),
                    ListTile(
                      title: Text('Birthday'),
                      subtitle: Text(DateFormat('MM/dd/yyyy').format(_selectedBirthday)),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedBirthday,
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && picked != _selectedBirthday) {
                          setState(() {
                            _selectedBirthday = picked;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 16),
                    if (_selectedUserType == 'Receptionist') ...[
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: 'Shift'),
                        value: _selectedShift,
                        items: ['Morning', 'Noon', 'Afternoon', 'Evening']
                            .map((shift) => DropdownMenuItem(
                                  value: shift,
                                  child: Text(shift),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedShift = value!;
                          });
                        },
                      ),
                    ],
                    if (_selectedUserType == 'Therapist') ...[
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: 'Status'),
                        value: _selectedStatus,
                        items: ['Active', 'Inactive', 'Busy']
                            .map((status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value!;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _createUser,
                  child: Text('Create Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    final userType = user['user_type'];
    final userId = userType == 'Therapist' ? user['therapist_id'] : user['receptionist_id'];
    final authId = user['auth_id'] ?? 'Not linked';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('User Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: ${userId}'),
              SizedBox(height: 8),
              Text('Auth ID: ${authId}'),
              SizedBox(height: 8),
              Text('Type: ${userType}'),
              SizedBox(height: 8),
              Text('Name: ${user['first_name']} ${user['last_name']}'),
              SizedBox(height: 8),
              Text('Email: ${user['email']}'),
              SizedBox(height: 8),
              Text('Phone: ${user['phonenumber']}'),
              SizedBox(height: 8),
              Text('Birthday: ${DateFormat('MM/dd/yyyy').format(DateTime.parse(user['birthday']))}'),
              SizedBox(height: 8),
              if (userType == 'Therapist')
                Text('Status: ${user['status']}')
              else
                Text('Shift: ${user['shift']}'),
              SizedBox(height: 8),
              Text('Created: ${DateFormat('MM/dd/yyyy').format(DateTime.parse(user['created_at']))}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showUpdateUserDialog(user);
              },
              child: Text('Update'),
            ),
          ],
        );
      },
    );
  }
  
  void _showOtpVerificationDialog() {
  final otpController = TextEditingController();
  
  showDialog(
    context: context,
    barrierDismissible: false, // User must respond to the dialog
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Verify Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('A verification email has been sent to $_pendingEmail.'),
            Text('Please check your inbox and enter the OTP code below:'),
            SizedBox(height: 16),
            TextField(
              controller: otpController,
              decoration: InputDecoration(
                labelText: 'OTP Code',
                border: OutlineInputBorder(),
                hintText: 'Enter the code from your email',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _accountCreated = false;
              });
            },
            child: Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (otpController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter the OTP code')),
                );
                return;
              }
              
              try {
                // Verify the OTP with Supabase
                await supabase.auth.verifyOTP(
                  email: _pendingEmail!,
                  token: otpController.text.trim(),
                  type: OtpType.signup,
                );
                
                // Link the auth ID to the user record now that it's verified
                await _linkAuthIdToUser(_pendingEmail!, _pendingAuthId!);
                
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email verified successfully!')),
                );
                
                // Refresh the user list
                _fetchUsers();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Verification failed: ${e.toString()}')),
                );
              }
            },
            child: Text('Verify'),
          ),
        ],
      );
    },
  );
}

  void _showUpdateUserDialog(Map<String, dynamic> user) {
    final userType = user['user_type'];
    
    // Pre-fill the form with existing user data
    _firstNameController.text = user['first_name'] ?? '';
    _lastNameController.text = user['last_name'] ?? '';
    _emailController.text = user['email'] ?? '';
    _phoneController.text = user['phonenumber'] ?? '';
    _passwordController.text = ''; // Don't prefill password for security
    
    try {
      _selectedBirthday = DateTime.parse(user['birthday']);
    } catch (e) {
      _selectedBirthday = DateTime.now().subtract(Duration(days: 365 * 25));
    }
    
    if (userType == 'Therapist') {
      _selectedStatus = user['status'] ?? 'Active';
    } else {
      _selectedShift = user['shift'] ?? 'Morning';
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Update User'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User Type: $userType', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 16),
                    TextField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'New Password (leave blank to keep current)',
                        border: OutlineInputBorder(),
                        helperText: 'Will update Supabase Auth if provided',
                      ),
                      obscureText: true,
                    ),
                    SizedBox(height: 16),
                    ListTile(
                      title: Text('Birthday'),
                      subtitle: Text(DateFormat('MM/dd/yyyy').format(_selectedBirthday)),
                      trailing: Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedBirthday,
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && picked != _selectedBirthday) {
                          setState(() {
                            _selectedBirthday = picked;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 16),
                    if (userType == 'Receptionist') ...[
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: 'Shift'),
                        value: _selectedShift,
                        items: ['Morning', 'Noon', 'Afternoon', 'Evening']
                            .map((shift) => DropdownMenuItem(
                                  value: shift,
                                  child: Text(shift),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedShift = value!;
                          });
                        },
                      ),
                    ],
                    if (userType == 'Therapist') ...[
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: 'Status'),
                        value: _selectedStatus,
                        items: ['Active', 'Inactive', 'Busy']
                            .map((status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value!;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          title: Text('Save Changes?'),
                          content: Text('Are you sure you want to save the changes?'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop(); // Close confirmation dialog
                              },
                              child: Text('No'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop(); // Close confirmation dialog
                                Navigator.of(context).pop(); // Close update dialog
                                _updateUser(user);
                              },
                              child: Text('Yes'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateUser(Map<String, dynamic> user) async {
    // Validate fields
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill up the required fields')),
      );
      return;
    }

    // Email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    // Phone validation
    if (_phoneController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final userType = user['user_type'];
      final userId = userType == 'Therapist' ? user['therapist_id'] : user['receptionist_id'];
      final authId = user['auth_id'];

      // Prepare update data
      final updateData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phonenumber': _phoneController.text.trim(),
        'birthday': _selectedBirthday.toIso8601String(),
      };

      // Update Supabase Auth if changing email or password and auth_id exists
      if (authId != null) {
        final Map<String, dynamic> authUpdateData = {};
        
        // Only include email if it changed
        if (_emailController.text.trim() != user['email']) {
          authUpdateData['email'] = _emailController.text.trim();
          
          // If email is changed, user will need to verify new email
          updateData['is_verified'] = 'false'; // If the column expects a string
        }
        
        // Only include password if provided
        if (_passwordController.text.isNotEmpty) {
          authUpdateData['password'] = _passwordController.text.trim();
        }
        
        // Perform auth update if needed
        if (authUpdateData.isNotEmpty) {
          try {
            // Update the user in Supabase Auth
            await supabase.auth.admin.updateUserById(
              authId,
              attributes: AdminUserAttributes(
                email: authUpdateData['email'],
                password: authUpdateData['password'],
              ),
            );
            
            // If email was changed, send a verification email
            if (authUpdateData.containsKey('email')) {
              // Store for OTP verification
              _pendingEmail = _emailController.text.trim();
              _pendingAuthId = authId;
              _selectedUserType = userType;
              
              // Set flag to show verification dialog after update
              setState(() {
                _accountCreated = true;
              });
            }
          } catch (e) {
            print('Warning: Failed to update Auth user: ${e.toString()}');
            // Continue with DB update even if auth update fails
          }
        }
      }

      // Add password only if it's not empty (for legacy fallback)
      if (_passwordController.text.isNotEmpty) {
        updateData['password'] = _passwordController.text.trim();
      }

      // Add type-specific fields
      if (userType == 'Therapist') {
        updateData['status'] = _selectedStatus;
        await supabase
            .from('therapist')
            .update(updateData)
            .eq('therapist_id', userId);
      } else {
        updateData['shift'] = _selectedShift;
        await supabase
            .from('receptionist')
            .update(updateData)
            .eq('receptionist_id', userId);
      }

      // Refresh the user list
      _fetchUsers();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved successfully')),
      );
      
      // If email was changed, show verification dialog
      if (_accountCreated) {
        _showOtpVerificationDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update user: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _toggleUserStatus(Map<String, dynamic> user, bool setActive) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final userType = user['user_type'];
      final userId = userType == 'Therapist' ? user['therapist_id'] : user['receptionist_id'];
      
      if (userType == 'Therapist') {
        await supabase
            .from('therapist')
            .update({'status': setActive ? 'Active' : 'Inactive'})
            .eq('therapist_id', userId);
      }
      
      // No status for receptionists, but could implement shift changes
      // or other status indicators in the future
      
      // Refresh user list
      _fetchUsers();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          'User status set to ${setActive ? 'Active' : 'Inactive'}'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userType = user['user_type'];
    final userStatus = userType == 'Therapist' ? user['status'] : user['shift'];
    final bool isLinkedToAuth = user['auth_id'] != null;
    final bool isVerified = user['is_verified'] ?? false;
    
    // Determine status color
    Color statusColor = Colors.grey;
    if (userType == 'Therapist') {
      if (userStatus == 'Active') statusColor = Colors.green;
      else if (userStatus == 'Busy') statusColor = Colors.orange;
      else if (userStatus == 'Inactive') statusColor = Colors.red;
    }
    
    return Dismissible(
      key: Key(userType == 'Therapist' 
          ? 'therapist-${user['therapist_id']}' 
          : 'receptionist-${user['receptionist_id']}'),
      background: Container(
        color: userType == 'Therapist' && userStatus != 'Inactive' 
            ? Colors.red 
            : Colors.green,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 20.0),
            child: Icon(
              userType == 'Therapist' && userStatus != 'Inactive'
                  ? Icons.person_off
                  : Icons.person,
              color: Colors.white,
            ),
          ),
        ),
      ),
      secondaryBackground: Container(
        color: Colors.blue,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Icon(Icons.edit, color: Colors.white),
          ),
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Left swipe: Toggle active status (for therapists)
          if (userType == 'Therapist') {
            bool setActive = userStatus == 'Inactive';
            await _toggleUserStatus(user, setActive);
          }
          return false; // Don't remove from list
        } else {
          // Right swipe: Edit user
          _showUpdateUserDialog(user);
          return false; // Don't remove from list
        }
      },
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: userType == 'Therapist' ? Colors.green : Colors.blue,
              child: Icon(
                userType == 'Therapist' ? Icons.spa : Icons.person,
                color: Colors.white,
              ),
            ),
            if (userType == 'Therapist') 
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${user['first_name']} ${user['last_name']}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isLinkedToAuth)
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Icon(
                  isVerified ? Icons.verified_user : Icons.warning,
                  size: 16,
                  color: isVerified ? Colors.green : Colors.orange,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user['email'],
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: userType == 'Therapist' ? Colors.green[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: userType == 'Therapist' ? Colors.green : Colors.blue,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    userType,
                    style: TextStyle(
                      fontSize: 12,
                      color: userType == 'Therapist' ? Colors.green[800] : Colors.blue[800],
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: statusColor,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    userStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'details') {
              _showUserDetails(user);
            } else if (value == 'edit') {
              _showUpdateUserDialog(user);
            } else if (value == 'verify') {
              // Set pending email and auth ID
              _pendingEmail = user['email'];
              _pendingAuthId = user['auth_id'] ?? '';
              _selectedUserType = userType;
              // Show OTP verification dialog
              _showOtpVerificationDialog();
            } else if (value == 'active') {
              _toggleUserStatus(user, true);
            } else if (value == 'inactive') {
              _toggleUserStatus(user, false);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Text('Details'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            if (!isVerified && isLinkedToAuth)
              PopupMenuItem(
                value: 'verify',
                child: Row(
                  children: [
                    Icon(Icons.verified_user),
                    SizedBox(width: 8),
                    Text('Verify Email'),
                  ],
                ),
              ),
            if (userType == 'Therapist' && user['status'] != 'Active')
              PopupMenuItem(
                value: 'active',
                child: Row(
                  children: [
                    Icon(Icons.check_circle),
                    SizedBox(width: 8),
                    Text('Set Active'),
                  ],
                ),
              ),
            if (userType == 'Therapist' && user['status'] != 'Inactive')
              PopupMenuItem(
                value: 'inactive',
                child: Row(
                  children: [
                    Icon(Icons.cancel),
                    SizedBox(width: 8),
                    Text('Set Inactive'),
                  ],
                ),
              ),
          ],
        ),
        onTap: () {
          _showUserDetails(user);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Users'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: ButtonTheme(
                      alignedDropdown: true,
                      child: DropdownButton<String>(
                        value: _currentFilter,
                        items: _filterOptions
                            .map((option) => DropdownMenuItem(
                                  value: option,
                                  child: Text(option),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _currentFilter = value!;
                          });
                        },
                        padding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _isLoading
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(),
                )
              : SizedBox(),
          Expanded(
            child: _isLoading && _filteredUsers.isEmpty
                ? Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red),
                            SizedBox(height: 16),
                            Text(_error!, style: TextStyle(color: Colors.red)),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchUsers,
                              child: Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 80, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No users found',
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                                if (_searchQuery.isNotEmpty || _currentFilter != 'All')
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _currentFilter = 'All';
                                      });
                                    },
                                    child: Text('Clear filters'),
                                  ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchUsers,
                            child: ListView.separated(
                              itemCount: _filteredUsers.length,
                              separatorBuilder: (context, index) => Divider(height: 1),
                              itemBuilder: (context, index) {
                                return _buildUserTile(_filteredUsers[index]);
                              },
                            ),
                          ),
          ),
          // Stats footer
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${_filteredUsers.length} users',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green,
                      radius: 8,
                      child: Icon(Icons.spa, color: Colors.white, size: 10),
                    ),
                    SizedBox(width: 4),
                    Text('${_therapists.length} therapists'),
                    SizedBox(width: 12),
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      radius: 8,
                      child: Icon(Icons.person, color: Colors.white, size: 10),
                    ),
                    SizedBox(width: 4),
                    Text('${_receptionists.length} receptionists'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUserDialog,
        icon: Icon(Icons.person_add),
        label: Text('New User'),
        tooltip: 'Create New Account',
      ),
    );
  }
}