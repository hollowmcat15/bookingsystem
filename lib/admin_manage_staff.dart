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

      // For managers, specify the manager-spa relationship using fk_manager
      final managerResponse = await supabase
          .from('staff')
          .select('''
            *,
            managed_spa:spa!fk_manager(
              spa_id,
              spa_name,
              spa_address,
              spa_phonenumber
            )
          ''')
          .eq('role', 'Manager');

      // For other staff, use the explicit staff-spa relationship
      final otherStaffResponse = await supabase
          .from('staff')
          .select('''
            *,
            spa:spa!staff_spa_id_fkey(
              spa_id,
              spa_name,
              spa_address,
              spa_phonenumber
            )
          ''')
          .neq('role', 'Manager');

      final managers = List<Map<String, dynamic>>.from(managerResponse);
      final otherStaff = List<Map<String, dynamic>>.from(otherStaffResponse);

      final groupedStaff = {
        'Manager': managers,
        'Therapist': otherStaff.where((s) => s['role'] == 'Therapist').toList(),
        'Receptionist': otherStaff.where((s) => s['role'] == 'Receptionist').toList(),
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
            // Update spa info access based on role
            final spaInfo = role == 'Manager' 
                ? (staff['managed_spa'] != null && staff['managed_spa'].length > 0 
                    ? staff['managed_spa'][0] 
                    : null)
                : staff['spa'];
            
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text('${staff['first_name']} ${staff['last_name']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (spaInfo != null) 
                      Text('Spa: ${spaInfo['spa_name']}')
                    else
                      Text('No Spa Assigned'),
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
    // Filter staff based on selected role
    List<Widget> staffLists = [];
    
    if (_selectedRole == 'All') {
      staffLists = [
        _buildStaffList('Manager'),
        SizedBox(height: 16),
        _buildStaffList('Therapist'),
        SizedBox(height: 16),
        _buildStaffList('Receptionist'),
      ];
    } else {
      staffLists = [_buildStaffList(_selectedRole)];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Staff Management'),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: DropdownButton<String>(
              value: _selectedRole,
              underline: Container(), // Remove the underline
              items: [
                DropdownMenuItem(value: 'All', child: Text('All Roles')),
                DropdownMenuItem(value: 'Manager', child: Text('Managers')),
                DropdownMenuItem(value: 'Therapist', child: Text('Therapists')),
                DropdownMenuItem(value: 'Receptionist', child: Text('Receptionists')),
              ],
              onChanged: (value) {
                setState(() => _selectedRole = value!);
              },
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(children: staffLists),
                ),
    );
  }
}
