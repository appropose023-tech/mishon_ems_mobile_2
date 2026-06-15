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
  String _fromStage = "SMT";
  String _toStage = "Through hole";
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

    // Filter active open batches so floor operators only see their assigned target segments/teams
    List<JobBatch> visibleFormBatches = state.batches.where((b) => b.status == 'OPEN').toList();
    if (!isManagement) {
      visibleFormBatches = visibleFormBatches.where((b) => 
        state.targetingMatrix.any((target) => 
          target.batchNo == b.batchNo && 
          target.segment == userSegment && 
          target.team == userTeam
        )
      ).toList();
    }

    // Dynamic safety fallback if a previously selected batch falls out of scope following a sync loop
    if (_batchNo != null && !visibleFormBatches.any((b) => b.batchNo == _batchNo)) {
      _batchNo = null;
    }

    // Visibility Scoping Layer for Logs filtering
    final filteredLedger = state.materialLedger.where((ent) {
      if (isManagement) return true;
      return ent.fromStage == userSegment || ent.toStage == userSegment;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), 
      appBar: AppBar(
        title: const Text("Inter-Department Ledgers"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Assignment Context Tag Info Widget
              Card(
                elevation: 0,
                color: const Color(0xFFE2E8F0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.account_tree, color: Color(0xFF004d4d)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isManagement ? "Scope Context: Comprehensive Factory Matrix" : "Scope Context Account: $userSegment Segment Routing Only",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004d4d), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ADMINISTRATIVE GLOBAL QUANTITY SPLIT-STATUS REPORT MATRIX
              if (isManagement) ...[
                const Text(
                  "📊 Management System Matrix Split View (Current Status)",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))
                ),
                const SizedBox(height: 8),
                Card(
                  color: Colors.blueGrey.shade900,
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Active Batch Material Distribution Breakdown:", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (state.batches.isEmpty)
                          const Text("No batches available inside memory cache buffers.", style: TextStyle(color: Colors.white38, fontSize: 12)),
                        // ... inside lib/screens/ledger_transfer.dart (Management View Section)
                        ...state.batches.map((b) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Batch #${b.batchNo} (${b.jobName}):", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12)),
                                Text("Status: ${b.status}", style: TextStyle(color: b.status == 'OPEN' ? Colors.greenAccent : Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              const Text(
                "Route Batch Quantities Between Nodes",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
              ),
              const SizedBox(height: 8),
              
              Card(
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _batchNo,
                        hint: const Text("Select active tracking batch number..."),
                        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        items: visibleFormBatches.map((b) {
                          return DropdownMenuItem(value: b.batchNo, child: Text("Batch #${b.batchNo} - ${b.jobName}"));
                        }).toList(),
                        onChanged: (val) => setState(() => _batchNo = val),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _fromStage,
                        decoration: const InputDecoration(labelText: "Source Department Node", border: OutlineInputBorder()),
                        items: ["SMT", "Through hole", "Testing", "Packing", "Dispatched"].map((s) {
                          return DropdownMenuItem(value: s, child: Text(s));
                        }).toList(),
                        onChanged: (val) => setState(() => _fromStage = val!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _toStage,
                        decoration: const InputDecoration(labelText: "Destination Department Node", border: OutlineInputBorder()),
                        items: ["SMT", "Through hole", "Testing", "Packing", "Dispatched"].map((s) {
                          return DropdownMenuItem(value: s, child: Text(s));
                        }).toList(),
                        onChanged: (val) => setState(() => _toStage = val!),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Transfer Quantity (Units)", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _remarksController,
                        decoration: const InputDecoration(labelText: "Operational Signature / Remarks", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      _isSubmitting
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF008080)))
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF008080),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () async {
                                int qty = int.tryParse(_qtyController.text) ?? 0;
                                if (_batchNo == null || qty <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Please select a valid batch and positive quantity."))
                                  );
                                  return;
                                }
                                setState(() => _isSubmitting = true);
                                
                                String? err = await state.injectLedgerTransaction(
                                  batchNo: _batchNo!,
                                  fromStage: _fromStage,
                                  toStage: _toStage,
                                  qty: qty,
                                  operator: state.currentUser?.username ?? 'System',
                                  comments: _remarksController.text,
                                );
                                
                                setState(() => _isSubmitting = false);
                                if (err == null) {
                                  _qtyController.clear();
                                  _remarksController.clear();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Secure Ledger Node Entry Transferred Successfully!"), backgroundColor: Colors.green)
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error: $err"), backgroundColor: Colors.red)
                                  );
                                }
                              },
                              child: const Text("EMIT SECURE LEDGER ROUTE ENTRY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                    ],
                  ),
                ),
              ),
              
              const Divider(height: 40, thickness: 1.5),
              const Text(
                "📋 Operational Tracking Ledger Historical Blocks", 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))
              ),
              const SizedBox(height: 12),
              
              filteredLedger.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("No tracking ledger histories committed yet within your filter node context.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(), 
                      itemCount: filteredLedger.length,
                      itemBuilder: (context, idx) {
                        final ent = filteredLedger[idx];
                        String formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(ent.timestamp);
                        return Card(
                          color: Colors.white,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 0.5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Batch Code ID: #${ent.batchNo}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text("${ent.qtyTransferred} Units", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF008080))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text("Sequence Vector: ${ent.fromStage} ➔ ${ent.toStage}", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                if (ent.comments.isNotEmpty) Text("Comments: ${ent.comments}", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black54)),
                                const Divider(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Auth Signee: ${ent.operator}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text(formattedTime, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                )
                              ],
                            ),
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
