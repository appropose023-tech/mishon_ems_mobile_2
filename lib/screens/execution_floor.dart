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
  bool _isSubmitting = false;
  
  final Map<String, bool> _defectChecklist = {
    "Solder Bridging Discrepancies": false,
    "Misaligned Component Variances": false,
    "Tombstoning Structural Errors": false,
    "Voiding Threshold Multi-Faults": false,
  };

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
    final bool isManagement = (role == 'admin' || role == 'manager');

    // Filter local active jobs safely
    List<JobBatch> visibleBatches = state.batches.where((b) => b.status == 'OPEN').toList();
    if (!isManagement) {
      visibleBatches = visibleBatches.where((b) => 
        state.targetingMatrix.any((target) => 
          target.batchNo == b.batchNo && 
          target.segment == userSegment && 
          target.team == userTeam
        )
      ).toList();
    }

    // Retain dropdown assignment if visible job rows match
    if (_selectedBatchNo != null && !visibleBatches.any((b) => b.batchNo == _selectedBatchNo)) {
      _selectedBatchNo = null;
    }

    JobBatch? activeBatchRef;
    if (_selectedBatchNo != null) {
      activeBatchRef = visibleBatches.firstWhere((b) => b.batchNo == _selectedBatchNo);
    }

    int cumulativeDone = 0;
    if (_selectedBatchNo != null) {
      cumulativeDone = state.getLayerRunningTotal(_selectedBatchNo!, _activeLayer);
    }

    int totalLimit = activeBatchRef?.initialQty ?? 0;
    int balanceQty = totalLimit - cumulativeDone;
    if (balanceQty < 0) balanceQty = 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Execution Logging"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: visibleBatches.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    "No active manufacturing batch allocations match your profile segment criteria.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Select Production Line Sequence Identifier",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: const Text("Select active operational batch..."),
                          value: _selectedBatchNo,
                          items: visibleBatches.map((b) {
                            return DropdownMenuItem<String>(
                              value: b.batchNo,
                              child: Text("Batch #${b.batchNo} - ${b.jobName}"),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedBatchNo = val),
                        ),
                      ),
                    ),
                    if (_selectedBatchNo != null && activeBatchRef != null) ...[
                      const SizedBox(height: 20),
                      Card(
                        elevation: 1,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMetricNode("BATCH TOTAL", "$totalLimit"),
                              _buildMetricNode("PROCESSED ($_activeLayer)", "$cumulativeDone"),
                              _buildMetricNode("REMAINING BAL", "$balanceQty"),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text("Component Placement Layer Configuration", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text("TOP"),
                              value: "TOP",
                              groupValue: _activeLayer,
                              onChanged: (v) => setState(() => _activeLayer = v!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text("BOTTOM"),
                              value: "BOTTOM",
                              groupValue: _activeLayer,
                              onChanged: (v) => setState(() => _activeLayer = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Yield Output Quantity Processed This Hour",
                          border: OutlineInputBorder(),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _commentController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: "Operational Discrepancy Comments / Shift Notes",
                          border: OutlineInputBorder(),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text("AOI Inspection Defect Matrix Validation Checklist", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
                      const SizedBox(height: 8),
                      ..._defectChecklist.keys.map((key) {
                        return CheckboxListTile(
                          title: Text(key, style: const TextStyle(fontSize: 14)),
                          value: _defectChecklist[key],
                          dense: true,
                          onChanged: (v) => setState(() => _defectChecklist[key] = v ?? false),
                        );
                      }).toList(),
                      const SizedBox(height: 24),
                      _isSubmitting
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF008080)))
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF008080),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () async {
                                int inputAmt = int.tryParse(_qtyController.text) ?? 0;
                                if (inputAmt <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Quantity completed must be greater than zero.")));
                                  return;
                                }
                                if (inputAmt > balanceQty) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error Validation: Quantities out of bounds tolerances. Maximum allowed: $balanceQty")));
                                  return;
                                }

                                setState(() => _isSubmitting = true);
                                
                                // Clean Execution matching your state engine backend future
                                await state.logHourlyStatus(
                                  _selectedBatchNo!, 
                                  _activeLayer, 
                                  inputAmt, 
                                  _commentController.text.trim()
                                );

                                setState(() => _isSubmitting = false);

                                _commentController.clear();
                                _qtyController.text = "1";
                                // Reset checklist matrix fields cleanly
                                _defectChecklist.updateAll((key, value) => false);
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Performance block committed successfully to structural database."), backgroundColor: Colors.green)
                                );
                              },
                              child: const Text(
                                "COMMIT HOURLY TRANSACTION DATA BLOCK", 
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)
                              ),
                            ),
                      const SizedBox(height: 40),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMetricNode(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF004d4d), fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF008080))),
      ],
    );
  }
}
