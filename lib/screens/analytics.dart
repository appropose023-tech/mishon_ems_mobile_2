import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_state.dart';
import '../models.dart';

class OperationalAnalyticsMatrixView extends StatefulWidget {
  const OperationalAnalyticsMatrixView({Key? key}) : super(key: key);

  @override
  State<OperationalAnalyticsMatrixView> createState() => _OperationalAnalyticsMatrixViewState();
}

class _OperationalAnalyticsMatrixViewState extends State<OperationalAnalyticsMatrixView> {
  final TextEditingController _targetQtyController = TextEditingController();
  String? _selectedBatchTarget;
  String _segmentTarget = "SMT";
  String _teamTarget = "Production";
  bool _isProcessingTarget = false;

  @override
  void dispose() {
    _targetQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context);
    final closedBatches = state.batches.where((b) => b.status == 'CLOSED').toList();
    final activeBatches = state.batches.where((b) => b.status == 'OPEN').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Analytics & Quality Target Control"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Closed Batches Awaiting Logistical Dispatch Clearance",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
            ),
            const SizedBox(height: 8),
            closedBatches.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("No batches currently isolated in closed status bounds.", style: TextStyle(color: Colors.grey)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: closedBatches.length,
                    itemBuilder: (context, idx) {
                      final cb = closedBatches[idx];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text("Batch #${cb.batchNo} - ${cb.jobName}"),
                          subtitle: Text("Client Target: ${cb.clientName} | Qty: ${cb.initialQty}"),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008080)),
                            onPressed: () async {
                              // Fixed: Named to match your exact engine definition method name
                              await state.transmitBatchCloseEvent(cb.batchNo);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Batch clearance status transmission successful."))
                              );
                            },
                            child: const Text("DISPATCH", style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      );
                    },
                  ),
            const Divider(height: 32),
            const Text(
              "Provision Target Metrics Allocation Map",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
            ),
            const SizedBox(height: 12),
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
                  hint: const Text("Select active operational batch sequence..."),
                  value: _selectedBatchTarget,
                  items: activeBatches.map((b) {
                    return DropdownMenuItem<String>(
                      value: b.batchNo,
                      child: Text("Batch #${b.batchNo} - ${b.jobName}"),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedBatchTarget = val),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _segmentTarget,
              decoration: const InputDecoration(labelText: "Shop Floor Segment Node", filled: true, fillColor: Colors.white),
              items: ["SMT", "Through hole", "None"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _segmentTarget = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _teamTarget,
              decoration: const InputDecoration(labelText: "Operational Sub-Team Assignment", filled: true, fillColor: Colors.white),
              items: ["Production", "Quality", "None"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _teamTarget = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetQtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Target Yield Upper Bound Threshold Volume",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _isProcessingTarget
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF008080)))
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004d4d),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      int tq = int.tryParse(_targetQtyController.text) ?? 0;
                      if (_selectedBatchTarget != null && tq > 0) {
                        setState(() => _isProcessingTarget = true);
                        try {
                          final res = await http.post(
                            Uri.parse('${state.baseUrl}/api/provision_target'),
                            headers: {"Content-Type": "application/json"},
                            body: json.encode({
                              "batch_no": _selectedBatchTarget,
                              "segment": _segmentTarget,
                              "team": _teamTarget,
                              "target_qty": tq
                            }),
                          );
                          if (res.statusCode == 200) {
                            await state.fetchAndSyncFromBackend();
                            _targetQtyController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Target profiles registered safely inside operational parameters."), backgroundColor: Colors.green)
                            );
                          } else {
                            throw Exception("Server rejection exception parameter.");
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Failed to save target entry bounds securely."), backgroundColor: Colors.red)
                          );
                        } finally {
                          setState(() => _isProcessingTarget = false);
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please select a valid batch identifier and non-zero target volume."))
                        );
                      }
                    },
                    child: const Text("REGISTER TARGET PARAMETER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
            const Divider(height: 32),
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
      ),
    );
  }
}
