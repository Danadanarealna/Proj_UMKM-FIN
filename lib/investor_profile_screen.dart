import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api.dart'; // Assuming api.dart defines apiBaseUrl
import 'package:intl/intl.dart';
import 'app_state.dart'; // Assuming app_state.dart defines AppState and AuthWrapper
import 'auth.dart'; // Assuming auth.dart might be needed by AuthWrapper or other parts
import 'package:url_launcher/url_launcher.dart'; // Import for launching URLs

class InvestmentInfo {
  final String id;
  final String umkmName;
  final double amount;
  final String status;
  final DateTime investmentDate;

  InvestmentInfo({
    required this.id,
    required this.umkmName,
    required this.amount,
    required this.status,
    required this.investmentDate,
  });

  factory InvestmentInfo.fromJson(Map<String, dynamic> json) {
    final umkmData = json['umkm'] as Map<String, dynamic>?;
    DateTime parsedDate;
    try {
        if (json['investment_date'] != null) {
            parsedDate = DateTime.parse(json['investment_date']);
        } else if (json['created_at'] != null) {
            parsedDate = DateTime.parse(json['created_at']);
        } else {
            // Fallback if no date is provided, though ideally dates should always be present
            print("Warning: Investment date missing for ID ${json['id']}, defaulting to now.");
            parsedDate = DateTime.now();
        }
    } catch(e) {
        // Fallback in case of parsing error
        print("Error parsing investment date: ${json['investment_date'] ?? json['created_at']}. Error: $e. Defaulting to now for ID ${json['id']}");
        parsedDate = DateTime.now();
    }

    // Robust amount parsing
    double parsedAmount = 0.0;
    if (json['amount'] != null) {
      if (json['amount'] is num) {
        parsedAmount = (json['amount'] as num).toDouble();
      } else if (json['amount'] is String) {
        parsedAmount = double.tryParse(json['amount'] as String) ?? 0.0;
        if (parsedAmount == 0.0 && (json['amount'] as String).isNotEmpty) {
            print("Warning: Could not parse amount string '${json['amount']}' for investment ID ${json['id']}. Defaulted to 0.0.");
        }
      } else {
        print("Warning: Amount for investment ID ${json['id']} is not num or String, defaulting to 0.0. Type: ${json['amount'].runtimeType}");
      }
    } else {
        print("Warning: Amount is null for investment ID ${json['id']}, defaulting to 0.0.");
    }


    return InvestmentInfo(
      id: json['id']?.toString() ?? '',
      umkmName: umkmData?['umkm_name']?.toString() ?? umkmData?['name']?.toString() ?? 'N/A',
      amount: parsedAmount,
      status: json['status']?.toString() ?? 'pending',
      investmentDate: parsedDate,
    );
  }
}

class AppointmentInfo {
  final String id;
  final String umkmName;
  final String umkmOwnerName;
  final String umkmContact;
  final String status;
  final String details;
  final DateTime? appointmentTime;
  final String contactMethod;
  final String contactPayload;
  final DateTime createdAt;

  AppointmentInfo({
    required this.id,
    required this.umkmName,
    required this.umkmOwnerName,
    required this.umkmContact,
    required this.status,
    required this.details,
    this.appointmentTime,
    required this.contactMethod,
    required this.contactPayload,
    required this.createdAt,
  });

  factory AppointmentInfo.fromJson(Map<String, dynamic> json) {
    final umkmData = json['umkm'] as Map<String, dynamic>?;
    DateTime? parsedAppTime;
    if (json['appointment_time'] != null) {
        try {
            parsedAppTime = DateTime.parse(json['appointment_time']);
        } catch(e) {
            print("Error parsing appointment time: ${json['appointment_time']}. Error: $e. Defaulting to null for ID ${json['id']}");
            parsedAppTime = null; // Explicitly null if parsing fails
        }
    }
    DateTime parsedCreatedAt;
     try {
        parsedCreatedAt = DateTime.parse(json['created_at']);
    } catch(e) {
        print("Error parsing appointment created_at: ${json['created_at']}. Error: $e. Defaulting to now for ID ${json['id']}");
        parsedCreatedAt = DateTime.now(); // Fallback
    }

    return AppointmentInfo(
      id: json['id']?.toString() ?? '',
      umkmName: umkmData?['umkm_name']?.toString() ?? 'N/A',
      umkmOwnerName: umkmData?['name']?.toString() ?? 'N/A', // Assuming 'name' is owner name in umkmData
      umkmContact: umkmData?['contact']?.toString() ?? 'N/A',
      status: json['status']?.toString() ?? 'N/A',
      details: json['appointment_details']?.toString() ?? 'No details',
      appointmentTime: parsedAppTime,
      contactMethod: json['contact_method']?.toString() ?? 'whatsapp',
      contactPayload: json['contact_payload']?.toString() ?? '',
      createdAt: parsedCreatedAt,
    );
  }
}


class InvestorProfileScreen extends StatefulWidget {
  final String investorName;
  final String investorEmail;
  final VoidCallback onLogout;
  final Future<void> Function() onRefresh; // Callback to refresh parent/global data

  const InvestorProfileScreen({
    super.key,
    required this.investorName,
    required this.investorEmail,
    required this.onLogout,
    required this.onRefresh,
  });

  @override
  State<InvestorProfileScreen> createState() => _InvestorProfileScreenState();
}

class _InvestorProfileScreenState extends State<InvestorProfileScreen> {
  List<InvestmentInfo> _myInvestments = [];
  List<AppointmentInfo> _myAppointments = [];
  bool _isLoadingInvestments = true;
  bool _isLoadingAppointments = true;
  String? _fetchError; // General error for the whole screen or specific sections
  bool _isUpdating = false; // To disable buttons during an update operation


  @override
  void initState() {
    super.initState();
    _fetchAllProfileData(isInitialLoad: true);
  }

  Future<void> _fetchAllProfileData({bool isInitialLoad = false}) async {
    if (!mounted) return;
    setState(() {
      if (isInitialLoad) {
        _isLoadingInvestments = true;
        _isLoadingAppointments = true;
      }
      _fetchError = null; 
      if(!isInitialLoad) {
        _myInvestments = [];
        _myAppointments = [];
      }
    });

    await Future.wait([
      _fetchMyInvestments(isInitialLoad: isInitialLoad),
      _fetchMyAppointments(isInitialLoad: isInitialLoad),
    ]);
  }

  Future<void> _fetchMyInvestments({bool isInitialLoad = false}) async {
    if (!mounted) return;
    if(!isInitialLoad) setState(() => _isLoadingInvestments = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (mounted) {
        setState(() => _isLoadingInvestments = false);
        _showAuthError(); 
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/investor/investments'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15)); 

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          setState(() {
            _myInvestments = data.map((item) => InvestmentInfo.fromJson(item)).toList();
            if (_fetchError != null && _myInvestments.isNotEmpty) _fetchError = null;
          });
        } else {
          final errorData = jsonDecode(response.body);
          _showError('Failed to load investments: ${errorData['message'] ?? response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Error fetching investments: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoadingInvestments = false);
    }
  }

  Future<void> _fetchMyAppointments({bool isInitialLoad = false}) async {
     if (!mounted) return;
    if(!isInitialLoad) setState(() => _isLoadingAppointments = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
     if (token == null) {
      if (mounted) setState(() => _isLoadingAppointments = false);
      _showAuthError();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/investor/appointments'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15)); 

      if (mounted) {
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          setState(() {
            _myAppointments = data.map((item) => AppointmentInfo.fromJson(item)).toList();
            if (_fetchError != null && _myAppointments.isNotEmpty) _fetchError = null;
          });
        } else {
           final errorData = jsonDecode(response.body);
           _showError('Failed to load appointments: ${errorData['message'] ?? response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted){
        _showError('Error fetching appointments: ${e.toString()}');
      }
    } finally {
        if (mounted) setState(() => _isLoadingAppointments = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
    if (_myInvestments.isEmpty && _myAppointments.isEmpty) {
       setState(() { _fetchError = message; });
    }
  }

  void _showAuthError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Authentication error. Please log in again.')),
    );
    AppState().clearUserSession().then((_) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()), 
          (Route<dynamic> route) => false,
        );
      }
    });
  }

  Future<void> _confirmInvestment(InvestmentInfo investment) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      _showAuthError();
      setState(() => _isUpdating = false);
      return;
    }

    // Backend should ideally change status from 'pending' to 'active' or 'confirmed_by_investor'
    // For now, we assume newStatus will be 'active' or similar.
    // The backend endpoint would be something like: PUT /investor/investments/{id}/confirm
    // Or a general status update endpoint: PUT /investor/investments/{id}/status with body {'status': 'active'}

    try {
      // IMPORTANT: Replace with your actual API endpoint and method for confirming investment
      final response = await http.put(
        Uri.parse('$apiBaseUrl/investor/investments/${investment.id}/confirm'), // Example endpoint
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        // body: jsonEncode({'status': 'active'}), // If using a general status update endpoint
      );

      if (mounted) {
        if (response.statusCode == 200) {
          _showSnackbar('Investment confirmed successfully.', isError: false);
          _fetchMyInvestments(isInitialLoad: false); // Refresh investments
        } else {
          final errorData = jsonDecode(response.body);
          _showError(errorData['message'] ?? 'Failed to confirm investment.');
        }
      }
    } catch (e) {
      if (mounted) _showError('Error confirming investment: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }


  Future<void> _updateAppointmentStatus(AppointmentInfo appointment, String newStatus) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      _showAuthError(); 
      setState(() => _isUpdating = false);
      return;
    }
    Map<String, dynamic> body = {'status': newStatus};
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/investor/appointments/${appointment.id}/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json', 
          'Accept': 'application/json'
        },
        body: jsonEncode(body), 
      );
      if (mounted) {
        if (response.statusCode == 200) {
          _showSnackbar('Appointment status updated to $newStatus.', isError: false);
          _fetchMyAppointments(isInitialLoad: false); 
        } else {
          final errorData = jsonDecode(response.body);
          _showError(errorData['message'] ?? 'Failed to update appointment status.');
        }
      }
    } catch (e) {
      if (mounted) _showError('Error updating appointment: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
            IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _isUpdating ? null : () async { // Disable refresh if updating
                    await widget.onRefresh(); 
                    await _fetchAllProfileData(isInitialLoad: false); 
                },
                tooltip: 'Refresh My Data',
            )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _isUpdating ? () async {} : () => _fetchAllProfileData(isInitialLoad: false),
        color: theme.colorScheme.secondary, 
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            _buildProfileHeader(theme),
            const SizedBox(height: 24),
            _buildSectionTitle("My Investments (${_myInvestments.length})", theme),
            _isLoadingInvestments
                ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                : _myInvestments.isEmpty && _fetchError == null 
                    ? _buildEmptyState("You haven't made any investments yet.", theme, () => _fetchMyInvestments(isInitialLoad: false))
                    : _fetchError != null && _myInvestments.isEmpty 
                        ? _buildErrorState(_fetchError!, theme, () => _fetchMyInvestments(isInitialLoad: false))
                        : _buildInvestmentList(theme), 
            const SizedBox(height: 24),

            _buildSectionTitle("My Appointments (${_myAppointments.length})", theme),
             _isLoadingAppointments
                ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
                : _myAppointments.isEmpty && _fetchError == null
                    ? _buildEmptyState("You don't have any appointments scheduled.", theme, () => _fetchMyAppointments(isInitialLoad: false))
                    : _fetchError != null && _myAppointments.isEmpty
                        ? _buildErrorState(_fetchError!, theme, () => _fetchMyAppointments(isInitialLoad: false))
                        : _buildAppointmentList(theme),

            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout_outlined),
              label: const Text('Logout'),
              onPressed: _isUpdating ? null : widget.onLogout, // Disable if updating
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withAlpha((0.1 * 255).round()), 
                foregroundColor: Colors.redAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 20), 
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme) {
     return Card(
      elevation: 0, 
      color: theme.colorScheme.secondary.withAlpha((0.05 * 255).round()), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: theme.colorScheme.secondary.withAlpha((0.8 * 255).round()), 
              child: Text(
                widget.investorName.isNotEmpty ? widget.investorName[0].toUpperCase() : "I",
                style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.investorName,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.investorEmail,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0), 
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.secondary),
      ),
    );
  }

  Widget _buildEmptyState(String message, ThemeData theme, Future<void> Function() onRetry) {
    return Card(
      elevation: 0,
      color: Colors.grey[100], 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded, size: 40, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
              const SizedBox(height: 12),
              TextButton.icon( 
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Refresh"),
                  onPressed: _isUpdating ? null : onRetry, // Disable if updating
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.secondary),
              )
            ],
          ),
        ),
      ),
    );
  }

   Widget _buildErrorState(String message, ThemeData theme, Future<void> Function() onRetry) {
    return Card(
      elevation: 0,
      color: Colors.red[50], 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 40, color: Colors.red[700]),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.red[700])),
              const SizedBox(height: 12),
              TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Retry"),
                  onPressed: _isUpdating ? null : onRetry, // Disable if updating
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error), 
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvestmentList(ThemeData theme) {
    return ListView.builder(
      shrinkWrap: true, 
      physics: const NeverScrollableScrollPhysics(), 
      itemCount: _myInvestments.length,
      itemBuilder: (context, index) {
        final investment = _myInvestments[index];
        List<Widget> actionButtons = [];

        if (investment.status.toLowerCase() == 'pending') {
          actionButtons.add(
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton.icon(
                icon: Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Confirm'),
                onPressed: _isUpdating ? null : () => _confirmInvestment(investment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: TextStyle(fontSize: 13)
                ),
              ),
            )
          );
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.attach_money_rounded, color: theme.colorScheme.primary, size: 28),
                  title: Text('Invested in: ${investment.umkmName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Amount: \$${investment.amount.toStringAsFixed(2)}\nStatus: ${investment.status.toUpperCase()}',
                    style: TextStyle(color: Colors.grey[700])
                  ),
                  trailing: Text(
                      DateFormat('dd MMM yy').format(investment.investmentDate), 
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  isThreeLine: true,
                ),
                if (actionButtons.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Wrap(spacing: 8.0, children: actionButtons),
                  ),
              ],
            ),
          )
        );
      },
    );
  }

  Widget _buildAppointmentList(ThemeData theme) {
     return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _myAppointments.length,
      itemBuilder: (context, index) {
        final appointment = _myAppointments[index];
        String appointmentTimeDisplay = "Not set yet";
        if (appointment.appointmentTime != null) {
            appointmentTimeDisplay = DateFormat('dd MMM yy, hh:mm a').format(appointment.appointmentTime!);
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding( 
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: ListTile(
              leading: Icon(
                _getAppointmentStatusIcon(appointment.status),
                color: _getAppointmentStatusColor(appointment.status, theme),
                size: 30, 
              ),
              title: Text('With: ${appointment.umkmName}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('UMKM Owner: ${appointment.umkmOwnerName}'),
                  Text('Contact: ${appointment.umkmContact}'),
                  Text('Status: ${appointment.status.toUpperCase()}', style: TextStyle(fontWeight: FontWeight.bold, color: _getAppointmentStatusColor(appointment.status, theme))),
                  if (appointment.appointmentTime != null) 
                    Text('Scheduled: $appointmentTimeDisplay'),
                  Text('Details: ${appointment.details}', maxLines: 2, overflow: TextOverflow.ellipsis), 
                  Text('Requested: ${DateFormat('dd MMM yy').format(appointment.createdAt)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
              isThreeLine: true, 
              trailing: _buildAppointmentActions(appointment, theme),
            ),
          ),
        );
      },
    );
  }

  Widget? _buildAppointmentActions(AppointmentInfo appointment, ThemeData theme) {
    List<Widget> actions = [];

    // Investor can cancel if 'requested' or 'rescheduled_by_umkm'
    if (appointment.status.toLowerCase() == 'requested' || appointment.status.toLowerCase() == 'rescheduled_by_umkm') {
      actions.add(
        TextButton(
          child: Text('Cancel', style: TextStyle(color: Colors.red.shade600)),
          onPressed: _isUpdating ? null : () => _updateAppointmentStatus(appointment, 'cancelled'),
        ),
      );
    }

    // Investor can confirm if 'rescheduled_by_umkm'
    if (appointment.status.toLowerCase() == 'rescheduled_by_umkm') {
       actions.add(
        TextButton(
          child: Text('Confirm', style: TextStyle(color: Colors.green.shade700)),
          onPressed: _isUpdating ? null : () => _updateAppointmentStatus(appointment, 'confirmed'),
        ),
      );
    }
    
    if (appointment.contactMethod == 'whatsapp' &&
               (appointment.status.toLowerCase() == 'confirmed' || appointment.status.toLowerCase() == 'requested') && 
               appointment.umkmContact.isNotEmpty) {
      actions.add(
        IconButton(
          icon: Icon(Icons.message_outlined, color: Colors.green.shade600),
          tooltip: 'Open WhatsApp Chat',
          onPressed: _isUpdating ? null : () async {
              String umkmPhone = appointment.umkmContact.replaceAll(RegExp(r'[^0-9+]'), ''); 
              if (umkmPhone.startsWith('0')) {
                  umkmPhone = '62${umkmPhone.substring(1)}'; 
              } else if (!umkmPhone.startsWith('+') && !umkmPhone.startsWith('62')) {
                  umkmPhone = '62$umkmPhone'; 
              }
              if (umkmPhone.startsWith('+') && umkmPhone.length > 1 && umkmPhone.substring(1).contains('+')) {
                  umkmPhone = umkmPhone.substring(0,1) + umkmPhone.substring(1).replaceAll('+', '');
              } else if (!umkmPhone.startsWith('+')) {
                  umkmPhone = umkmPhone.replaceAll('+', '');
              }

              final Uri whatsappUri = Uri.parse("https://wa.me/$umkmPhone?text=${Uri.encodeComponent(appointment.contactPayload)}");
              try {
                  if (await canLaunchUrl(whatsappUri)) { 
                    await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
                  } else {
                     _showError("Could not open WhatsApp. Ensure it's installed or the link is correct.");
                  }
              } catch (e) {
                  _showError("Could not open WhatsApp: $e");
              }
          },
        ),
      );
    }
    return actions.isEmpty ? null : Wrap(spacing: 4.0, runSpacing: 0, alignment: WrapAlignment.end, children: actions);
  }

  IconData _getAppointmentStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed': return Icons.event_available_rounded;
      case 'completed': return Icons.check_circle_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      case 'requested': return Icons.hourglass_top_rounded;
      case 'rescheduled_by_umkm':
      case 'rescheduled_by_investor': 
        return Icons.edit_calendar_rounded;
      default: return Icons.calendar_today_rounded; 
    }
  }

  Color _getAppointmentStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'confirmed': return Colors.green.shade700;
      case 'completed': return theme.colorScheme.primary; 
      case 'cancelled': return Colors.red.shade700;
      case 'requested': return theme.colorScheme.secondary; 
      case 'rescheduled_by_umkm':
      case 'rescheduled_by_investor':
        return Colors.orange.shade800; 
      default: return Colors.grey.shade700; 
    }
  }
}
