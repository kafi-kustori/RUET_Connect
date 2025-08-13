import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'options.dart';  // import your options page

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _rollController = TextEditingController();
  final TextEditingController _deptController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _loginUser() async {
    final roll = _rollController.text.trim();
    final department = _deptController.text.trim();
    final password = _passwordController.text.trim();

    if (roll.isEmpty || department.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ All fields are required!")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Query Firestore for user
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('roll', isEqualTo: roll)
          .where('department', isEqualTo: department)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final user = snapshot.docs.first.data();
        final userRoll = user['roll'];
        final userRole = user['role'] ?? 'user'; // Default to 'user' if role missing

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Welcome ${user['name']}!")),
        );

        // Navigate to options page passing both roll and role
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OptionsPage(userRoll: userRoll, userRole: userRole),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Invalid credentials!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login"),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _rollController,
              decoration: const InputDecoration(
                labelText: "Roll",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _deptController,
              decoration: const InputDecoration(
                labelText: "Department",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _loginUser,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Login"),
            ),
          ],
        ),
      ),
    );
  }
}
