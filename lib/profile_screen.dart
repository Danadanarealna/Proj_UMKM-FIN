import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api.dart';
// import 'app_state.dart'; // Not directly used here, but good for consistency if AppState manages user data

class ProfileScreen extends StatefulWidget {
  final String username;
  final String email;
  final String umkmName;
  final String umkmContact;
  final bool isInvestable;
  final VoidCallback onLogout;
  final Function(String newUmkmName, String newUmkmContact, String newOwnerName, bool newIsInvestable) onProfileUpdated;
  final Future<void> Function() onRefresh;

  const ProfileScreen({
    required this.username,
    required this.email,
    required this.umkmName,
    required this.umkmContact,
    required this.isInvestable,
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
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isSavingInvestableToggle = false;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ownerNameController;
  late TextEditingController _umkmNameController;
  late TextEditingController _umkmContactController;

  @override
  void initState() {
    super.initState();
    _updateLocalStateFromWidget();
    _ownerNameController = TextEditingController(text: _currentOwnerName);
    _umkmNameController = TextEditingController(text: _currentUmkmName);
    _umkmContactController = TextEditingController(text: _currentUmkmContact);
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.username != oldWidget.username ||
        widget.email != oldWidget.email ||
        widget.umkmName != oldWidget.umkmName ||
        widget.umkmContact != oldWidget.umkmContact ||
        widget.isInvestable != oldWidget.isInvestable) {
      _updateLocalStateFromWidget();
      _ownerNameController.text = _currentOwnerName;
      _umkmNameController.text = _currentUmkmName;
      _umkmContactController.text = _currentUmkmContact;
    }
  }

  void _updateLocalStateFromWidget() {
    _currentOwnerName = widget.username;
    _currentEmail = widget.email;
    _currentUmkmName = widget.umkmName;
    _currentUmkmContact = widget.umkmContact;
    _currentIsInvestable = widget.isInvestable;
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _umkmNameController.dispose();
    _umkmContactController.dispose();
    super.dispose();
  }

  Future<void> _updateProfileData({bool? newIsInvestable}) async {
    // If only toggling investable status, no need to validate the form
    if (_isEditing && !_formKey.currentState!.validate()) {
      return;
    }
    
    if (newIsInvestable != null) { // If called from Switch toggle
        setState(() => _isSavingInvestableToggle = true);
    } else { // If called from Save Changes button
        setState(() => _isLoading = true);
    }


    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      _showError("Authentication token not found. Please login again.");
      if (newIsInvestable != null) setState(() => _isSavingInvestableToggle = false);
      else setState(() => _isLoading = false);
      widget.onLogout();
      return;
    }

    Map<String, dynamic> body = {
      'name': _ownerNameController.text,
      'umkm_name': _umkmNameController.text,
      'contact': _umkmContactController.text, // Use 'contact' key
      'is_investable': newIsInvestable ?? _currentIsInvestable, // Use toggled value or current form value
    };

    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (mounted) {
        if (newIsInvestable != null) setState(() => _isSavingInvestableToggle = false);
        else setState(() => _isLoading = false);

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          final updatedUser = responseData['user'];
          
          // Update local state and call parent callback
          _currentOwnerName = updatedUser['name'] ?? _ownerNameController.text;
          _currentUmkmName = updatedUser['umkm_name'] ?? _umkmNameController.text;
          _currentUmkmContact = updatedUser['contact'] ?? _umkmContactController.text;
          _currentIsInvestable = updatedUser['is_investable'] as bool? ?? (newIsInvestable ?? _currentIsInvestable);


          widget.onProfileUpdated(
            _currentUmkmName,
            _currentUmkmContact,
            _currentOwnerName,
            _currentIsInvestable,
          );
          
          if (! (newIsInvestable != null)) { // Only exit editing mode if it was a full save
            setState(() { _isEditing = false; });
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
          );
        } else {
          final errorData = jsonDecode(response.body);
          _showError(errorData['message'] ?? 'Failed to update profile. Status: ${response.statusCode}');
          // Revert UI toggle if only investable status update failed
          if (newIsInvestable != null) {
            setState(() { _currentIsInvestable = !newIsInvestable; });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        if (newIsInvestable != null) {
            setState(() {
                _isSavingInvestableToggle = false;
                _currentIsInvestable = !newIsInvestable; // Revert on error
            });
        } else {
             setState(() => _isLoading = false);
        }
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
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Profile',
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _ownerNameController.text = _currentOwnerName;
                  _umkmNameController.text = _currentUmkmName;
                  _umkmContactController.text = _currentUmkmContact;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: 'Cancel Edit',
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _ownerNameController.text = widget.username;
                  _umkmNameController.text = widget.umkmName;
                  _umkmContactController.text = widget.umkmContact;
                  // _currentIsInvestable is not reset here to reflect its actual state from widget.isInvestable
                  _currentIsInvestable = widget.isInvestable; 
                });
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
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
                  onPressed: _isLoading ? null : () => _updateProfileData(),
                  style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout_outlined),
                  label: const Text('Logout'),
                  onPressed: widget.onLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
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
    return Card(
      elevation: 0,
      color: theme.colorScheme.primary.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.8),
            child: Text(
              _currentOwnerName.isNotEmpty ? _currentOwnerName[0].toUpperCase() : "U",
              style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
            ),
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
          children: [
            _buildDisplayRow(label: "UMKM Name:", value: _currentUmkmName.isNotEmpty ? _currentUmkmName : "Not set"),
            _buildDisplayRow(label: "Contact:", value: _currentUmkmContact.isNotEmpty ? _currentUmkmContact : "Not set", isPhone: true),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Open for Investment:", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500, fontSize: 15)),
                  _isSavingInvestableToggle 
                    ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.colorScheme.primary))
                    : Switch(
                        value: _currentIsInvestable,
                        onChanged: (bool value) {
                          setState(() { _currentIsInvestable = value; });
                          _updateProfileData(newIsInvestable: value);
                        },
                        activeColor: theme.colorScheme.primary,
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
            validator: (value) => value == null || value.isEmpty ? "Owner name cannot be empty" : null,
          ),
          const SizedBox(height: 24),
          Text("Edit UMKM Business Information", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _umkmNameController,
            decoration: const InputDecoration(labelText: "UMKM Business Name", prefixIcon: Icon(Icons.storefront_outlined)),
            // validator: (value) => value == null || value.isEmpty ? "UMKM name cannot be empty" : null, // Optional based on your rules
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _umkmContactController,
            decoration: const InputDecoration(labelText: "Contact (Phone/WA)", prefixIcon: Icon(Icons.contact_phone_outlined)),
            keyboardType: TextInputType.phone,
            // validator: (value) => value == null || value.isEmpty ? "UMKM contact cannot be empty" : null, // Optional
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

  Widget _buildInfoCard({required String title, required IconData icon, required List<Widget> children, required ThemeData theme}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 10),
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ]),
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
