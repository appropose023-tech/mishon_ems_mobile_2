import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class ClientOperationalTrackingConsole extends StatefulWidget {
  const ClientOperationalTrackingConsole({Key? key}) : super(key: key);

  @override
  State<ClientOperationalTrackingConsole> createState() => _ClientOperationalTrackingConsoleState();
}

class _ClientOperationalTrackingConsoleState extends State<ClientOperationalTrackingConsole> {
  String? _selectedBatchCode;
  Map<String, dynamic>? _projectDetailsMatrix;
  bool _isFetchingMatrix = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Client Job Tracking Console"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              state.clearSession();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Select Project Reference Batch Token", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004d4d))),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedBatchCode,
                        hint: const Text("Choose Batch Reference Code"),
                        items: state.batches.map((b) {
                          return DropdownMenuItem<String>(
                            value: b.batchNo,
                            child: Text("Batch #${b.batchNo} [${b.jobName}]"),
                          );
                        }).toList(),
                        onChanged: (val) async {
                          if (val == null) return;
                          setState(() {
                            _selectedBatchCode = val;
                            _isFetchingMatrix = true;
                          });
                          final res = await state.fetchClientProjectView(val);
                          setState(() {
                            _projectDetailsMatrix = res;
                            _isFetchingMatrix = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_isFetchingMatrix)
                const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008080)))),
              if (!_isFetchingMatrix && _projectDetailsMatrix != null) ...[
                Text("Project Logistics Metrics Profile: #${_projectDetailsMatrix!['batch_no']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
                const SizedBox(height: 10),
                _buildMetricsCard("Client Reference Title", _projectDetailsMatrix!['client_name'].toString(), Icons.business),
                _buildMetricsCard("Registered Job Nomenclature", _projectDetailsMatrix!['job_name'].toString(), Icons.assignment),
                _buildMetricsCard("Active Pipeline Job Status", _projectDetailsMatrix!['status'].toString(), Icons.info_outline),
                _buildMetricsCard("Latest Production Milestone Update", _projectDetailsMatrix!['last_update_date'].toString(), Icons.access_time),
                const Divider(height: 30, thickness: 1),
                const Text("Current Floor Quantities In Progress (Stage Aggregations)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
                const SizedBox(height: 10),
                _buildMetricsCard("Total Quantities at SMT Production", "${_projectDetailsMatrix!['qty_at_smt_production']} Units", Icons.precision_manufacturing),
                _buildMetricsCard("Total Quantities at Through Hole Production", "${_projectDetailsMatrix!['qty_at_through_hole_production']} Units", Icons.hardware),
                _buildMetricsCard("Total Quantities at SMT Quality Line", "${_projectDetailsMatrix!['qty_at_smt_quality']} Units", Icons.verified),
                _buildMetricsCard("Total Quantities at Through Hole Quality Line", "${_projectDetailsMatrix!['qty_at_through_hole_quality']} Units", Icons.fact_check),
                _buildMetricsCard("Total Quantities Dispatched / At Packaging Terminal", "${_projectDetailsMatrix!['qty_at_dispatch']} Units", Icons.local_shipping),
              ] else if (!_isFetchingMatrix && _selectedBatchCode != null)
                const Padding(
                  padding: EdgeInsets.only(top: 40.0),
                  child: Text("Unable to parse pipeline attributes for this tracking assignment code.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsCard(String title, String dataContent, IconData analyticalIcon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.white,
      child: ListTile(
        leading: Icon(analyticalIcon, color: const Color(0xFF008080)),
        title: Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
        subtitle: Text(dataContent, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
    );
  }
}
