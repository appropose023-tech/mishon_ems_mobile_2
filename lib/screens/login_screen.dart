import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'dashboard.dart';

class IdentityGatewayPortal extends StatefulWidget {
  const IdentityGatewayPortal({Key? key}) : super(key: key);

  @override
  State<IdentityGatewayPortal> createState() => _IdentityGatewayPortalState();
}

class _IdentityGatewayPortalState extends State<IdentityGatewayPortal> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isAuthenticating = false;

  void _processAuthentication(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isAuthenticating = true);
    final state = Provider.of<EMSStateEngine>(context, listen: false);

    // Properly await the network future response from your GCP server
    bool pass = await state.authenticateUser(
      _userController.text.trim(), 
      _passController.text.trim()
    );

    setState(() => _isAuthenticating = false);

    if (pass) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Authenticated: ${state.currentUser?.username.toUpperCase()} [Role: ${state.currentUser?.role.toUpperCase()}]"),
          backgroundColor: const Color(0xFF008080),
        ),
      );
      
      // Navigates directly to the role-filtering engine inside dashboard.dart
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => const DashboardScreen())
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Authentication Failed: Invalid credentials or offline terminal server."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF008080).withOpacity(0.2), width: 2),
                    ),
                    padding: const EdgeInsets.all(32.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "Mishon Solutions EMS",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Unified Floor Verification Terminal",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Color(0xFF008080), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _userController,
                            enabled: !_isAuthenticating,
                            decoration: const InputDecoration(
                              labelText: "Operator Username",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person, color: Color(0xFF008080)),
                            ),
                            validator: (v) => v!.isEmpty ? "Identifier required" : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passController,
                            obscureText: true,
                            enabled: !_isAuthenticating,
                            decoration: const InputDecoration(
                              labelText: "Secure Token Password",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock, color: Color(0xFF008080)),
                            ),
                            validator: (v) => v!.isEmpty ? "Password required" : null,
                          ),
                          const SizedBox(height: 24),
                          _isAuthenticating
                              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080))))
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF008080),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () => _processAuthentication(context),
                                  child: const Text("AUTHENTICATE SYSTEM ACCESS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildCorporateFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildCorporateFooter() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFF008080), width: 2)),
      ),
      padding: const EdgeInsets.all(12),
      child: const Text(
        "Mishon Solutions | www.mishonsolutions.com | contact: info@mishonsolutions.com",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: Color(0xFF004d4d), fontWeight: FontWeight.w600),
      ),
    );
  }
}
