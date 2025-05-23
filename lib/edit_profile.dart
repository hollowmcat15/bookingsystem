import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting

class EditProfilePage extends StatefulWidget {
  final String userRole;
  final Map<String, dynamic>? initialData; // Optional pre-loaded user data
  
  const EditProfilePage({Key? key, required this.userRole, this.initialData}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _birthdayController; // For therapist
  
  // Additional controllers for email/password
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  late TextEditingController _newEmailController;

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isEmailChangeMode = false;
  bool _isPasswordChangeMode = false;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _userData;
  String? _userId;
  String? _userEmail;
  String? _tableName;
  String? _userIdField;
  String? _firstNameField;
  String? _lastNameField;
  String? _phoneField;
  String? _addressField;
  String? _birthdayField;
  String? _statusField;
  String? _currentStatus;
  bool _hasAddressField = false;
  bool _hasBirthdayField = false;
  bool _hasStatusField = false;
  
  // Status options for therapist
  final List<String> _statusOptions = ['Active', 'Inactive', 'Busy'];

  DateTime? _selectedBirthday;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _birthdayController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _newEmailController = TextEditingController();
    
    _setupBasedOnRole();
    
    // Use pre-loaded data if available
    if (widget.initialData != null) {
      setState(() {
        _userData = widget.initialData;
        _populateFormFields();
        _isLoading = false;
      });
    } else {
      _fetchUserData();
    }
  }

  // In the _setupBasedOnRole() method, add a case for 'receptionist'
void _setupBasedOnRole() {
  // Get current user ID and email
  _userId = supabase.auth.currentUser?.id;
  _userEmail = supabase.auth.currentUser?.email;
  
  print("Current user role: ${widget.userRole}");
  print("Current user email: $_userEmail");
  
  // Set up table and field names based on user role
  switch (widget.userRole.toLowerCase()) {
    case 'manager':
      _tableName = 'manager';
      _userIdField = 'manager_id';
      _firstNameField = 'first_name';
      _lastNameField = 'last_name';
      _phoneField = 'phonenumber';
      _birthdayField = 'birthday';
      _hasAddressField = false;
      _hasBirthdayField = true;
      _hasStatusField = false;
      break;
    case 'client':
      _tableName = 'client';
      _userIdField = 'client_id';
      _firstNameField = 'first_name';
      _lastNameField = 'last_name';
      _phoneField = 'phonenumber';
      _addressField = 'address';
      _birthdayField = 'birthday';
      _hasAddressField = true;
      _hasBirthdayField = true;
      _hasStatusField = false;
      break;
    case 'therapist':
      _tableName = 'therapist';
      _userIdField = 'therapist_id';
      _firstNameField = 'first_name';
      _lastNameField = 'last_name';
      _phoneField = 'phonenumber';
      _birthdayField = 'birthday';
      _statusField = 'status';
      _hasAddressField = false;
      _hasBirthdayField = true;
      _hasStatusField = true;
      break;
    case 'receptionist':
      _tableName = 'receptionist';
      _userIdField = 'receptionist_id';
      _firstNameField = 'first_name';
      _lastNameField = 'last_name';
      _phoneField = 'phonenumber';
      _birthdayField = 'birthday';
      _hasAddressField = false;
      _hasBirthdayField = true;
      _hasStatusField = false;
      break;
    default:
      _error = 'Invalid user role';
  }
}

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _birthdayController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newEmailController.dispose();
    super.dispose();
  }

  void _populateFormFields() {
    if (_userData == null) return;
    
    _firstNameController.text = _userData?[_firstNameField] ?? '';
    _lastNameController.text = _userData?[_lastNameField] ?? '';
    _phoneController.text = _userData?[_phoneField] ?? '';
    
    if (_hasAddressField && _addressField != null) {
      _addressController.text = _userData?[_addressField] ?? '';
    }
    
    if (_hasBirthdayField && _birthdayField != null && _userData?[_birthdayField] != null) {
      try {
        _selectedBirthday = DateTime.parse(_userData![_birthdayField!]);
        _birthdayController.text = DateFormat('yyyy-MM-dd').format(_selectedBirthday!);
      } catch (e) {
        print('Error parsing birthday: $e');
      }
    }
    
    if (_hasStatusField && _statusField != null) {
      _currentStatus = _userData?[_statusField] ?? 'Active';
    }
  }

  Future<void> _fetchUserData() async {
    if (_tableName == null) {
      setState(() {
        _error = 'Invalid user role';
        _isLoading = false;
      });
      return;
    }

    if (_userEmail == null) {
      setState(() {
        _error = 'User email not found';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // For managers and therapists, we might need to try both email and auth_id
      if (widget.userRole.toLowerCase() == 'manager' || widget.userRole.toLowerCase() == 'therapist') {
        try {
          // First try to get user by email
          final response = await supabase
              .from(_tableName!)
              .select()
              .eq('email', _userEmail!)
              .limit(1);
          
          if (response != null && response.isNotEmpty) {
            setState(() {
              _userData = response[0];
            });
          } else if (_userId != null) {
            // If email doesn't work, try auth_id
            final authResponse = await supabase
                .from(_tableName!)
                .select()
                .eq('auth_id', _userId!)
                .limit(1);
                
            if (authResponse != null && authResponse.isNotEmpty) {
              setState(() {
                _userData = authResponse[0];
              });
            } else {
              throw Exception('No profile found for ${widget.userRole}');
            }
          } else {
            throw Exception('No profile found for ${widget.userRole}');
          }
        } catch (e) {
          throw Exception('Failed to fetch ${widget.userRole} profile: ${e.toString()}');
        }
      } else {
        // For clients, just use email
        final response = await supabase
            .from(_tableName!)
            .select()
            .eq('email', _userEmail!)
            .limit(1);
            
        if (response != null && response.isNotEmpty) {
          setState(() {
            _userData = response[0];
          });
        } else {
          throw Exception('No client profile found');
        }
      }
      
      print("Found user data: $_userData");
      
      // Populate form fields with retrieved data
      _populateFormFields();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not find user profile: ${e.toString()}';
        _isLoading = false;
      });
      print('Error fetching user data: $e');
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate() || 
        _tableName == null || 
        _userData == null) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      Map<String, dynamic> updateData = {
        _firstNameField!: _firstNameController.text,
        _lastNameField!: _lastNameController.text,
        _phoneField!: _phoneController.text,
      };

      // Add address field for client if applicable
      if (_hasAddressField && _addressField != null) {
        updateData[_addressField!] = _addressController.text;
      }
      
      // Add birthday field if applicable
      if (_hasBirthdayField && _birthdayField != null && _selectedBirthday != null) {
        updateData[_birthdayField!] = _selectedBirthday!.toIso8601String().split('T')[0];
      }
      
      // Add status field for therapist if applicable
      if (_hasStatusField && _statusField != null && _currentStatus != null) {
        updateData[_statusField!] = _currentStatus;
      }

      // Use the actual ID from the fetched user data for the update
      final idValue = _userData![_userIdField!];
      
      print("Updating profile for $idValue with data: $updateData");
      
      await supabase
          .from(_tableName!)
          .update(updateData)
          .eq(_userIdField!, idValue);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context, true); // Return true to indicate successful update
      }
    } catch (e) {
      setState(() {
        _error = 'Update failed: ${e.toString()}';
        _isLoading = false;
      });
      print('Error updating profile: $e');
    }
  }

  Future<void> _updateEmail() async {
    if (!_formKey.currentState!.validate() || _tableName == null) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final currentUserEmail = supabase.auth.currentUser!.email!;
      final newEmail = _newEmailController.text.trim();
      final currentPassword = _currentPasswordController.text;

      // First verify password
      final AuthResponse verifyResponse = await supabase.auth.signInWithPassword(
        email: currentUserEmail,
        password: currentPassword,
      );

      if (verifyResponse.user == null) {
        throw AuthException('Invalid credentials');
      }

      // Use RPC to update auth email
      await supabase.rpc('change_user_email', params: {
        'old_email': currentUserEmail,
        'new_email': newEmail,
      });

      // Update the database table
      await supabase.from(_tableName!).update({
        'email': newEmail,
      }).eq('email', currentUserEmail);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email updated successfully. Please sign in with your new email.')),
        );
        // Sign out and redirect to login
        await supabase.auth.signOut();
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("New passwords do not match!")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Password updated successfully!")),
        );
        setState(() {
          _isPasswordChangeMode = false;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now().subtract(Duration(days: 365 * 25)),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(Duration(days: 365 * 18)),
    );
    
    if (picked != null && picked != _selectedBirthday) {
      setState(() {
        _selectedBirthday = picked;
        _birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  /// Get color based on therapist status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active': return Colors.green;
      case 'Busy': return Colors.orange;
      case 'Inactive': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, 
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
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile section header
                        Text(
                          'Edit Your Profile',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 20),

                        // Toggle buttons for different sections
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () => setState(() {
                                _isEmailChangeMode = false;
                                _isPasswordChangeMode = false;
                              }),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (!_isEmailChangeMode && !_isPasswordChangeMode) 
                                  ? Theme.of(context).primaryColor 
                                  : Colors.grey,
                              ),
                              child: Text('Profile Info'),
                            ),
                            ElevatedButton(
                              onPressed: () => setState(() {
                                _isEmailChangeMode = true;
                                _isPasswordChangeMode = false;
                              }),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isEmailChangeMode 
                                  ? Theme.of(context).primaryColor 
                                  : Colors.grey,
                              ),
                              child: Text('Change Email'),
                            ),
                            ElevatedButton(
                              onPressed: () => setState(() {
                                _isEmailChangeMode = false;
                                _isPasswordChangeMode = true;
                              }),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isPasswordChangeMode 
                                  ? Theme.of(context).primaryColor 
                                  : Colors.grey,
                              ),
                              child: Text('Change Password'),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),

                        // Show different forms based on mode
                        if (!_isEmailChangeMode && !_isPasswordChangeMode) ...[
                          // Original profile edit form fields
                          TextFormField(
                            controller: _firstNameController,
                            decoration: InputDecoration(
                              labelText: 'First Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your first name';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _lastNameController,
                            decoration: InputDecoration(
                              labelText: 'Last Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your last name';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              return null;
                            },
                          ),
                          if (_hasAddressField) ...[
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _addressController,
                              decoration: InputDecoration(
                                labelText: 'Address',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.home),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your address';
                                }
                                return null;
                              },
                            ),
                          ],
                          if (_hasBirthdayField) ...[
                            SizedBox(height: 16),
                            GestureDetector(
                              onTap: _pickDate,
                              child: AbsorbPointer(
                                child: TextFormField(
                                  controller: _birthdayController,
                                  decoration: InputDecoration(
                                    labelText: 'Birthday',
                                    hintText: 'YYYY-MM-DD',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.cake),
                                    suffixIcon: Icon(Icons.calendar_today),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_hasStatusField && _currentStatus != null) ...[
                            SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _currentStatus,
                              decoration: InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.circle, color: _getStatusColor(_currentStatus!)),
                              ),
                              items: _statusOptions.map((String status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(status),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _currentStatus = newValue;
                                  });
                                }
                              },
                            ),
                          ],
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _updateProfile,
                              child: Text('Save Changes', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],

                        if (_isEmailChangeMode) ...[
                          TextFormField(
                            controller: _newEmailController,
                            decoration: InputDecoration(
                              labelText: 'New Email',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter new email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _currentPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Current Password',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showCurrentPassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () => setState(() {
                                  _showCurrentPassword = !_showCurrentPassword;
                                }),
                              ),
                            ),
                            obscureText: !_showCurrentPassword,
                            validator: (value) => value!.isEmpty ? 'Please enter current password' : null,
                          ),
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _updateEmail,
                              child: Text('Update Email', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],

                        if (_isPasswordChangeMode) ...[
                          TextFormField(
                            controller: _currentPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Current Password',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showCurrentPassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () => setState(() {
                                  _showCurrentPassword = !_showCurrentPassword;
                                }),
                              ),
                            ),
                            obscureText: !_showCurrentPassword,
                            validator: (value) => value!.isEmpty ? 'Please enter current password' : null,
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _newPasswordController,
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showNewPassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () => setState(() {
                                  _showNewPassword = !_showNewPassword;
                                }),
                              ),
                            ),
                            obscureText: !_showNewPassword,
                            validator: (value) => value!.length < 6 
                              ? 'Password must be at least 6 characters' 
                              : null,
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Confirm New Password',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () => setState(() {
                                  _showConfirmPassword = !_showConfirmPassword;
                                }),
                              ),
                            ),
                            obscureText: !_showConfirmPassword,
                            validator: (value) => value != _newPasswordController.text 
                              ? 'Passwords do not match' 
                              : null,
                          ),
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _updatePassword,
                              child: Text('Update Password', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }
}