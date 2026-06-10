import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart'; 

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
  bool _isSubmittingLog = false;
  
  final Map<String, bool> _defectChecklist = {
    "Solder Bridging Discrepancies": false,
    "Misaligned Component Variances": false,
    "Tombstoning Structural Errors": false,
    "Voiding Threshold Multi-Faults": false,
  };
  final Map<String, double> _defectWeights = {};

  @override
  void dispose() {
    _qtyController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context);
    
    final String role = (state.currentUser?.role ?? 'operator').trim().toLowerCase();
    final String userTeam = state.currentUser?.team ?? 'None';
    final String userSegment = state.currentUser?.segment ?? 'None';

    // Filter available batches down to items matching visibility rules calculated in app_state
    final visibleBatches = state.batches;

    // Resolve details for currently highlighted line batch selection
    JobBatch? chosenBatch;
    if (_selectedBatchNo != null) {
      try {
        chosenBatch = visibleBatches.firstWhere((element) => element.batchNo == _selectedBatchNo);
      } catch (_) {
        chosenBatch = null;
      }
    }

    int balanceQty = chosenBatch?.initialQty ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Execution Floor Assembly Terminal"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Log Daily Assembly Output Metrics",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedBatchNo,
              hint: const Text("Select allocated batch route..."),
              decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              items: visibleBatches.map((b) {
                return DropdownMenuItem(
                  value: b.batchNo,
                  child: Text("Batch #${b.batchNo} (${b.jobName}) — Available Balance: ${b.initialQty}"),
                );
              }).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedBatchNo = v;
                  _qtyController.text = "1";
                });
              },
            ),
            const SizedBox(height: 12),
            if (_selectedBatchNo != null && chosenBatch != null) ...[
              Card(
                color: Colors.white,
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Client Profile: ${chosenBatch.clientName}", style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text("Project Identity: ${chosenBatch.projectName}", style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text("Assigned Line Node Location: $userSegment [Team: $userTeam]", style: const TextStyle(color: Color(0xFF008080), fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _surfaceConfig,
                      decoration: const InputDecoration(labelText: "PCB Configuration", border: OutlineInputBorder()),
                      items: ["Single-Sided", "Double-Sided"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _surfaceConfig = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _activeLayer,
                      decoration: const InputDecoration(labelText: "Execution Board Side", border: OutlineInputBorder()),
                      items: ["TOP", "BOTTOM"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _activeLayer = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Finished Pass Log Volume Qty", border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(labelText: "Operational Station Notes / Comments", border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text("Quality Defect Inspection Checklist Matrix", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004d4d))),
              const SizedBox(height: 8),
              ..._defectChecklist.keys.map((defectKey) {
                return CheckboxListTile(
                  title: Text(defectKey, style: const TextStyle(fontSize: 13)),
                  activeColor: const Color(0xFF008080),
                  value: _defectChecklist[defectKey],
                  onChanged: (val) {
                    setState(() {
                      _defectChecklist[defectKey] = val ?? false;
                    });
                  },
                );
              }).toList(),
              const SizedBox(height: 16),
              _isSubmittingLog
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF008080)))
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008080),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        int inputAmt = int.tryParse(_qtyController.text) ?? 0;
                        if (inputAmt > 0 && inputAmt <= balanceQty) {
                          setState(() => _isSubmittingLog = true);
                          
                          // Corrected: Just call the future without trying to catch a non-existent return string.
                          await state.logHourlyStatus(
                            _selectedBatchNo!, 
                            _activeLayer, 
                            inputAmt, 
                            _commentController.text.trim()
                          );
                          
                          setState(() => _isSubmittingLog = false);
                          _commentController.clear();
                          _qtyController.text = "1";
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Performance blocks committed successfully to server."), backgroundColor: Colors.green)
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Error Validation: Quantities out of bounds tolerances."), backgroundColor: Colors.orange)
                          );
                        }
                      },
                      child: const Text("COMMIT HOURLY TRANSACTION DATA BLOCK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}
