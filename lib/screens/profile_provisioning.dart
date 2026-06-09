import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_state.dart';

class ProfileProvisioningScreen extends StatefulWidget {
  const ProfileProvisioningScreen({super.key});

  @override
  State<ProfileProvisioningScreen> createState() => _ProfileProvisioningScreenState();
}

class _ProfileProvisioningScreenState extends State<ProfileProvisioningScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  String _selectedRole = "operator";
  String _selectedTeam = "Production";
  String _selectedSegment = "SMT";
  bool _isSubmitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Profile Provisioning Engine"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person_add, color: Color(0xFF008080), size: 28),
                        SizedBox(width: 10),
                        Text(
                          "Provision New Operator Profile",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
                        ),
                      ],
                    ),
                    const Divider(height: 30, thickness: 1),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: "Unique Username ID",
                        prefixIcon: Icon(Icons.account_box),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Username required" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Access Token / Password",
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().length < 4) ? "Password must be >= 4 chars" : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(labelText: "System Governance Role", border: OutlineInputBorder()),
                      items: ["admin", "manager", "supervisor", "operator"]
                          .map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                      onChanged: (v) => setState(() => _selectedRole = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedTeam,
                      decoration: const InputDecoration(labelText: "Shop Floor Department", border: OutlineInputBorder()),
                      items: ["Production", "Quality", "None"]
                          .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _selectedTeam = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedSegment,
                      decoration: const InputDecoration(labelText: "Line Process Segment", border: OutlineInputBorder()),
                      items: ["SMT", "Through hole", "None"]
                          .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _selectedSegment = v!),
                    ),
                    const SizedBox(height: 28),
                    _isSubmitting
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF008080)))
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF008080),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              if (!_formKey.currentState!.validate()) return;
                              setState(() => _isSubmitting = true);

                              try {
                                final res = await http.post(
                                  Uri.parse('${state.baseUrl}/api/provision_profile'),
                                  headers: {"Content-Type": "application/json"},
                                  body: json.encode({
                                    "username": _usernameController.text.trim(),
                                    "password": _passwordController.text.trim(),
                                    "role": _selectedRole,
                                    "team": _selectedTeam,
                                    "segment": _selectedSegment,
                                  }),
                                );

                                if (res.statusCode == 200) {
                                  _usernameController.clear();
                                  _passwordController.clear();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Operator profile committed safely to database."), backgroundColor: Colors.green)
                                  );
                                } else {
                                  final msg = json.decode(res.body)['message'] ?? "Failed to provision profile.";
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $msg"), backgroundColor: Colors.red));
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network failure context mapping error."), backgroundColor: Colors.red));
                              } finally {
                                setState(() => _isSubmitting = false);
                              }
                            },
                            child: const Text("COMMIT OPERATOR PROFILE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
