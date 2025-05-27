import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminManageManager extends StatefulWidget {
  const AdminManageManager({super.key});

  @override
  _AdminManageManagerState createState() => _AdminManageManagerState();
}

class _AdminManageManagerState extends State<AdminManageManager> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> managers = [];
  bool _isLoading = false;
  String? _error;
  bool _isPasswordVisible = false; // Add this line at class level

  @override
  void initState() {
    super.initState();
    _fetchManagers();
  }

  Future<void> _fetchManagers() async {
    try {
      setState(() => _isLoading = true);
      
      // Update query to get managers and their managed spas
      final response = await supabase
          .from('staff')
          .select('''
            staff_id,
            first_name,
            last_name,
            email,
            phonenumber,
            birthday,
            is_active,
            managed_spas:spa!fk_manager(
              spa_id,
              spa_name,
              spa_address,
              spa_phonenumber
            )
          ''')
          .eq('role', 'Manager');

      setState(() {
        managers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading managers: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _verifyAndUpdatePassword(String newPassword, String email, int staffId) async {
    try {
      // Send email OTP instead of reset password
      await supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false, // Important: don't create new user
      );

      // Show OTP verification dialog
      final otpVerified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final otpController = TextEditingController();
          return AlertDialog(
            title: const Text('Verify OTP'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('An OTP code has been sent to $email'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: otpController,
                  decoration: const InputDecoration(
                    labelText: 'Enter Code',
                    hintText: 'Enter the OTP code sent to your email'
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    // Verify OTP
                    final response = await supabase.auth.verifyOTP(
                      type: OtpType.magiclink,
                      email: email,
                      token: otpController.text,
                    );

                    if (response.session != null) {
                      // Update password using the verified session
                      await supabase.auth.updateUser(
                        UserAttributes(password: newPassword),
                      );

                      // Update database password
                      await supabase
                          .from('staff')
                          .update({'password': newPassword})
                          .eq('staff_id', staffId);

                      if (mounted) Navigator.pop(context, true);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid OTP code. Please try again.')),
                      );
                    }
                  }
                },
                child: const Text('Verify'),
              ),
            ],
          );
        },
      );

      if (otpVerified == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating password: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _updateManager(Map<String, dynamic> manager) async {
    try {
      final formKey = GlobalKey<FormState>();
      final firstNameController = TextEditingController(text: manager['first_name'] ?? '');
      final lastNameController = TextEditingController(text: manager['last_name'] ?? '');
      final phoneController = TextEditingController(text: manager['phonenumber'] ?? '');
      final passwordController = TextEditingController(); // Add this line
      
      // Parse the birthday string and remove time component
      String? birthdayStr = manager['birthday']?.toString().split('T')[0];
      DateTime? selectedDate = birthdayStr != null ? DateTime.parse(birthdayStr) : null;
      
      // Add name validation function
      String? validateName(String? value, String fieldName) {
        if (value == null || value.isEmpty) {
          return '$fieldName is required';
        }
        // Only allow letters, spaces, and hyphens
        if (!RegExp(r"^[a-zA-Z\s-]+$").hasMatch(value)) {
          return '$fieldName can only contain letters, spaces, and hyphens';
        }
        return null;
      }

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Edit Manager Details'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        helperText: 'Only letters, spaces, and hyphens allowed',
                      ),
                      validator: (value) => validateName(value, 'First name'),
                    ),
                    TextFormField(
                      controller: lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        helperText: 'Only letters, spaces, and hyphens allowed',
                      ),
                      validator: (value) => validateName(value, 'Last name'),
                    ),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                      maxLength: 11, // Add max length
                      keyboardType: TextInputType.number, // Add numeric keyboard
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Phone number is required';
                        if (value!.length != 11) return 'Phone number must be 11 digits';
                        return null;
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Birthday: ${selectedDate?.toString().split(' ')[0] ?? 'Not set'}',
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                selectedDate = picked;
                                (context as Element).markNeedsBuild();
                              }
                            },
                            child: const Text('Select Date'),
                          ),
                        ],
                      ),
                    ),
                    TextFormField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: 'New Password (optional)',
                        hintText: 'Leave blank to keep current password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setStateDialog(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      obscureText: !_isPasswordVisible,
                      validator: (value) {
                        if (value?.isEmpty == true) return null; // Password is optional
                        if (value!.length < 8) return 'Password must be at least 8 characters';
                        if (!value.contains(RegExp(r'[A-Z]'))) {
                          return 'Password must contain at least one uppercase letter';
                        }
                        if (!value.contains(RegExp(r'[a-z]'))) {
                          return 'Password must contain at least one lowercase letter';
                        }
                        if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                          return 'Password must contain at least one special character';
                        }
                        if (!value.contains(RegExp(r'[0-9]'))) {
                          return 'Password must contain at least one number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (formKey.currentState?.validate() == true && selectedDate != null) {
                    Navigator.pop(context, true);
                  } else if (selectedDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a birthday')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );

      if (result == true) {
        final updateData = {
          'first_name': firstNameController.text,
          'last_name': lastNameController.text,
          'phonenumber': phoneController.text,
          'birthday': selectedDate?.toString().split(' ')[0], // Format as YYYY-MM-DD
        };

        // Handle password update separately with OTP verification
        if (passwordController.text.isNotEmpty) {
          await _verifyAndUpdatePassword(
            passwordController.text,
            manager['email'] as String,
            manager['staff_id'] as int,
          );
        }

        // Update other data
        await supabase
            .from('staff')
            .update(updateData)
            .eq('staff_id', manager['staff_id']);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Manager updated successfully')),
          );
          _fetchManagers();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating manager: $e')),
        );
      }
    }
  }

  Future<void> _toggleManagerStatus(Map<String, dynamic> manager) async {
    try {
      final newStatus = !(manager['is_active'] ?? true);
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(newStatus ? 'Enable Account' : 'Disable Account'),
          content: Text(
            'Are you sure you want to ${newStatus ? 'enable' : 'disable'} '
            'this manager\'s account?\n\n'
            'Manager: ${manager['first_name']} ${manager['last_name']}'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(newStatus ? 'Enable' : 'Disable'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await supabase
            .from('staff')
            .update({'is_active': newStatus})
            .eq('staff_id', manager['staff_id']);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account ${newStatus ? 'enabled' : 'disabled'} successfully'),
          ),
        );
        _fetchManagers();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating account status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Managers'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      ElevatedButton(
                        onPressed: _fetchManagers,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchManagers,
                  child: managers.isEmpty
                      ? const Center(child: Text('No managers found'))
                      : ListView.builder(
                          itemCount: managers.length,
                          itemBuilder: (context, index) {
                            final manager = managers[index];
                            final managedSpas = manager['managed_spas'] as List<dynamic>;
                            
                            return Card(
                              margin: const EdgeInsets.all(8),
                              child: ExpansionTile(
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${manager['first_name']} ${manager['last_name']}',
                                        style: TextStyle(
                                          color: manager['is_active'] == false 
                                              ? Colors.grey 
                                              : null,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _updateManager(manager),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        manager['is_active'] == false 
                                            ? Icons.check_circle_outline 
                                            : Icons.block,
                                        color: manager['is_active'] == false 
                                            ? Colors.green 
                                            : Colors.red,
                                      ),
                                      onPressed: () => _toggleManagerStatus(manager),
                                    ),
                                  ],
                                ),
                                subtitle: Text(manager['email']),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Phone: ${manager['phonenumber']}'),
                                        if (manager['birthday'] != null)
                                          Text('Birthday: ${manager['birthday'].toString().split('T')[0]}'),
                                        const SizedBox(height: 16),
                                        if (managedSpas.isNotEmpty) ...[
                                          const Text('Managing Spas:',
                                              style: TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          ...managedSpas.map((spa) => Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(spa['spa_name']),
                                                Text(spa['spa_address']),
                                                Text('Phone: ${spa['spa_phonenumber']}'),
                                                const Divider(),
                                              ],
                                            ),
                                          )).toList(),
                                        ] else
                                          const Text('\nNo spa currently assigned',
                                              style: TextStyle(fontStyle: FontStyle.italic)),
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
}
