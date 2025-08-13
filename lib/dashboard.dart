import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  final String roll;

  const DashboardPage({Key? key, required this.roll}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic>? _userData;
  bool _requestingAdmin = false;
  bool _updatingName = false;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  final TextEditingController _nameController = TextEditingController();

  // Google Form link
  final String adminRequestFormUrl =
      "https://docs.google.com/forms/d/e/your-google-form-link";

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _loadUserData();
    _updateLastLogin();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('roll', isEqualTo: widget.roll)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userDoc = querySnapshot.docs.first;
        final data = userDoc.data();
        setState(() {
          _userData = data;
          _loading = false;
        });
        _nameController.text = data['name'] ?? '';
        _slideController.forward();
      } else {
        setState(() {
          _userData = null;
          _loading = false;
        });
      }
    } catch (e) {
      _showSnackBar("Error loading user data: ${e.toString()}", Colors.red);
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _updateUserName(String newName) async {
    if (newName.trim().isEmpty) {
      _showSnackBar("Name cannot be empty", Colors.red);
      return;
    }

    setState(() => _updatingName = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('roll', isEqualTo: widget.roll)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userDoc = querySnapshot.docs.first.reference;
        await userDoc.update({'name': newName.trim()});

        setState(() {
          _userData!['name'] = newName.trim();
        });

        await _logActivity('Updated profile name');
        _showSnackBar("Name updated successfully!", Colors.green);
      }
    } catch (e) {
      _showSnackBar("Error updating name: ${e.toString()}", Colors.red);
    } finally {
      setState(() => _updatingName = false);
    }
  }

  void _showEditNameDialog() {
    _nameController.text = _userData!['name'] ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Name'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _updatingName
                  ? null
                  : () {
                Navigator.of(context).pop();
                _updateUserName(_nameController.text);
              },
              child: _updatingName
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateLastLogin() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('roll', isEqualTo: widget.roll)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userDoc = querySnapshot.docs.first;
        final userRef = userDoc.reference;

        final lastLoginTimestamp = userDoc.data()['lastLogin'];

        final updateData = {
          'lastLogin': Timestamp.now(),
        };

        if (lastLoginTimestamp != null) {
          updateData['previousLogin'] = lastLoginTimestamp;
        }

        await userRef.update(updateData);

        // After updating the login times, reload the user data
        // to ensure the UI has the new 'previousLogin' value.
        await _loadUserData();

        // Log the login activity
        await _logActivity('Logged into dashboard');
      }
    } catch (e) {
      print("Error updating last login: $e");
    }
  }

  Future<void> _logActivity(String action) async {
    try {
      await FirebaseFirestore.instance.collection('activities').add({
        'roll': widget.roll,
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error logging activity: $e");
    }
  }

  Future<void> _openGoogleForm() async {
    setState(() => _requestingAdmin = true);

    try {
      final Uri url = Uri.parse(adminRequestFormUrl);
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);

      if (launched) {
        await _logActivity('Requested admin access');
        _showSnackBar("Admin request form opened successfully!", Colors.green);
      } else {
        _showSnackBar("Failed to open Google Form", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error opening form: ${e.toString()}", Colors.red);
    } finally {
      setState(() => _requestingAdmin = false);
    }
  }

  Future<void> _refreshData() async {
    setState(() => _loading = true);
    await _loadUserData();
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == Colors.green ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final name = _userData?['name'] ?? 'User';
    final timeOfDay = DateTime.now().hour;
    final greeting = timeOfDay < 12
        ? 'Good Morning'
        : timeOfDay < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade600,
              Colors.deepPurple.shade800,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_userData?['department'] ?? 'Unknown Department'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutBack,
      )),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person,
                        color: Colors.deepPurple.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Profile Information",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.deepPurple.shade600),
                      onPressed: _refreshData,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoRow(Icons.badge, "Roll Number", _userData!['roll']),
                _buildEditableNameRow(),
                _buildInfoRow(Icons.school, "Department", _userData!['department']),
                _buildInfoRow(
                  Icons.admin_panel_settings,
                  "Role",
                  _userData!['role'] ?? 'user',
                  isRole: true,
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditableNameRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.person_outline,
            size: 20,
            color: Colors.deepPurple.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              "Full Name",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _userData!['name'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _showEditNameDialog,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.edit,
                      size: 16,
                      color: Colors.deepPurple.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildInfoRow(IconData icon, String label, String value,
      {bool isRole = false, bool isSubtle = false}) {
    final isAdmin = value.toLowerCase() == 'admin';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSubtle
                ? Colors.grey.shade500
                : Colors.deepPurple.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isSubtle ? 14 : 16,
                color: isSubtle ? Colors.grey.shade600 : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: isRole && isAdmin
                ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            )
                : Text(
              value,
              style: TextStyle(
                fontSize: isSubtle ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: isSubtle ? Colors.grey.shade600 : Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminRequestCard() {
    final isAdmin = (_userData?['role'] ?? 'user').toLowerCase() == 'admin';

    if (isAdmin) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.green.shade100],
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.admin_panel_settings,
                  color: Colors.green.shade700,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Admin Access Granted",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You have administrator privileges. You can manage events, users, and system settings.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.orange.shade50, Colors.orange.shade100],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.security,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "Request Admin Access",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "Want to help manage events and contribute to the platform? Request admin access by filling out our form. We'll review your request and get back to you soon!",
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _requestingAdmin ? null : _openGoogleForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                icon: _requestingAdmin
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Icon(Icons.open_in_new),
                label: Text(
                  _requestingAdmin ? "Opening Form..." : "Fill Admin Request Form",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple.shade600),
              ),
              const SizedBox(height: 16),
              Text(
                "Loading your dashboard...",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_userData == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                "User data not found",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Please check your connection and try again",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: Colors.deepPurple.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeHeader(),
              const SizedBox(height: 24),
              _buildStatsCard(),
              const SizedBox(height: 24),
              _buildAdminRequestCard(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}