import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'widgets/otp_verification_dialog.dart';
import 'login.dart';  // Updated import

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
  
  // Password change controllers
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
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
  _userId = supabase.auth.currentUser?.id;
  _userEmail = supabase.auth.currentUser?.email;
  
  switch (widget.userRole.toLowerCase()) {
    case 'admin':
      _tableName = 'admin';
      _userIdField = 'admin_id';
      _firstNameField = 'first_name';
      _lastNameField = 'last_name';
      _phoneField = null;
      _hasAddressField = false;
      _hasBirthdayField = false;
      _hasStatusField = false;
      break;
      
    case 'manager':
    case 'therapist':
    case 'receptionist':
      _tableName = 'staff';
      _userIdField = 'staff_id';
      _firstNameField = 'first_name';
      _lastNameField = 'last_name';
      _phoneField = 'phonenumber';
      _birthdayField = 'birthday';
      _addressField = null;
      _hasAddressField = false;
      _hasBirthdayField = true;
      _hasStatusField = false; // Receptionists don't have status
      _statusField = null;
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

      // For staff members (manager, therapist, receptionist)
      if (['manager', 'therapist', 'receptionist'].contains(widget.userRole.toLowerCase())) {
        final response = await supabase
            .from('staff')
            .select()
            .eq('email', _userEmail!)
            .eq('role', widget.userRole.capitalize()) // Make sure role matches exactly
            .limit(1);
        
        if (response != null && response.isNotEmpty) {
          setState(() {
            _userData = response[0];
            _currentStatus = response[0]['status'];
            _isLoading = false;
          });
        } else {
          throw Exception('Staff profile not found');
        }
      } else {
        // For clients and admin, use their respective tables
        final response = await supabase
            .from(_tableName!)
            .select()
            .eq('email', _userEmail!)
            .limit(1);
            
        if (response != null && response.isNotEmpty) {
          setState(() {
            _userData = response[0];
            _isLoading = false;
          });
        } else {
          throw Exception('Profile not found');
        }
      }
      
      _populateFormFields();
    } catch (e) {
      setState(() {
        _error = 'Could not find user profile: ${e.toString()}';
        _isLoading = false;
      });
      print('Error fetching user data: $e');
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final idValue = _userData![_userIdField!];
      final Map<String, dynamic> changes = {
        _firstNameField!: _firstNameController.text,
        _lastNameField!: _lastNameController.text,
        if (_phoneField != null) _phoneField!: _phoneController.text,
        if (_hasBirthdayField && _birthdayField != null && _selectedBirthday != null)
          _birthdayField!: _selectedBirthday!.toIso8601String().split('T')[0],
        'role': widget.userRole.capitalize(), // Ensure role is properly set
        'is_active': true, // Ensure staff remains active
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase
          .from(_tableName!)
          .update(changes)
          .eq(_userIdField!, idValue);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Add new method for password change with OTP
  Future<void> _updatePasswordWithOTP() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("New passwords do not match!")),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      // First verify current password
      final response = await supabase.auth.signInWithPassword(
        email: _userEmail!,
        password: _currentPasswordController.text,
      );

      if (response.user == null) {
        throw Exception('Current password is incorrect');
      }

      // Request OTP using signInWithOtp instead of resetPasswordForEmail
      await supabase.auth.signInWithOtp(
        email: _userEmail!,
        shouldCreateUser: false, // Important: set to false since user exists
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Verification code sent to $_userEmail")),
      );

      // Show OTP verification dialog
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => OTPVerificationDialog(
          email: _userEmail!,
          title: 'Verify Password Change',
          message: 'Please check your email (${_userEmail}) for the verification code',
          type: OtpType.email,  // Changed to email type for OTP
        ),
      );

      if (verified == true) {
        // Update password after OTP verification
        await supabase.auth.updateUser(
          UserAttributes(password: _newPasswordController.text),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Password updated successfully")),
          );
          setState(() {
            _isPasswordChangeMode = false;
            _currentPasswordController.clear();
            _newPasswordController.clear();
            _confirmPasswordController.clear();
          });
        }
      }
    } catch (e) {
      print("Password Update Error: $e"); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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

  Future<void> _pickDate() async {
    final currentYear = DateTime.now().year;
    final minimumYear = currentYear - 18;  // Must be at least 18 years old
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(minimumYear - 5), // Default to 23 years old
      firstDate: DateTime(1940),
      lastDate: DateTime(minimumYear),  // Cannot select dates less than 18 years ago
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

  // Add this validator method after other validation methods
  String? _validateName(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Please enter your $fieldName';
    }
    // Only allow letters, spaces, and hyphens
    if (!RegExp(r"^[a-zA-Z\s-]+$").hasMatch(value)) {
      return '$fieldName can only contain letters, spaces, and hyphens';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : Column(
                  children: [
                    _buildTabBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: _buildForm(),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Theme.of(context).primaryColor,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                _buildTab(
                  title: 'Profile',
                  icon: Icons.person,
                  isSelected: !_isPasswordChangeMode,
                  onTap: () => setState(() {
                    _isPasswordChangeMode = false;
                  }),
                ),
                _buildTab(
                  title: 'Password',
                  icon: Icons.lock,
                  isSelected: _isPasswordChangeMode,
                  onTap: () => setState(() {
                    _isPasswordChangeMode = true;
                  }),
                ),
              ],
            ),
          ),
          Container(
            height: 2,
            color: Colors.white.withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
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
      ),
    );
  }

  Widget _buildForm() {
    return Form(
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

          // Show different forms based on mode
          if (!_isPasswordChangeMode) ...[
            // Original profile edit form fields
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: 'First Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                helperText: 'Only letters, spaces, and hyphens allowed',
              ),
              validator: (value) => _validateName(value, 'first name'),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: 'Last Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                helperText: 'Only letters, spaces, and hyphens allowed',
              ),
              validator: (value) => _validateName(value, 'last name'),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              maxLength: 11,
              buildCounter: (BuildContext context, {
                required int currentLength,
                required bool isFocused,
                required int? maxLength,
              }) {
                return Text('$currentLength/$maxLength');
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                if (value.length != 11) {
                  return 'Phone number must be exactly 11 digits';
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
                onPressed: _updatePasswordWithOTP, // Change this line
                child: Text('Update Password', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Add this extension to capitalize the role
extension StringExtension on String {
    String capitalize() {
        return "${this[0].toUpperCase()}${this.substring(1)}";
    }
}