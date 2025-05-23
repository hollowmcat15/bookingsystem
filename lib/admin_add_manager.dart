import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminAddManager extends StatefulWidget {
  @override
  _AdminAddManagerState createState() => _AdminAddManagerState();
}

class _AdminAddManagerState extends State<AdminAddManager> {
  final _formKey = GlobalKey<FormState>();
  final _managerFormKey = GlobalKey<FormState>();
  final _spaFormKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // Manager Details Controllers
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthdayController = TextEditingController();

  // Spa Details Controllers
  final _spaNameController = TextEditingController();
  final _spaAddressController = TextEditingController();
  final _spaPostalCodeController = TextEditingController();
  final _spaPhoneController = TextEditingController();
  final _spaDescriptionController = TextEditingController();
  
  bool _isLoading = false;
  DateTime? _selectedDate;

  // Emoji detection regex
  final RegExp emojiRegex = RegExp(
    r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F000}-\u{1F02F}]|[\u{1F0A0}-\u{1F0FF}]|[\u{1F100}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{1F910}-\u{1F96B}]',
    unicode: true
  );

  String? _validateNoEmoji(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (emojiRegex.hasMatch(value)) {
      return 'Emojis are not allowed in $fieldName';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (value.length != 11) {
      return 'Phone number must be 11 digits';
    }
    if (!RegExp(r'^\d{11}$').hasMatch(value)) {
      return 'Enter a valid 11 digit phone number';
    }
    return null;
  }

  Future<void> _addManagerAndSpa() async {
    if (!_managerFormKey.currentState!.validate() || 
        !_spaFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create auth user
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text,
        password: 'temppass123', // Temporary password
        data: {'role': 'manager'},
      );

      if (authResponse.user == null) throw Exception('Failed to create user');

      // 2. Add to staff table
      final staffResponse = await supabase.from('staff').insert({
        'auth_id': authResponse.user!.id,
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'email': _emailController.text,
        'phonenumber': _phoneController.text,
        'birthday': _selectedDate?.toIso8601String(),
        'role': 'Manager',
        'status': 'Active',
      }).select();

      if (staffResponse.isEmpty) throw Exception('Failed to create staff record');

      // 3. Create spa
      await supabase.from('spa').insert({
        'manager_id': staffResponse[0]['staff_id'],
        'spa_name': _spaNameController.text,
        'spa_address': _spaAddressController.text,
        'postal_code': _spaPostalCodeController.text,
        'spa_phonenumber': _spaPhoneController.text,
        'description': _spaDescriptionController.text,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Manager and Spa added successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add New Manager with Spa'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Manager Details Section
                    Text('Manager Details', 
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 16),
                    Form(
                      key: _managerFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(labelText: 'Email'),
                            validator: (value) => _validateNoEmoji(value, 'Email'),
                          ),
                          TextFormField(
                            controller: _firstNameController,
                            decoration: InputDecoration(labelText: 'First Name'),
                            validator: (value) => _validateNoEmoji(value, 'First name'),
                          ),
                          TextFormField(
                            controller: _lastNameController,
                            decoration: InputDecoration(labelText: 'Last Name'),
                            validator: (value) => _validateNoEmoji(value, 'Last name'),
                          ),
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(labelText: 'Phone Number'),
                            validator: _validatePhone,
                            keyboardType: TextInputType.phone,
                            maxLength: 11,
                          ),
                          TextFormField(
                            controller: _birthdayController,
                            decoration: InputDecoration(
                              labelText: 'Birthday',
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            readOnly: true,
                            onTap: () => _selectDate(context),
                            validator: (value) => value?.isEmpty ?? true 
                                ? 'Birthday is required' 
                                : null,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),

                    // Spa Details Section
                    Text('Spa Details', 
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 16),
                    Form(
                      key: _spaFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _spaNameController,
                            decoration: InputDecoration(labelText: 'Spa Name'),
                            validator: (value) => _validateNoEmoji(value, 'Spa name'),
                          ),
                          TextFormField(
                            controller: _spaAddressController,
                            decoration: InputDecoration(labelText: 'Spa Address'),
                            validator: (value) => _validateNoEmoji(value, 'Address'),
                          ),
                          TextFormField(
                            controller: _spaPostalCodeController,
                            decoration: InputDecoration(labelText: 'Postal Code'),
                            validator: (value) => _validateNoEmoji(value, 'Postal code'),
                          ),
                          TextFormField(
                            controller: _spaPhoneController,
                            decoration: InputDecoration(labelText: 'Spa Phone Number'),
                            validator: _validatePhone,
                            keyboardType: TextInputType.phone,
                            maxLength: 11,
                          ),
                          TextFormField(
                            controller: _spaDescriptionController,
                            decoration: InputDecoration(labelText: 'Description'),
                            validator: (value) => _validateNoEmoji(value, 'Description'),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),

                    Center(
                      child: ElevatedButton(
                        onPressed: _addManagerAndSpa,
                        child: Text('Create Manager and Spa'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    _spaNameController.dispose();
    _spaAddressController.dispose();
    _spaPostalCodeController.dispose();
    _spaPhoneController.dispose();
    _spaDescriptionController.dispose();
    super.dispose();
  }
}
