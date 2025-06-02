import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api.dart';
import 'umkm_detail_screen.dart'; 

class UmkmInfo {
  final int id;
  final String ownerName;
  final String email;
  final String umkmName;
  final String contact; 
  final bool isInvestable;
  final String? umkmDescription;
  final String? umkmProfileImageUrl;


  UmkmInfo({
    required this.id,
    required this.ownerName,
    required this.email,
    required this.umkmName,
    required this.contact,
    required this.isInvestable,
    this.umkmDescription,
    this.umkmProfileImageUrl,
  });

  factory UmkmInfo.fromJson(Map<String, dynamic> json) {
    return UmkmInfo(
      id: json['id'] as int? ?? 0,
      ownerName: json['name']?.toString() ?? 'N/A',
      email: json['email']?.toString() ?? 'N/A',
      umkmName: json['umkm_name']?.toString() ?? 'Unnamed UMKM',
      contact: json['contact']?.toString() ?? 'No Contact',
      isInvestable: json['is_investable'] as bool? ?? false,
      umkmDescription: json['umkm_description'] as String?,
      umkmProfileImageUrl: json['umkm_profile_image_url'] as String?,
    );
  }
}

class UmkmListScreen extends StatefulWidget {
  const UmkmListScreen({super.key});

  @override
  State<UmkmListScreen> createState() => _UmkmListScreenState();
}

class _UmkmListScreenState extends State<UmkmListScreen> {
  List<UmkmInfo> _umkmList = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUmkmList();
  }

  Future<void> _fetchUmkmList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userType = prefs.getString('user_type');

    if (token == null || userType != 'investor') {
      setState(() {
        _isLoading = false;
        _errorMessage = "Unauthorized or invalid session.";
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/investor/umkms'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 20));

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          setState(() {
            _umkmList = data.map((json) => UmkmInfo.fromJson(json)).toList();
            _isLoading = false;
          });
        } else {
          final errorData = jsonDecode(response.body);
          setState(() {
            _isLoading = false;
            _errorMessage = errorData['message'] ?? "Failed to load UMKM list. Status: ${response.statusCode}";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error fetching UMKMs: ${e.toString()}";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover UMKMs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchUmkmList,
            tooltip: 'Refresh List',
          )
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: theme.colorScheme.secondary));
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.redAccent)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Retry"),
              onPressed: _fetchUmkmList,
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary, foregroundColor: Colors.white),
            )
          ]),
        ),
      );
    }
    if (_umkmList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.storefront_outlined, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No UMKMs available for investment yet.', style: TextStyle(fontSize: 17, color: Colors.grey[600])),
            Text('UMKMs can enable this option in their profile.', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Refresh"),
              onPressed: _fetchUmkmList,
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary.withAlpha(26), foregroundColor: theme.colorScheme.secondary),
            )
          ]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchUmkmList,
      color: theme.colorScheme.secondary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: _umkmList.length,
        itemBuilder: (context, index) {
          final umkm = _umkmList[index];
          Widget leadingWidget;
          if (umkm.umkmProfileImageUrl != null && umkm.umkmProfileImageUrl!.isNotEmpty) {
            leadingWidget = CircleAvatar(
              backgroundImage: NetworkImage(umkm.umkmProfileImageUrl!),
              backgroundColor: theme.colorScheme.secondary.withAlpha(38),
            );
          } else {
            leadingWidget = CircleAvatar(
              backgroundColor: theme.colorScheme.secondary.withAlpha(38),
              child: Text(
                umkm.umkmName.isNotEmpty ? umkm.umkmName[0].toUpperCase() : "U",
                style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
              ),
            );
          }

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: leadingWidget,
              title: Text(umkm.umkmName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Owner: ${umkm.ownerName}", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  Text("Contact: ${umkm.contact}", style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UmkmDetailScreen(umkmId: umkm.id, umkmName: umkm.umkmName),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
