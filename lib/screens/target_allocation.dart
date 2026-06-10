import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_state.dart';
import '../models.dart';

class TargetAllocationScreen extends StatefulWidget {
  const TargetAllocationScreen({super.key});

  @override
  State<TargetAllocationScreen> createState() => _TargetAllocationScreenState();
}

class _TargetAllocationScreenState extends State<TargetAllocationScreen> {
  final TextEditingController _qtyController = TextEditingController();
  String? _selectedBatch;
  String _segment = "SMT";
  String _team = "Production";
  bool _isSaving = false;

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context);
    
    // GOVERNANCE RULE: Hides closed jobs entirely from target assignments
    final activeBatches = state.batches.where((b) => b.status == 'OPEN').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Target Allocation Matrix"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Allocate Line Target Constraints",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedBatch,
                        hint: const Text("Select active sequence batch..."),
                        decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                        items: activeBatches.map((b) {
                          return DropdownMenuItem(value: b.batchNo, child: Text("Batch #${b.batchNo} - ${b.jobName}"));
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedBatch = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _segment,
                        decoration: const InputDecoration(labelText: "Floor Segment Node", border: OutlineInputBorder()),
                        items: ["SMT", "Through hole", "None"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _segment = v!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _team,
                        decoration: const InputDecoration(labelText: "Operational Sub-Team", border: OutlineInputBorder()),
                        items: ["Production", "Quality", "None"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() => _team = v!),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Target Quantity Threshold Bound", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      _isSaving
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF008080)))
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)),
                              onPressed: () async {
                                int q = int.tryParse(_qtyController.text) ?? 0;
                                if (_selectedBatch == null || q <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Select an active open batch and non-zero volume.")));
                                  return;
                                }
                                setState(() => _isSaving = true);
                                try {
                                  final res = await http.post(
                                    Uri.parse('${state.baseUrl}/api/provision_target'),
                                    headers: {"Content-Type": "application/json"},
                                    body: json.encode({
                                      "batch_no": _selectedBatch,
                                      "segment": _segment,
                                      "team": _team,
                                      "target_qty": q
                                    }),
                                  );
                                  if (res.statusCode == 200) {
                                    await state.fetchAndSyncFromBackend();
                                    _qtyController.clear();
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Target profile saved to live floor guidelines."), backgroundColor: Colors.green));
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network submission error context failure.")));
                                } finally {
                                  setState(() => _isSaving = false);
                                }
                              },
                              child: const Text("REGISTER EXCELLENCE TARGET", style: TextStyle(color: Colors.white)),
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Active Floor Allocation Targets Matrix", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004d4d))),
              const SizedBox(height: 8),
              state.targetingMatrix.isEmpty
                  ? const Text("No targeted constraints tracked inside the framework yet.", style: TextStyle(color: Colors.grey, fontSize: 13))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.targetingMatrix.length,
                      itemBuilder: (context, idx) {
                        final tm = state.targetingMatrix[idx];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.radar, color: Color(0xFF008080)),
                            title: Text("Batch #${tm.batchNo} (${tm.segment} - ${tm.team})"),
                            subtitle: Text("Target Capacity limit: ${tm.targetQty} Units"),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
