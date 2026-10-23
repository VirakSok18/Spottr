import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/config.dart' as app_config;
import '../../widgets/app_theme_widgets.dart';
import 'premium_upgrade_screen.dart';


class ManagePlanScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ManagePlanScreen({Key? key, required this.userData}) : super(key: key);

  @override
  State<ManagePlanScreen> createState() => _ManagePlanScreenState();
}

class _ManagePlanScreenState extends State<ManagePlanScreen> {
  bool _isLoading = false;
  bool _isFetchingDetails = true;
  Map<String, dynamic>? _subscriptionDetails;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionDetails();
  }

  Future<void> _fetchSubscriptionDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final baseUrl = app_config.Config.baseUrl;

      final response = await http.get(
        Uri.parse('$baseUrl/api/payments/subscription-details'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _subscriptionDetails = json.decode(response.body);
          _isFetchingDetails = false;
        });
      } else {
        setState(() => _isFetchingDetails = false);
      }
    } catch (e) {
      print('Fetch Subscription Error: $e');
      setState(() => _isFetchingDetails = false);
    }
  }

  Future<void> _openBillingPortal() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final baseUrl = app_config.Config.baseUrl;

      final response = await http.get(
        Uri.parse('$baseUrl/api/payments/billing-portal'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final url = Uri.parse(data['url']);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      } else {
        final error = json.decode(response.body)['error'] ?? 'Failed to open portal';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error connecting to billing service')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPlanType = widget.userData['planType']?.toString().toUpperCase() ?? 'PREMIUM';
    final planName = _subscriptionDetails?['planName'] ?? defaultPlanType;
    final status = _subscriptionDetails?['status']?.toString().toUpperCase() ?? 'ACTIVE';
    final isCanceling = _subscriptionDetails?['isCanceling'] == true;
    
    String statusText = status;
    Color statusColor = const Color(0xFFFFD700);
    if (isCanceling) {
      statusText = 'CANCELS SOON';
      statusColor = Colors.orange;
    } else if (status != 'ACTIVE') {
      statusColor = Colors.grey;
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Manage Plan', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Plan Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E2E2E), Color(0xFF252525)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CURRENT PLAN',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Row(
                        children: [
                          if (_subscriptionDetails?['renewalDate'] != null)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_getDaysLeft(_subscriptionDetails?['renewalDate'])} left',
                                style: GoogleFonts.poppins(
                                  color: Colors.blueAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusText,
                              style: GoogleFonts.poppins(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (_isFetchingDetails)
                     const Padding(
                       padding: EdgeInsets.symmetric(vertical: 8.0),
                       child: SizedBox(
                         height: 20, width: 20, 
                         child: CircularProgressIndicator(color: Color(0xFFFFD700), strokeWidth: 2)
                       ),
                     )
                  else ...[
                    Text(
                      planName,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_subscriptionDetails?['renewalDate'] != null)
                      Text(
                        isCanceling 
                            ? 'Ends on ${_formatDate(_subscriptionDetails?['renewalDate'])}'
                            : 'Renews on ${_formatDate(_subscriptionDetails?['renewalDate'])}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    if (_subscriptionDetails?['cardLast4'] != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.credit_card, size: 16, color: Colors.grey[400]),
                          const SizedBox(width: 8),
                          Text(
                            '•••• ${_subscriptionDetails!['cardLast4']} (${_subscriptionDetails!['cardBrand']?.toString().toUpperCase()})',
                            style: const TextStyle(fontFamily: 'monospace', color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ]
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'SUBSCRIPTION OPTIONS',
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),

            // Billing Portal Button
            _buildOptionTile(
              icon: Icons.open_in_browser,
              title: 'Manage Billing & Subscription',
              subtitle: 'Update card, change plan, or cancel',
              onTap: _openBillingPortal,
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2E2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFB497FF)),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: _isLoading ? null : onTap,
      ),
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'N/A';
    try {
      final date = DateTime.parse(isoString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _getDaysLeft(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString);
      final diff = date.difference(DateTime.now()).inDays;
      if (diff < 0) return '0 days';
      return '$diff days';
    } catch (e) {
      return '';
    }
  }
}
