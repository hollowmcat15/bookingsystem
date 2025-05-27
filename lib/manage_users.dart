import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'widgets/otp_verification_dialog.dart'; // Add this import

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
  List<Map<String, dynamic>> _staff = []; // Change to use unified staff table
  String _searchQuery = '';
  String _currentFilter = 'All';
  final List<String> _filterOptions = ['All', 'Therapists', 'Receptionists'];
  String _selectedUserType = 'Therapist';
  String _selectedStatus = 'Active'; // For therapists
  DateTime _selectedBirthday = DateTime.now().subtract(Duration(days: 365 * 18)); // Changed to 18 years ago

  // Form controllers for creating new user
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // Update validation function to be more strict
  bool _isValidName(String name) {
    // Only allow letters, spaces, and hyphens - no emojis or special characters
    return RegExp(r"^[a-zA-Z\s-]+$").hasMatch(name);
  }

  // Add password validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$')
        .hasMatch(value)) {
      return 'Password must contain uppercase, lowercase,\nnumber and special character';
    }
    return null;
  }

  // Add phone validation
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length != 11) {
      return 'Phone number must be exactly 11 digits';
    }
    if (!RegExp(r'^\d{11}$').hasMatch(value)) {
      return 'Please enter valid phone number';
    }
    return null;
  }

  // Add birthday validation method
  String? _validateBirthday(DateTime? date) {
    if (date == null) {
      return 'Birthday is required';
    }
    final now = DateTime.now();
    final minimumYear = now.year - 18;  // Must be at least 18 years old
    
    if (date.year >= minimumYear) {
      return 'Must be at least 18 years old';
    }
    return null;
  }

  // Update birthday selection logic
  Future<void> _selectBirthday(BuildContext context) async {
    final currentYear = DateTime.now().year;
    final minimumYear = currentYear - 18;  // Must be at least 18 years old
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday,
      firstDate: DateTime(1940),
      lastDate: DateTime(minimumYear),  // Cannot select dates less than 18 years ago
    );
    
    if (picked != null && picked != _selectedBirthday) {
      setState(() => _selectedBirthday = picked);
    }
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
              : SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            TextField(
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: 'Search',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                suffixIcon: Icon(Icons.search),
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _currentFilter,
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _currentFilter = newValue!;
                                    });
                                  },
                                  items: _filterOptions.map<DropdownMenuItem<String>>(
                                    (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    },
                                  ).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _filteredUsers.length,
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${user['first_name']} ${user['last_name']}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: user['is_active'] == true ? null : Colors.grey,
                                                ),
                                              ),
                                              Text(
                                                user['is_active'] == true ? 'Active' : 'Disabled',
                                                style: TextStyle(
                                                  color: user['is_active'] == true ? Colors.green : Colors.red,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.edit, size: 20),
                                              onPressed: () => _editUser(user),
                                              constraints: BoxConstraints(),
                                              padding: EdgeInsets.all(8),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                user['is_active'] == true ? Icons.block : Icons.check_circle,
                                                size: 20,
                                                color: user['is_active'] == true ? Colors.red : Colors.green,
                                              ),
                                              onPressed: () => _toggleUserStatus(user),
                                              constraints: BoxConstraints(),
                                              padding: EdgeInsets.all(8),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text('Email: ${user['email']}'),
                                    Text('Phone: ${user['phonenumber']}'),
                                    if (user['role'] == 'Therapist') ...[
                                      Text('Status: ${user['status']}'),
                                      Text('Commission: ${user['commission_percentage']}%'),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _showAddUserDialog,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text('Add User'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Future<void> _fetchUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch all staff members for this spa except managers
      final staffResponse = await supabase
          .from('staff')
          .select('*')
          .eq('spa_id', widget.spaId)
          .neq('role', 'Manager')
          .order('created_at', ascending: false);

      setState(() {
        _staff = List<Map<String, dynamic>>.from(staffResponse);
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
    return _staff.where((staff) {
      // Filter by role
      if (_currentFilter == 'Therapists' && staff['role'] != 'Therapist') return false;
      if (_currentFilter == 'Receptionists' && staff['role'] != 'Receptionist') return false;

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final String firstName = staff['first_name']?.toString().toLowerCase() ?? '';
        final String lastName = staff['last_name']?.toString().toLowerCase() ?? '';
        final String email = staff['email']?.toString().toLowerCase() ?? '';
        return firstName.contains(_searchQuery.toLowerCase()) || 
               lastName.contains(_searchQuery.toLowerCase()) ||
               email.contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();
  }

  // Add this method to toggle user active status
  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    try {
      setState(() => _isLoading = true);
      
      final newStatus = !(user['is_active'] ?? true);
      
      // Update both is_active and status fields
      await supabase
          .from('staff')
          .update({
            'is_active': newStatus,
            'status': newStatus ? 'Active' : 'Inactive', // Update status for all staff types
          })
          .eq('staff_id', user['staff_id']);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Account enabled' : 'Account disabled'),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
          ),
        );
      }

      await _fetchUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating account status: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Update the password field builder to accept setState
  Widget _buildPasswordField(StateSetter setBuilderState, ValueNotifier<bool> isPasswordVisible) {
    return ValueListenableBuilder<bool>(
      valueListenable: isPasswordVisible,
      builder: (context, visible, _) {
        return TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                visible ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey,
              ),
              onPressed: () => isPasswordVisible.value = !visible,
            ),
            helperText: '8+ chars with upper/lowercase, number, symbol',
            helperStyle: TextStyle(fontSize: 12),
          ),
          obscureText: !visible,
          validator: _validatePassword,
        );
      },
    );
  }

  // Add this method to show the add user dialog
  void _showAddUserDialog({bool isEdit = false, Map<String, dynamic>? userData}) {
    final addUserFormKey = GlobalKey<FormState>();
    if (!isEdit) _resetFormControllers();
    final isPasswordVisible = ValueNotifier<bool>(false);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // More rounded corners
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.7, // Reduced from 0.8
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  backgroundColor: Colors.transparent, // Make scaffold transparent
                  appBar: PreferredSize(
                    preferredSize: Size.fromHeight(60),
                    child: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      title: Text(isEdit ? 'Edit User' : 'Add New User'),
                      automaticallyImplyLeading: false,
                      actions: [
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), // Reduced top padding
                      child: Form(
                        key: addUserFormKey, // Use the local form key
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min, // Make content compact
                          children: [
                            // User Type Dropdown
                            Container(
                              margin: EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedUserType,
                                decoration: InputDecoration(
                                  labelText: 'User Type',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                items: ['Therapist', 'Receptionist'].map((String type) {
                                  return DropdownMenuItem(value: type, child: Text(type));
                                }).toList(),
                                onChanged: (String? value) {
                                  setState(() => _selectedUserType = value ?? 'Therapist');
                                },
                              ),
                            ),

                            // Name Fields Row
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _firstNameController,
                                    decoration: InputDecoration(
                                      labelText: 'First Name',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lastNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Last Name',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),

                            // Contact Information
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                            SizedBox(height: 20),

                            TextFormField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: 'Phone',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              keyboardType: TextInputType.phone,
                              maxLength: 11,
                              validator: _validatePhone,
                            ),
                            SizedBox(height: 20),

                            // Password Field
                            if (!isEdit) _buildPasswordField(setState, isPasswordVisible),
                            SizedBox(height: 20),

                            // Birthday Field
                            GestureDetector(
                              onTap: () => _selectBirthday(context),
                              child: AbsorbPointer(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: 'Birthday',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  controller: TextEditingController(
                                    text: DateFormat('yyyy-MM-dd').format(_selectedBirthday),
                                  ),
                                  validator: (value) {
                                    // Validate birthday only if it's not empty
                                    if (value?.isEmpty ?? true) {
                                      return 'Required';
                                    }
                                    return _validateBirthday(_selectedBirthday);
                                  },
                                ),
                              ),
                            ),
                            SizedBox(height: 32),

                            // Action Buttons
                            Padding(
                              padding: const EdgeInsets.only(top: 20), // Reduced padding
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text('Cancel'),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        if (addUserFormKey.currentState!.validate()) {
                                          if (isEdit) {
                                            await _updateUser(userData!);
                                          } else {
                                            await _createStaffUser();
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(isEdit ? 'Save Changes' : 'Add User'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    ).then((_) => isPasswordVisible.dispose()); // Clean up the ValueNotifier
  }

  // Add helper method to reset form controllers
  void _resetFormControllers() {
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
  }

  // Fix getRoleLabel method signature
  String getRoleLabel(String role) { // Remove underscore from method name
    switch (role) {
      case 'Therapist':
        return 'Therapist';
      case 'Receptionist':
        return 'Receptionist';
      default:
        return 'Staff';
    }
  }

  // Add this method to handle user editing
  void _editUser(Map<String, dynamic> user) {
    _firstNameController.text = user['first_name'] ?? '';
    _lastNameController.text = user['last_name'] ?? '';
    _emailController.text = user['email'] ?? '';
    _phoneController.text = user['phonenumber'] ?? '';
    _selectedUserType = user['role'] ?? 'Therapist';
    _selectedStatus = user['status'] ?? 'Active';
    
    _showAddUserDialog(isEdit: true, userData: user);
  }

  // Add method to update user
  Future<void> _updateUser(Map<String, dynamic> userData) async {
    try {
      setState(() => _isLoading = true);

      // Update staff table
      await supabase.from('staff').update({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phonenumber': _phoneController.text.trim(),
        'role': _selectedUserType,
        'status': _selectedStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('staff_id', userData['staff_id']);

      // Refresh the list and show success message
      await _fetchUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createStaffUser() async {
    try {
      setState(() => _isLoading = true);

      // Create user and send OTP
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'role': _selectedUserType,
          'spa_id': widget.spaId,
        },
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create user account');
      }

      // Show OTP verification dialog
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => OTPVerificationDialog(
          email: _emailController.text.trim(),
          title: 'Verify Staff Account',
          message: 'Enter the verification code sent to ${_emailController.text}',
          type: OtpType.signup,
        ),
      );

      if (verified != true) {
        throw Exception('Email verification failed');
      }

      // If verification successful, create staff record
      await supabase.from('staff').insert({
        'spa_id': widget.spaId,
        'auth_id': authResponse.user!.id,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phonenumber': _phoneController.text.trim(),
        'birthday': _selectedBirthday.toIso8601String(),
        'role': _selectedUserType,
        'status': 'Active',
        'commission_percentage': _selectedUserType == 'Therapist' ? 25.0 : 0.0,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      Navigator.pop(context); // Close add user dialog
      await _fetchUsers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Staff account created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error creating user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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