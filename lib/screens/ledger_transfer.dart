import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';

class InterDepartmentLedgerGatewayView extends StatefulWidget {
  const InterDepartmentLedgerGatewayView({Key? key}) : super(key: key);

  @override
  State<InterDepartmentLedgerGatewayView> createState() => _InterDepartmentLedgerGatewayViewState();
}

class _InterDepartmentLedgerGatewayViewState extends State<InterDepartmentLedgerGatewayView> {
  String? _batchNo;
  String _fromStage = "SMT_QUALITY";
  String _toStage = "TH_PRODUCTION";
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context);
    
    final String role = (state.currentUser?.role ?? 'operator').trim().toLowerCase();
    final String userTeam = state.currentUser?.team ?? 'None';
    final String userSegment = state.currentUser?.segment ?? 'None';
    final bool isManagement = (role == 'admin' || role == 'manager');

    List<JobBatch> openBatches = state.batches.where((b) => b.status == 'OPEN').toList();

    if (!isManagement) {
      openBatches = openBatches.where((b) => 
        state.targetingMatrix.any((target) => 
          target.batchNo == b.batchNo && 
          target.segment == userSegment && 
          target.team == userTeam
        )
      ).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Material Route Ledger"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Select Asset Logistical Identifier Code",
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
                    hint: const Text("Select active sequence batch..."),
                    value: _batchNo,
                    items: openBatches.map((b) {
                      return DropdownMenuItem<String>(
                        value: b.batchNo,
                        child: Text("Batch #${b.batchNo} - ${b.jobName}"),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _batchNo = val),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _fromStage,
                decoration: const InputDecoration(labelText: "Source Departure Node", filled: true, fillColor: Colors.white),
                items: ["SMT_PRODUCTION", "SMT_QUALITY", "TH_PRODUCTION", "TH_QUALITY", "POST_ASSEMBLY", "WAREHOUSE"]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _fromStage = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _toStage,
                decoration: const InputDecoration(labelText: "Destination Arrival Stage", filled: true, fillColor: Colors.white),
                items: ["SMT_PRODUCTION", "SMT_QUALITY", "TH_PRODUCTION", "TH_QUALITY", "POST_ASSEMBLY", "WAREHOUSE"]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _toStage = v!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Logistical Transfer Unit Volume",
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: "Traceability Sequence Remarks / Sign-off Comments",
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
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
                        if (_batchNo == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Please select a target batch.")));
                          return;
                        }
                        int inputQ = int.tryParse(_qtyController.text) ?? 0;
                        if (inputQ <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Quantity must be greater than zero.")));
                          return;
                        }

                        setState(() => _isSubmitting = true);
                        
                        // Fixed: Changed 'remarks:' parameter key to match your 'executeLedgerTransfer' implementation
                        String? err = await state.executeLedgerTransfer(
                          _batchNo!,
                          _fromStage,
                          _toStage,
                          inputQ,
                          _remarksController.text.trim(),
                        );

                        setState(() => _isSubmitting = false);

                        if (err == null) {
                          _qtyController.clear();
                          _remarksController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Traceability transactional token emitted successfully across chains."), backgroundColor: Colors.green)
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Rejection: $err"), backgroundColor: Colors.red)
                          );
                        }
                      },
                      child: const Text("EMIT SECURE LEDGER ROUTE ENTRY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
              const Divider(height: 40, thickness: 2),
              const Text("📋 Operational Tracking Ledger Historical Blocks", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.materialLedger.length,
                itemBuilder: (context, idx) {
                  final ent = state.materialLedger[idx];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.history_toggle_off, color: Color(0xFF008080)),
                      title: Text("Batch: ${ent.batchNo} -> ${ent.qtyTransferred} Units"),
                      subtitle: Text("Node Path: ${ent.fromStage} ➔ ${ent.toStage}\nSign-Off Operator: ${ent.operator}\nTimestamp: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(ent.timestamp)}"),
                      trailing: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
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
