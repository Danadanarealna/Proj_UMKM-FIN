import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'api.dart';

class ProfileScreen extends StatefulWidget {
  final String username;
  final String email;
  final String umkmName;
  final String umkmContact;
  final bool isInvestable;
  final String? umkmDescription;
  final String? umkmProfileImageUrl;
  final VoidCallback onLogout;
  final Function(String newUmkmName, String newUmkmContact, String newOwnerName, bool newIsInvestable, String? newDescription, String? newImageUrl) onProfileUpdated;
  final Future<void> Function() onRefresh;

  const ProfileScreen({
    required this.username,
    required this.email,
    required this.umkmName,
    required this.umkmContact,
    required this.isInvestable,
    this.umkmDescription,
    this.umkmProfileImageUrl,
    required this.onLogout,
    required this.onProfileUpdated,
    required this.onRefresh,
    super.key,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _currentOwnerName;
  late String _currentEmail;
  late String _currentUmkmName;
  late String _currentUmkmContact;
  late bool _currentIsInvestable;
  late String? _currentUmkmDescription;
  String? _currentUmkmProfileImageUrl;

  bool _isEditing = false;
  bool _isLoading = false;
  File? _profileImageFile;
  final ImagePicker _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ownerNameController;
  late TextEditingController _umkmNameController;
  late TextEditingController _umkmContactController;
  late TextEditingController _umkmDescriptionController;

  @override
  void initState() {
    super.initState();
    _updateLocalStateFromWidget();
    _ownerNameController = TextEditingController(text: _currentOwnerName);
    _umkmNameController = TextEditingController(text: _currentUmkmName);
    _umkmContactController = TextEditingController(text: _currentUmkmContact);
    _umkmDescriptionController = TextEditingController(text: _currentUmkmDescription ?? '');
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.username != oldWidget.username ||
        widget.email != oldWidget.email ||
        widget.umkmName != oldWidget.umkmName ||
        widget.umkmContact != oldWidget.umkmContact ||
        widget.isInvestable != oldWidget.isInvestable ||
        widget.umkmDescription != oldWidget.umkmDescription ||
        widget.umkmProfileImageUrl != oldWidget.umkmProfileImageUrl) {
      _updateLocalStateFromWidget();
      _ownerNameController.text = _currentOwnerName;
      _umkmNameController.text = _currentUmkmName;
      _umkmContactController.text = _currentUmkmContact;
      _umkmDescriptionController.text = _currentUmkmDescription ?? '';
    }
  }

  void _updateLocalStateFromWidget() {
    _currentOwnerName = widget.username;
    _currentEmail = widget.email;
    _currentUmkmName = widget.umkmName;
    _currentUmkmContact = widget.umkmContact;
    _currentIsInvestable = widget.isInvestable;
    _currentUmkmDescription = widget.umkmDescription;
    _currentUmkmProfileImageUrl = widget.umkmProfileImageUrl;
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _umkmNameController.dispose();
    _umkmContactController.dispose();
    _umkmDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfileData() async {
    if (_isEditing && !_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if(mounted){
        _showError("Authentication token not found. Please login again.");
      }
      setState(() => _isLoading = false);
      widget.onLogout();
      return;
    }

    var request = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/profile'));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    
    request.fields['name'] = _ownerNameController.text;
    request.fields['umkm_name'] = _umkmNameController.text;
    request.fields['contact'] = _umkmContactController.text;
    request.fields['umkm_description'] = _umkmDescriptionController.text;
    request.fields['is_investable'] = _currentIsInvestable.toString();

    if (_profileImageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('umkm_profile_image', _profileImageFile!.path));
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (mounted) {
        setState(() => _isLoading = false);

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          final updatedUser = responseData['user'];
          
          _currentOwnerName = updatedUser['name'] ?? _ownerNameController.text;
          _currentUmkmName = updatedUser['umkm_name'] ?? _umkmNameController.text;
          _currentUmkmContact = updatedUser['contact'] ?? _umkmContactController.text;
          _currentIsInvestable = updatedUser['is_investable'] as bool? ?? _currentIsInvestable;
          _currentUmkmDescription = updatedUser['umkm_description'] ?? _umkmDescriptionController.text;
          _currentUmkmProfileImageUrl = updatedUser['umkm_profile_image_url'];

          widget.onProfileUpdated(
            _currentUmkmName,
            _currentUmkmContact,
            _currentOwnerName,
            _currentIsInvestable,
            _currentUmkmDescription,
            _currentUmkmProfileImageUrl
          );
          
          setState(() { _isEditing = false; _profileImageFile = null; });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
          );
        } else {
          final errorData = jsonDecode(response.body);
          _showError(errorData['message'] ?? 'Failed to update profile. Status: ${response.statusCode} ${response.body}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error updating profile: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit UMKM Profile' : 'UMKM Profile'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: 'Cancel Edit',
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _profileImageFile = null;
                  _ownerNameController.text = widget.username;
                  _umkmNameController.text = widget.umkmName;
                  _umkmContactController.text = widget.umkmContact;
                  _umkmDescriptionController.text = widget.umkmDescription ?? '';
                  _currentIsInvestable = widget.isInvestable; 
                });
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_isEditing) return; 
          await widget.onRefresh();
          _updateLocalStateFromWidget();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileHeader(theme),
              const SizedBox(height: 24),
              _isEditing ? _buildEditingForm(theme) : _buildDisplayInfo(theme),
              const SizedBox(height: 32),
              if (_isEditing)
                ElevatedButton.icon(
                  icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.save_alt_outlined),
                  label: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Save Changes'),
                  onPressed: _isLoading ? null : _updateProfileData,
                  style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout_outlined),
                  label: const Text('Logout'),
                  onPressed: widget.onLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withAlpha(26),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme) {
    Widget profilePicture;
    if (_profileImageFile != null) {
      profilePicture = CircleAvatar(radius: 50, backgroundImage: FileImage(_profileImageFile!));
    } else if (_currentUmkmProfileImageUrl != null && _currentUmkmProfileImageUrl!.isNotEmpty) {
      profilePicture = CircleAvatar(radius: 50, backgroundImage: NetworkImage(_currentUmkmProfileImageUrl!));
    } else {
      profilePicture = CircleAvatar(
        radius: 50,
        backgroundColor: theme.colorScheme.primary.withAlpha(204),
        child: Text(
          _currentOwnerName.isNotEmpty ? _currentOwnerName[0].toUpperCase() : "U",
          style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.primary.withAlpha(13),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(children: [
          profilePicture,
          if (_isEditing)
            TextButton.icon(
              icon: Icon(Icons.camera_alt_outlined, size: 18, color: theme.colorScheme.primary),
              label: Text('Change Image', style: TextStyle(color: theme.colorScheme.primary)),
              onPressed: _pickImage,
            ),
          const SizedBox(height: 16),
          Text(_currentOwnerName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(_currentEmail, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildDisplayInfo(ThemeData theme) {
    return Column(
      children: [
        _buildInfoCard(
          title: "UMKM Details",
          icon: Icons.storefront_outlined,
          theme: theme,
          actions: !_isEditing
              ? [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit Profile',
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                        _ownerNameController.text = _currentOwnerName;
                        _umkmNameController.text = _currentUmkmName;
                        _umkmContactController.text = _currentUmkmContact;
                        _umkmDescriptionController.text = _currentUmkmDescription ?? '';
                        _profileImageFile = null;
                      });
                    },
                  )
                ]
              : [],
          children: [
            _buildDisplayRow(label: "UMKM Name:", value: _currentUmkmName.isNotEmpty ? _currentUmkmName : "Not set"),
            _buildDisplayRow(label: "Contact:", value: _currentUmkmContact.isNotEmpty ? _currentUmkmContact : "Not set", isPhone: true),
            _buildDisplayRow(label: "Description:", value: _currentUmkmDescription?.isNotEmpty == true ? _currentUmkmDescription! : "Not set"),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Open for Investment:", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500, fontSize: 15)),
                  Switch(
                    value: _currentIsInvestable,
                    onChanged: null, // Made non-interactive in display mode
                    activeColor: theme.colorScheme.primary,
                    inactiveThumbColor: Colors.grey.shade400,
                    inactiveTrackColor: Colors.grey.shade200,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditingForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Edit Owner Information", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ownerNameController,
            decoration: const InputDecoration(labelText: "Owner Full Name", prefixIcon: Icon(Icons.person_outline)),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Owner name cannot be empty";
              }
              return null;
            }
          ),
          const SizedBox(height: 24),
          Text("Edit UMKM Business Information", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _umkmNameController,
            decoration: const InputDecoration(labelText: "UMKM Business Name", prefixIcon: Icon(Icons.storefront_outlined)),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _umkmContactController,
            decoration: const InputDecoration(labelText: "Contact (Phone/WA)", prefixIcon: Icon(Icons.contact_phone_outlined)),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _umkmDescriptionController,
            decoration: const InputDecoration(labelText: "UMKM Description", prefixIcon: Icon(Icons.description_outlined), alignLabelWithHint: true),
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: 24),
           SwitchListTile(
            title: const Text("Open for Investment"),
            subtitle: Text(_currentIsInvestable ? "Visible to Investors" : "Hidden from Investors"),
            value: _currentIsInvestable,
            onChanged: (bool value) {
              setState(() {
                _currentIsInvestable = value;
              });
            },
            activeColor: theme.colorScheme.primary,
            secondary: Icon(Icons.monetization_on_outlined, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required ThemeData theme,
    List<Widget> actions = const [],
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                ...actions,
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayRow({required String label, required String value, bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label ", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500, fontSize: 15)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isPhone ? Theme.of(context).colorScheme.secondary : Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }
}
