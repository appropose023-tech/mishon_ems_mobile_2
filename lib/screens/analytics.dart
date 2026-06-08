import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart'; // Assumes JobBatch and FloorTarget live here

class OperationalAnalyticsMatrixView extends StatefulWidget {
  const OperationalAnalyticsMatrixView({Key? key}) : super(key: key);

  @override
  State<OperationalAnalyticsMatrixView> createState() => _OperationalAnalyticsMatrixViewState();
}

class _OperationalAnalyticsMatrixViewState extends State<OperationalAnalyticsMatrixView> {
  final TextEditingController _targetQtyController = TextEditingController();
  String? _selectedBatchTarget; // Replaced text controller with a state variable
  String _segmentTarget = "SMT";
  String _teamTarget = "Production";

  @override
  void dispose() {
    _targetQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context);
    
    // Extract closed batches for dispatch clearance
    final closedBatches = state.batches.where((b) => b.status == 'CLOSED').toList();
    
    // Extract open/active batches to populate your new target assignment dropdown
    final activeBatches = state.batches.where((b) => b.status == 'OPEN').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ----------------------------------------------------
          // 1. OUTBOUND DESPATCH APPROVALS
          // ----------------------------------------------------
          if (closedBatches.isNotEmpty) ...[
            const Text(
              "Outbound Despatch Pending Approvals Request List", 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
            ),
            const SizedBox(height: 12),
            ...closedBatches.map((cb) => Card(
              color: Colors.amber[50],
              child: ListTile(
                title: Text("Batch: ${cb.batchNo} (${cb.projectName})", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Status: Pending Final Sign-Off to Billing Dispatch Archives."),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle, color: Color(0xFF008080)),
                  onPressed: () {
                    state.dispatchBillingClearance(cb.batchNo);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Despatch clearance tracking authorized for batch ${cb.batchNo}."))
                    );
                  },
                ),
              ),
            )).toList(),
            const Divider(height: 32),
          ],

          // ----------------------------------------------------
          // 2. INJECT FLOOR TARGETS (CONFIGURED WITH DROPDOWNS)
          // ----------------------------------------------------
          const Text(
            "Inject Floor Target Routing Baseline Configurations", 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
          ),
          const SizedBox(height: 12),
          
          // Dynamic Database-Driven Batch Dropdown Selector
          DropdownButtonFormField<String>(
            value: _selectedBatchTarget,
            decoration: const InputDecoration(
              labelText: "Select Active Target Batch",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.layers, color: Color(0xFF008080)),
            ),
            hint: const Text("Choose a running floor batch sequence..."),
            items: activeBatches.map((JobBatch batch) {
              return DropdownMenuItem<String>(
                value: batch.batchNo,
                child: Text("${batch.batchNo} [${batch.projectName}]"),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedBatchTarget = value;
              });
            },
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _segmentTarget,
                  decoration: const InputDecoration(labelText: "Line Segment", border: OutlineInputBorder()),
                  items: ["SMT", "Through hole"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _segmentTarget = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _teamTarget,
                  decoration: const InputDecoration(labelText: "Floor Domain", border: OutlineInputBorder()),
                  items: ["Production", "Quality"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _teamTarget = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          TextFormField(
            controller: _targetQtyController, 
            keyboardType: TextInputType.number, 
            decoration: const InputDecoration(labelText: "Target Volume Capacity Metrics", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)),
            onPressed: () {
              int tq = int.tryParse(_targetQtyController.text) ?? 0;
              if (_selectedBatchTarget != null && _selectedBatchTarget!.isNotEmpty && tq > 0) {
                state.provisionNewTarget(_selectedBatchTarget!, _segmentTarget, _teamTarget, tq);
                
                _targetQtyController.clear();
                setState(() {
                  _selectedBatchTarget = null; // Clear selection after submission
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Target profiles registered safely inside operational parameters."))
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please select a valid batch identifier and non-zero target volume."))
                );
              }
            },
            child: const Text("REGISTER TARGET PARAMETER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 32),

          // ----------------------------------------------------
          // 3. COMPARATIVE YIELD PERFORMANCE REPORTS
          // ----------------------------------------------------
          const Text(
            "Comparative Yield Performance Reports vs Target Bounds", 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
          ),
          const SizedBox(height: 12),
          
          ...state.targetingMatrix.map((tm) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.trending_up, color: Color(0xFF004d4d)),
                title: Text("Batch: ${tm.batchNo} [${tm.segment} - ${tm.team}]"),
                subtitle: Text("Target Capacity Bounds: ${tm.targetQty} Units"),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
