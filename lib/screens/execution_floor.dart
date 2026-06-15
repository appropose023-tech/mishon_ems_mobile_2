import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
  
  // Real-time Defect Loss Percentage Matrix State Bounds
  final Map<String, double> _defectChecklist = {
    "Solder Bridging Discrepancies": 0.0,
    "Misaligned Component Variances": 0.0,
    "Tombstoning Structural Errors": 0.0,
    "Voiding Threshold Multi-Faults": 0.0,
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

    // Filter active open batches so floor operators only see relevant jobs
    List<JobBatch> visibleBatches = state.batches.where((b) {
      if (b.status != 'OPEN') return false;
      if (isManagement) return true;
      return true; 
    }).toList();

    // Look up real-time statistics if a valid batch index is chosen
    JobBatch? currentSelectedBatch;
    if (_selectedBatchNo != null) {
      try {
        currentSelectedBatch = state.batches.firstWhere((b) => b.batchNo == _selectedBatchNo);
      } catch (_) {
        currentSelectedBatch = null;
      }
    }

    // Look up the targeted threshold bound dynamically from targeting matrix
    int targetedVolumeRequired = 0;
    if (_selectedBatchNo != null) {
      try {
        final matchingTarget = state.targetingMatrix.firstWhere(
          (t) => t.batchNo == _selectedBatchNo && t.segment == userSegment && t.team == userTeam
        );
        targetedVolumeRequired = matchingTarget.targetQty;
      } catch (_) {
        targetedVolumeRequired = 0; // Fallback bound configuration
      }
    }

    // Read counter yields safely from memory maps inside app_state
    int currentTopYield = _selectedBatchNo != null ? state.getLayerRunningTotal(_selectedBatchNo!, "TOP") : 0;
    int currentBottomYield = _selectedBatchNo != null ? state.getLayerRunningTotal(_selectedBatchNo!, "BOTTOM") : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Execution Floor Assembly Log"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: visibleBatches.isEmpty && !isManagement
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    "No open production logs are allocated within your segment layer currently.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ROW CHIP LABELS FOR SECURITY LAYER FEEDBACK
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.person, size: 16, color: Color(0xFF004d4d)),
                          label: Text("Operator: ${state.currentUser?.username ?? 'Guest'}"),
                          backgroundColor: const Color(0xFFE6F2F2),
                        ),
                        Chip(
                          avatar: const Icon(Icons.layers, size: 16, color: Color(0xFF004d4d)),
                          label: Text("Segment Node: $userSegment"),
                          backgroundColor: const Color(0xFFE6F2F2),
                        ),
                        Chip(
                          avatar: const Icon(Icons.groups, size: 16, color: Color(0xFF004d4d)),
                          label: Text("Team: $userTeam"),
                          backgroundColor: const Color(0xFFE6F2F2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // BATCH SELECTOR DROPDOWN BOUND CONSTRAINTS
                    const Text(
                      "Select Production Job Target",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004d4d)),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedBatchNo,
                      hint: const Text("Select active assembly batch code..."),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: visibleBatches.map((b) {
                        return DropdownMenuItem(
                          value: b.batchNo,
                          child: Text("Batch #${b.batchNo} — ${b.jobName} [Client: ${b.clientName}]"),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedBatchNo = val),
                    ),

                    if (currentSelectedBatch != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: const Color(0xFFF0FDF4),
                        elevation: 0.5,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "🎯 Target Threshold Bound: $targetedVolumeRequired Units Required",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534), fontSize: 13),
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildMetricNode("TOP LAYER YIELD", "$currentTopYield Pcs Completed"),
                                  _buildMetricNode("BOTTOM LAYER YIELD", "$currentBottomYield Pcs Completed"),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _surfaceConfig,
                        decoration: const InputDecoration(
                          labelText: "Board Surface Topology Configuration",
                          border: OutlineInputBorder(),
                        ),
                        items: ["Single-Sided", "Double-Sided Flipping"].map((s) {
                          return DropdownMenuItem(value: s, child: Text(s));
                        }).toList(),
                        onChanged: (v) => setState(() => _surfaceConfig = v!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _activeLayer,
                        decoration: const InputDecoration(
                          labelText: "Layer Feed Side Matrix Target",
                          border: OutlineInputBorder(),
                        ),
                        items: ["TOP", "BOTTOM"].map((l) {
                          return DropdownMenuItem(value: l, child: Text(l));
                        }).toList(),
                        onChanged: (v) => setState(() => _activeLayer = v!),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Hourly Processed Volume Success (Units)",
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        "AOI Solder & Defect Percentage Flag Matrix",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004d4d)),
                    ),
                      const SizedBox(height: 8),
                      
                      // RENDER PERCENT SLIDERS
                      Card(
                        elevation: 0.5,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            children: _defectChecklist.keys.map((defectKey) {
                              double curVal = _defectChecklist[defectKey] ?? 0.0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(defectKey, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
                                        Text(
                                          "${curVal.toStringAsFixed(0)}% Loss Rate", 
                                          style: TextStyle(
                                            color: curVal > 0 ? Colors.red : Colors.grey, 
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12
                                          ),
                                        ),
                                      ],
                                    ),
                                    Slider(
                                      value: curVal,
                                      min: 0.0,
                                      max: 100.0,
                                      divisions: 20,
                                      activeColor: curVal > 0 ? Colors.red : const Color(0xFF008080),
                                      inactiveColor: Colors.grey.shade200,
                                      onChanged: (nv) => setState(() => _defectChecklist[defectKey] = nv),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          labelText: "Delay Log Remarks & Process Signatures",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _isSubmitting
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF008080)))
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF008080),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () async {
                                int inputQty = int.tryParse(_qtyController.text) ?? 0;
                                if (inputQty <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Please supply positive yield metric quantities before committing."))
                                  );
                                  return;
                                }
                                setState(() => _isSubmitting = true);

                                // Map numerical double integers cleanly into network uploads
                                Map<String, int> structuredDefects = {};
                                _defectChecklist.forEach((k, v) {
                                  if (v > 0) {
                                    structuredDefects[k] = v.toInt();
                                  }
                                });

                                try {
                                  final response = await http.post(
                                    Uri.parse('${state.baseUrl}/api/log_hourly_status'),
                                    headers: {"Content-Type": "application/json"},
                                    body: json.encode({
                                      "batch_no": _selectedBatchNo,
                                      "operator_username": state.currentUser?.username ?? 'Operator',
                                      "side": _activeLayer,
                                      "qty_done": inputQty,
                                      "defects": structuredDefects,
                                      "comments": _commentController.text,
                                      "board_config": _surfaceConfig
                                    }),
                                  );
                                  
                                  if (response.statusCode == 200) {
                                    await state.fetchAndSyncFromBackend();
                                    if (mounted) {
                                      _commentController.clear();
                                      _qtyController.text = "1";
                                      _defectChecklist.updateAll((key, value) => 0.0);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Performance block committed successfully to structural database."), backgroundColor: Colors.green)
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Structural network transport failure: $e"), backgroundColor: Colors.red)
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _isSubmitting = false);
                                  }
                                }
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
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF004d4d), fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF008080))),
      ],
    );
  }
}
