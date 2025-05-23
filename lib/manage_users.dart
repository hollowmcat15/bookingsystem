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

  // Add this validation function
  bool _isValidName(String name) {
    return RegExp(r"^[a-zA-Z\s'\-]+$").hasMatch(name);
  }

  void _showOtpVerificationDialog() {
    final otpController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Verify Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('A verification email has been sent to $_pendingEmail'),
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
                  await supabase.auth.verifyOTP(
                    email: _pendingEmail!,
                    token: otpController.text.trim(),
                    type: OtpType.signup,
                  );
                  
                  await _linkAuthIdToUser(_pendingEmail!, _pendingAuthId!);
                  
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email verified successfully!')),
                  );
                  
                  _fetchUsers();
                } catch (e) {
                  if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Users'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: 'Search',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.search),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _currentFilter,
                            onChanged: (String? newValue) {
                              setState(() {
                                _currentFilter = newValue!;
                              });
                            },
                            items: _filterOptions
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return Card(
                            margin: EdgeInsets.all(8.0),
                            child: ListTile(
                              title: Text('${user['first_name']} ${user['last_name']}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Email: ${user['email']}'),
                                  Text('Phone: ${user['phonenumber']}'),
                                  if (user['user_type'] == 'Therapist') ...{
                                    Text('Status: ${user['status']}'),
                                    Text('Commission: ${user['commission_percentage']}%'),
                                  } else ...{
                                    Text('Shift: ${user['shift']}'),
                                  },
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit),
                                    onPressed: () {
                                      // Edit user logic
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete),
                                    onPressed: () {
                                      // Delete user logic
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        onPressed: () {
                          // Add user logic
                        },
                        child: Text('Add User'),
                      ),
                    ),
                  ],
                ),
    );
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

    // Name validation
    if (!_isValidName(_firstNameController.text) || !_isValidName(_lastNameController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Names can only contain letters, spaces, hyphens, and apostrophes')),
      );
      return;
    }

    // Phone validation - exactly 11 digits
    if (!RegExp(r'^\d{11}$').hasMatch(_phoneController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number must be exactly 11 digits')),
      );
      return;
    }

    // Birthday validation - must be at least 18 years old
    final DateTime now = DateTime.now();
    final DateTime minimumDate = DateTime(now.year - 18, now.month, now.day);
    if (_selectedBirthday.isAfter(minimumDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User must be at least 18 years old')),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final userData = {
        'spa_id': widget.spaId,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phonenumber': _phoneController.text.trim(),
        'birthday': _selectedBirthday.toIso8601String(),
        'password': _passwordController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      };

      // Add commission for therapist (minimum 25%)
      if (_selectedUserType == 'Therapist') {
        userData['commission_percentage'] = 25.0;
      }
      
      // Insert into appropriate table WITHOUT auth_id
      dynamic insertResponse;
      if (_selectedUserType == 'Therapist') {
        insertResponse = await supabase.from('therapist').insert({
          ...userData,
          'status': _selectedStatus,
        }).select().single();
      } else {
        insertResponse = await supabase.from('receptionist').insert({
          ...userData,
          'shift': _selectedShift,
        }).select().single();
      }

      if (!mounted) return;

      // Auth signup part
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        emailRedirectTo: 'https://qhqvnyefgqzzwovastnz.supabase.co/auth/callback',
      );

      if (!mounted) return;

      if (authResponse.user == null) {
        throw Exception('Failed to create auth user');
      }

      setState(() {
        _accountCreated = true;
        _pendingEmail = _emailController.text.trim();
        _pendingAuthId = authResponse.user!.id;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created! A verification email has been sent.')),
      );

      _showOtpVerificationDialog();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create account: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
      
      // Refresh user list after linking
      await _fetchUsers();
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to link account: ${e.toString()}')),
      );
    }
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
}