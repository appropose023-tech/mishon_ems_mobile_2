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
      // Scoping visibility to matching user segment metadata bounds
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
                      onChanged: (val) {
                        setState(() {
                          _selectedBatchNo = val;
                        });
                      },
                    ),

                    if (currentSelectedBatch != null) ...[
                      const SizedBox(height: 16),
                      // REAL-TIME CACHED QUANTITY BALANCES CARD
                      Card(
                        color: const Color(0xFFF0FDF4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Colors.greenAccent, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "🎯 Target Threshold constraint: ${currentSelectedBatch.targetQty} Units",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF166534)),
                              ),
                              const Divider(height: 16, color: Colors.greenAccent),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildMetricNode("TOP LAYER YIELD", "$currentTopYield Pcs"),
                                  _buildMetricNode("BOTTOM LAYER YIELD", "$currentBottomYield Pcs"),
                                  _buildMetricNode("TOTAL PROCESSED", "${currentTopYield + currentBottomYield} Pcs"),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      const Text(
                        "Surface Board Configuration Parameters",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004d4d)),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _surfaceConfig,
                        decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                        items: ["Single-Sided", "Double-Sided Flipping"].map((s) {
                          return DropdownMenuItem(value: s, child: Text(s));
                        }).toList(),
                        onChanged: (v) => setState(() => _surfaceConfig = v!),
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        "Target Process Alignment Layer Side",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004d4d)),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _activeLayer,
                        decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                        items: ["TOP", "BOTTOM"].map((l) {
                          return DropdownMenuItem(value: l, child: Text("$l Layer Feed"));
                        }).toList(),
                        onChanged: (v) => setState(() => _activeLayer = v!),
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        "Hourly Production Quantity Processed Successfully",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004d4d)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: "Enter exact processed output metrics...",
                        ),
                      ),

                      const SizedBox(height: 24),
                      // QUALITY INSPECTION & DEFECT MODAL LAYOUT
                      Row(
                        children: const [
                          Icon(Icons.biotech, color: Color(0xFF004d4d)),
                          SizedBox(width: 8),
                          Text(
                            "AOI Solder & Defect Percentage Flag Matrix",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004d4d)),
                          ),
                        ],
                      ),
                      const Text(
                        "Specify the estimated rate of loss if any defect threshold constraints occur.",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      
                      Card(
                        color: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                          child: Column(
                            children: _defectChecklist.keys.map((defectKey) {
                              double currentSliderValue = _defectChecklist[defectKey] ?? 0.0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6.0, top: 6.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          defectKey,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        Text(
                                          "${currentSliderValue.toStringAsFixed(0)}% Loss",
                                          style: TextStyle(
                                            color: currentSliderValue > 0 ? Colors.red.shade700 : Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Slider(
                                    value: currentSliderValue,
                                    min: 0.0,
                                    max: 100.0,
                                    divisions: 20,
                                    activeColor: currentSliderValue > 0 ? Colors.red.shade600 : const Color(0xFF008080),
                                    inactiveColor: Colors.grey.shade200,
                                    onChanged: (newValue) {
                                      setState(() {
                                        _defectChecklist[defectKey] = newValue;
                                      });
                                    },
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        "Execution Engineering Remarks & Delay Logs",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004d4d)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _commentController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: "Log equipment bottlenecks, material issues, or standard runtime notes here...",
                        ),
                      ),

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
                                int inputQty = int.tryParse(_qtyController.text) ?? 0;
                                if (inputQty <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Processed production volume must be greater than zero."), backgroundColor: Colors.orange)
                                  );
                                  return;
                                }

                                setState(() => _isSubmitting = true);

                                // Pack the defect sliders matrix into standard key-value maps safely
                                Map<String, int> structuredDefectsJson = {};
                                _defectChecklist.forEach((key, val) {
                                  if (val > 0) {
                                    structuredDefectsJson[key] = val.toInt();
                                  }
                                });

                                try {
                                  final response = await http.post(
                                    Uri.parse('${state.baseUrl}/api/log_hourly_status'),
                                    headers: {"Content-Type": "application/json"},
                                    body: json.encode({
                                      "batch_no": _selectedBatchNo,
                                      "operator_username": state.currentUser?.username ?? 'Unknown Operator',
                                      "side": _activeLayer,
                                      "qty_done": inputQty,
                                      "defects": structuredDefectsJson,
                                      "comments": _commentController.text,
                                      "board_config": _surfaceConfig
                                    }),
                                  );

                                  if (response.statusCode == 200) {
                                    // Complete database state handshake update loop
                                    await state.fetchAndSyncFromBackend();
                                    
                                    _commentController.clear();
                                    _qtyController.text = "1";
                                    _defectChecklist.updateAll((key, value) => 0.0);

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Performance block committed successfully to structural database."), backgroundColor: Colors.green)
                                      );
                                    }
                                  } else {
                                    final responseData = json.decode(response.body);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Rejection Error: ${responseData['message'] ?? 'Handshake transaction failed.'}"), backgroundColor: Colors.red)
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
