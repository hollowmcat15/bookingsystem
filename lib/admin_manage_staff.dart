import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminManageStaff extends StatefulWidget {
  @override
  _AdminManageStaffState createState() => _AdminManageStaffState();
}

class _AdminManageStaffState extends State<AdminManageStaff> {
  final SupabaseClient supabase = Supabase.instance.client;
  Map<String, List<Map<String, dynamic>>> staffByRole = {
    'Manager': [],
    'Therapist': [],
    'Receptionist': [],
  };
  bool _isLoading = false;
  String? _error;
  String _selectedRole = 'All';
  String _sortBy = 'name'; // 'name', 'spa', 'date'

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    try {
      setState(() => _isLoading = true);
      final response = await supabase
          .from('staff')
          .select('''
            *,
            spa!staff_spa_id_fkey (
              spa_id,
              spa_name,
              spa_address,
              spa_phonenumber
            )
          ''')
          .order('created_at');

      final staff = List<Map<String, dynamic>>.from(response);
      final groupedStaff = {
        'Manager': staff.where((s) => s['role'] == 'Manager').toList(),
        'Therapist': staff.where((s) => s['role'] == 'Therapist').toList(),
        'Receptionist': staff.where((s) => s['role'] == 'Receptionist').toList(),
      };

      setState(() {
        staffByRole = groupedStaff;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildStaffList(String role) {
    final staffList = staffByRole[role] ?? [];
    
    return ExpansionTile(
      title: Text('$role Staff (${staffList.length})'),
      initiallyExpanded: true,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: staffList.length,
          itemBuilder: (context, index) {
            final staff = staffList[index];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text('${staff['first_name']} ${staff['last_name']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spa: ${staff['spa']['spa_name']}'),
                    Text('Email: ${staff['email']}'),
                    Text('Phone: ${staff['phonenumber']}'),
                    if (role == 'Therapist')
                      Text('Status: ${staff['status'] ?? 'N/A'}'),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Staff Management'),
        actions: [
          DropdownButton<String>(
            value: _selectedRole,
            items: [
              DropdownMenuItem(value: 'All', child: Text('All Roles')),
              DropdownMenuItem(value: 'Manager', child: Text('Managers')),
              DropdownMenuItem(value: 'Therapist', child: Text('Therapists')),
              DropdownMenuItem(value: 'Receptionist', child: Text('Receptionists')),
            ],
            onChanged: (value) {
              setState(() => _selectedRole = value!);
              _fetchStaff();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildStaffList('Manager'),
                      SizedBox(height: 16),
                      _buildStaffList('Therapist'),
                      SizedBox(height: 16),
                      _buildStaffList('Receptionist'),
                    ],
                  ),
                ),
    );
  }
}
