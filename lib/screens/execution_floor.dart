import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class ExecutionFloorAssemblyView extends StatefulWidget {
  const ExecutionFloorAssemblyView({Key? key}) : super(key: key);

  @override
  State<ExecutionFloorAssemblyView> createState() => _ExecutionFloorAssemblyViewState();
}

class _ExecutionFloorAssemblyViewState extends State<ExecutionFloorAssemblyView> {
  String? _selectedBatchNo;
  String _surfaceConfig = "Single-Sided";
  String _activeLayer = "TOP";
  final TextEditingController _qtyController = TextEditingController(text: "1");
  final TextEditingController _commentController = TextEditingController();
  
  final Map<String, bool> _defectChecklist = {
    "Solder Bridging Discrepancies": false,
    "Misaligned Component Variances": false,
    "Tombstoning Structural Errors": false,
    "Voiding Threshold Multi-Faults": false,
  };
  final Map<String, double> _defectWeights = {};

  @override
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

    if (state.activePunchInTime == null) {
      return const Center(child: Text("🔒 Access Blocked: Initialize active shift punch to display tracking interfaces.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)));
    }

    if (openBatches.isEmpty) {
      return const Center(child: Text("No active manufacturing pipelines available inside profile allocations."));
    }

    _selectedBatchNo ??= openBatches.first.batchNo;
    final activeBatch = openBatches.firstWhere((b) => b.batchNo == _selectedBatchNo);

    int totalProcessed = state.getLayerRunningTotal(_selectedBatchNo!, _activeLayer);
    int balanceQty = activeBatch.initialQty - totalProcessed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedBatchNo,
            decoration: const InputDecoration(labelText: "Active Job Batch Selector Matrix", border: OutlineInputBorder()),
            items: openBatches.map((b) => DropdownMenuItem(value: b.batchNo, child: Text("${b.batchNo} (${b.projectName})"))).toList(),
            onChanged: (v) => setState(() => _selectedBatchNo = v),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _surfaceConfig,
                  decoration: const InputDecoration(labelText: "Surface Strategy Configuration", border: OutlineInputBorder()),
                  items: ["Single-Sided", "Double-Sided"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() {
                    _surfaceConfig = v!;
                    if (_surfaceConfig == "Single-Sided") _activeLayer = "TOP";
                  }),
                ),
              ),
              if (_surfaceConfig == "Double-Sided") ...[
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _activeLayer,
                    decoration: const InputDecoration(labelText: "Target Execution Layer", border: OutlineInputBorder()),
                    items: ["TOP", "BOTTOM"].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setState(() => _activeLayer = v!),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Card(
            color: const Color(0xFFE6F2F2),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricNode("Allocated Volume", "${activeBatch.initialQty} Units"),
                  _buildMetricNode("Balance Remaining", "$balanceQty Units"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (balanceQty <= 0) ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
              onPressed: () {
                state.closeBatchProcessingBlock(_selectedBatchNo!);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Batch marked as CLOSED. Relayed to billing tracking modules.")));
              },
              child: const Text("LOCK & FINALIZE BATCH TIMELINE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ] else ...[
            TextFormField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Processed Output Units Inside Selection Interval", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _commentController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: "Observations / Structural Manual Comments Diary", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text("⚠️ Process Defect Variance Matrix (Quality Assessment Mode)", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
            ..._defectChecklist.keys.map((defect) {
              _defectWeights[defect] ??= 0.0;
              return Column(
                children: [
                  CheckboxListTile(
                    title: Text(defect, style: const TextStyle(fontSize: 14)),
                    value: _defectChecklist[defect],
                    onChanged: (v) => setState(() => _defectChecklist[defect] = v!),
                  ),
                  if (_defectChecklist[defect] == true)
                    Slider(
                      value: _defectWeights[defect]!,
                      min: 0, max: 100, divisions: 20,
                      label: "${_defectWeights[defect]!.toStringAsFixed(0)}%",
                      onChanged: (v) => setState(() => _defectWeights[defect] = v),
                    ),
                ],
              );
            }).toList(),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)),
              onPressed: () {
                int inputAmt = int.tryParse(_qtyController.text) ?? 0;
                if (inputAmt > 0 && inputAmt <= balanceQty) {
                  state.commitHourlyStatus(_selectedBatchNo!, _activeLayer, inputAmt,_commentController.text.trim());
                  _commentController.clear();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Performance block committed successfully to structural database.")));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error Validation: Quantities out of bounds tolerances.")));
                }
              },
              child: const Text("COMMIT HOURLY TRANSACTION DATA BLOCK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricNode(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF004d4d), fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF008080))),
      ],
    );
  }
}
