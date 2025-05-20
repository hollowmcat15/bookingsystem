import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class ManageSpa extends StatefulWidget {
  final int? spaId;

  const ManageSpa({super.key, this.spaId});

  @override
  _ManageSpaState createState() => _ManageSpaState();
}

class _ManageSpaState extends State<ManageSpa> {
  final SupabaseClient supabase = Supabase.instance.client;
  Map<String, dynamic>? spa;
  List<Map<String, dynamic>> services = [];
  bool isLoading = true;
  
  // Form keys for validation
  final _spaFormKey = GlobalKey<FormState>();
  final _serviceFormKey = GlobalKey<FormState>();
  
  // Text controllers for the spa form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  // Text controllers for the service form fields
  final TextEditingController _serviceNameController = TextEditingController();
  final TextEditingController _servicePriceController = TextEditingController();
  
  // Currently selected service for editing
  Map<String, dynamic>? selectedService;

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  String? _currentImageUrl;
  bool _isUploadingImage = false;
  
  @override
  void initState() {
    super.initState();
    _fetchSpaAndServices();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _postalCodeController.dispose();
    _phoneNumberController.dispose();
    _descriptionController.dispose();
    _serviceNameController.dispose();
    _servicePriceController.dispose();
    super.dispose();
  }
  
  /// Fetch spa details and services from the database
  Future<void> _fetchSpaAndServices() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      // If spaId is provided through constructor, use that; otherwise check if we're already managing a spa
      int? targetSpaId = widget.spaId;
      
      if (targetSpaId == null) {
        // Attempt to get the manager's spa ID from user data
        final User? user = supabase.auth.currentUser;
        if (user != null) {
          final managerData = await supabase
              .from('manager')
              .select('spa_id')
              .eq('auth_id', user.id)
              .single();
          
          if (managerData != null) {
            targetSpaId = managerData['spa_id'];
          }
        }
      }
      
      // If we have a spa ID, fetch the spa details
      if (targetSpaId != null) {
        final spaResponse = await supabase
            .from('spa')
            .select('*')
            .eq('spa_id', targetSpaId)
            .single();
        
        // Fetch services for this spa
        final servicesResponse = await supabase
            .from('service')
            .select('*')
            .eq('spa_id', targetSpaId);
        
        if (mounted) {
          setState(() {
            spa = spaResponse;
            services = List<Map<String, dynamic>>.from(servicesResponse);
            
            // Populate form fields if spa details are available
            if (spa != null) {
              _nameController.text = spa!['spa_name'] ?? '';
              _addressController.text = spa!['spa_address'] ?? '';
              _postalCodeController.text = spa!['postal_code'] ?? '';
              _phoneNumberController.text = spa!['spa_phonenumber'] ?? '';
              _descriptionController.text = spa!['description'] ?? '';
              _currentImageUrl = spa!['image_url'];
            }
            
            isLoading = false;
          });
        }
      } else {
        // No specific spa to manage, fetch all spas (fallback to original behavior)
        final spasResponse = await supabase.from('spa').select('*');
        
        if (mounted) {
          setState(() {
            // Use the first spa in the list or leave null if none exist
            if (spasResponse.isNotEmpty) {
              spa = spasResponse[0];
              _nameController.text = spa!['spa_name'] ?? '';
              _addressController.text = spa!['spa_address'] ?? '';
              _postalCodeController.text = spa!['postal_code'] ?? '';
              _phoneNumberController.text = spa!['spa_phonenumber'] ?? '';
              _descriptionController.text = spa!['description'] ?? '';
              
              // Fetch services for this spa
              _fetchServicesForSpa(spa!['spa_id']);
            }
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _showErrorSnackBar('Error fetching spa details: $e');
      }
    }
  }
  
  /// Fetch services for a specific spa
  Future<void> _fetchServicesForSpa(int spaId) async {
    try {
      final servicesResponse = await supabase
          .from('service')
          .select('*')
          .eq('spa_id', spaId);
      
      if (mounted) {
        setState(() {
          services = List<Map<String, dynamic>>.from(servicesResponse);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching services: $e');
    }
  }
  
  /// Update existing spa in the database
  Future<void> _updateSpa() async {
    if (!_spaFormKey.currentState!.validate() || spa == null) return;
    
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final String? newImageUrl = await _uploadImage();
      
      await supabase.from('spa').update({
        'spa_name': _nameController.text,
        'spa_address': _addressController.text,
        'postal_code': _postalCodeController.text,
        'spa_phonenumber': _phoneNumberController.text,
        'description': _descriptionController.text,
        'image_url': newImageUrl ?? _currentImageUrl,
        'updated_at': today
      }).eq('spa_id', spa!['spa_id']);
      
      _fetchSpaAndServices();
      _showSuccessSnackBar('Spa updated successfully!');
    } catch (e) {
      _showErrorSnackBar('Error updating spa: $e');
    }
  }
  
  /// Add new service to the database
  Future<void> _addService() async {
    if (!_serviceFormKey.currentState!.validate() || spa == null) return;
    
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Get the global max service_id from the service table
      final maxIdResponse = await supabase
          .from('service')
          .select('service_id')
          .order('service_id', ascending: false)
          .limit(1);
      
      // Calculate next ID (if no services exist, start with 1)
      int nextId = 1;
      if (maxIdResponse.isNotEmpty) {
        nextId = (maxIdResponse[0]['service_id'] as int) + 1;
      }
      
      // Parse price to ensure it's a valid decimal
      double price = double.tryParse(_servicePriceController.text) ?? 0.0;
      
      await supabase.from('service').insert({
        'service_id': nextId,
        'spa_id': spa!['spa_id'],
        'service_name': _serviceNameController.text,
        'service_price': price,
        'created_at': today,
        'updated_at': today
      });
      
      _clearServiceForm();
      _fetchServicesForSpa(spa!['spa_id']);
      _showSuccessSnackBar('Service added successfully!');
    } catch (e) {
      _showErrorSnackBar('Error adding service: $e');
    }
  }
  
  /// Update existing service in the database
  Future<void> _updateService() async {
    if (!_serviceFormKey.currentState!.validate() || selectedService == null) return;
    
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Parse price to ensure it's a valid decimal
      double price = double.tryParse(_servicePriceController.text) ?? 0.0;
      
      await supabase.from('service').update({
        'service_name': _serviceNameController.text,
        'service_price': price,
        'updated_at': today
      }).eq('service_id', selectedService!['service_id']);
      
      _clearServiceForm();
      _fetchServicesForSpa(spa!['spa_id']);
      _showSuccessSnackBar('Service updated successfully!');
    } catch (e) {
      _showErrorSnackBar('Error updating service: $e');
    }
  }
  
  /// Delete service from the database
  Future<void> _deleteService(int serviceId) async {
    try {
      // Check for any appointments using this service
      final appointmentsResponse = await supabase
          .from('appointment')
          .select('book_id')
          .eq('service_id', serviceId);
      
      if (appointmentsResponse.isNotEmpty) {
        _showErrorSnackBar(
          'Cannot delete this service because it is used in appointments. '
          'Please update those appointments first.'
        );
        return;
      }
      
      await supabase
          .from('service')
          .delete()
          .eq('service_id', serviceId);
      
      _fetchServicesForSpa(spa!['spa_id']);
      _showSuccessSnackBar('Service deleted successfully!');
    } catch (e) {
      _showErrorSnackBar('Error deleting service: $e');
    }
  }
  
  /// Load service data into form for editing
  void _editService(Map<String, dynamic> service) {
    setState(() {
      selectedService = service;
      _serviceNameController.text = service['service_name'] ?? '';
      _servicePriceController.text = service['service_price'].toString();
    });
  }
  
  /// Clear service form and reset selected service
  void _clearServiceForm() {
    _serviceNameController.clear();
    _servicePriceController.clear();
    setState(() {
      selectedService = null;
    });
  }
  
  /// Show a success message
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  /// Show an error message
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  /// Show the form dialog for adding or editing a service
  void _showServiceFormDialog({bool isEditing = false}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Service' : 'Add Service'),
          content: SingleChildScrollView(
            child: Form(
              key: _serviceFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _serviceNameController,
                    decoration: const InputDecoration(labelText: 'Service Name *'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a service name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _servicePriceController,
                    decoration: const InputDecoration(
                      labelText: 'Price *',
                      prefixText: '₱',
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a price';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
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
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_serviceFormKey.currentState!.validate()) {
                  Navigator.of(context).pop();
                  if (isEditing) {
                    _updateService();
                  } else {
                    _addService();
                  }
                }
              },
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        );
      },
    );
  }
  
  /// Show confirmation dialog before deleting a service
  void _showDeleteServiceConfirmation(int serviceId, String serviceName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Service'),
          content: Text('Are you sure you want to delete "$serviceName"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteService(serviceId);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _pickImage() async {
    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text('Select Image Source'),
          actions: <Widget>[
            TextButton(
              child: Text('Camera'),
              onPressed: () => Navigator.pop(context, ImageSource.camera),
            ),
            TextButton(
              child: Text('Gallery'),
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      );

      if (source != null) {
        final XFile? pickedFile = await _picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        
        if (pickedFile != null) {
          setState(() {
            _imageFile = File(pickedFile.path);
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _currentImageUrl;
    
    setState(() => _isUploadingImage = true);
    try {
      final User? user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final String fileExtension = path.extension(_imageFile!.path);
      final String fileName = '${const Uuid().v4()}$fileExtension';
      
      // Delete old image if exists
      if (_currentImageUrl != null) {
        try {
          final oldFileName = _currentImageUrl!.split('/').last;
          await supabase.storage.from('spa_images').remove([oldFileName]);
        } catch (e) {
          print('Error deleting old image: $e');
        }
      }
      
      // Upload new image
      await supabase.storage.from('spa_images').upload(
        fileName,
        _imageFile!,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,
        ),
      );
      
      // Get public URL
      return supabase.storage.from('spa_images').getPublicUrl(fileName);
    } catch (e) {
      print('Storage error details: $e');
      if (e.toString().contains('not authenticated')) {
        _showErrorSnackBar('Please log in to upload images');
      } else {
        _showErrorSnackBar('Error uploading image. Please try again.');
      }
      return null;
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Spa'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : spa == null
              ? const Center(child: Text('No spa found to manage.'))
              : DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Spa Information'),
                          Tab(text: 'Services'),
                        ],
                        labelColor: Colors.blue,
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Spa Information Tab
                            _buildSpaInfoTab(),
                            // Services Tab
                            _buildServicesTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
  
  /// Build the Spa Information tab
  Widget _buildSpaInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _spaFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    image: (_imageFile != null)
                        ? DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          )
                        : (_currentImageUrl != null)
                            ? DecorationImage(
                                image: NetworkImage(_currentImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                  ),
                  child: _imageFile == null && _currentImageUrl == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey[600]),
                            SizedBox(height: 8),
                            Text('Add Spa Image', style: TextStyle(color: Colors.grey[600])),
                          ],
                        )
                      : null,
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Spa Details',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Spa Name *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a spa name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _postalCodeController,
              decoration: const InputDecoration(
                labelText: 'Postal Code *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a postal code';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneNumberController,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a phone number';
                }
                if (value.length < 10 || value.length > 11) {
                  return 'Phone number must be 10-11 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _updateSpa,
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build the Services tab
  Widget _buildServicesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Services',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _clearServiceForm();
                  _showServiceFormDialog();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Service'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: services.isEmpty
                ? const Center(
                    child: Text(
                      'No services available. Add services to your spa.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: services.length,
                    itemBuilder: (context, index) {
                      final service = services[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            service['service_name'] ?? 'Unnamed Service',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('₱${service['service_price'].toStringAsFixed(2)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  _editService(service);
                                  _showServiceFormDialog(isEditing: true);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _showDeleteServiceConfirmation(
                                    service['service_id'],
                                    service['service_name'],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}