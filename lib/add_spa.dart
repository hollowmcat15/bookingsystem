import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class AddSpa extends StatefulWidget {
  final int managerId;

  const AddSpa({
    Key? key,
    required this.managerId,
  }) : super(key: key);

  @override
  _AddSpaState createState() => _AddSpaState();
}

class _AddSpaState extends State<AddSpa> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  // Form fields
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Image handling
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  String? _uploadedImageUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _postalCodeController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;
    
    try {
      final String fileExtension = path.extension(_imageFile!.path);
      final String fileName = '${const Uuid().v4()}$fileExtension';
      
      await supabase.storage.from('spa_images').upload(
        fileName,
        _imageFile!,
        fileOptions: FileOptions(
          cacheControl: '3600',
          contentType: 'image/${fileExtension.substring(1)}',
        ),
      );
      
      final String imageUrl = supabase.storage.from('spa_images').getPublicUrl(fileName);
      return imageUrl;
    } catch (e) {
      setState(() {
        _errorMessage = 'Error uploading image: $e';
      });
      return null;
    }
  }

  Future<void> _saveSpa() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Upload image if selected
      if (_imageFile != null) {
        _uploadedImageUrl = await _uploadImage();
        if (_uploadedImageUrl == null && _errorMessage == null) {
          setState(() {
            _errorMessage = 'Failed to upload image';
          });
          return;
        }
      }
      
      // Generate a new spa ID
      final int newSpaId = DateTime.now().millisecondsSinceEpoch % 100000000;
      
      // Insert new spa into database with the manager ID
      await supabase.from('spa').insert({
        'spa_id': newSpaId,
        'manager_id': widget.managerId, // Set the manager_id as foreign key
        'spa_name': _nameController.text,
        'spa_address': _addressController.text,
        'postal_code': _postalCodeController.text,
        'spa_phonenumber': _phoneController.text,
        'description': _descriptionController.text,
        'image_url': _uploadedImageUrl,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      // No need to update manager table separately
      // The relationship is established through manager_id in the spa table
      
      if (mounted) {
        Navigator.pop(context); // Return to dashboard
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error creating spa: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add New Spa'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Spa image selection
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                      image: _imageFile != null
                          ? DecorationImage(
                              image: FileImage(_imageFile!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _imageFile == null
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
              SizedBox(height: 20),
              
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Spa Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter spa name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Address field
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter address';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Postal Code field
              TextFormField(
                controller: _postalCodeController,
                decoration: InputDecoration(
                  labelText: 'Postal Code',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter postal code';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Phone field
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              
              // Error message
              if (_errorMessage != null)
                Container(
                  padding: EdgeInsets.all(8),
                  margin: EdgeInsets.only(bottom: 16),
                  color: Colors.red[100],
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[900]),
                  ),
                ),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSpa,
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Create Spa', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}