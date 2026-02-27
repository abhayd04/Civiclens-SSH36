import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  
  void _updateStatus(String docId, String newStatus) {
    FirebaseFirestore.instance.collection('reports').doc(docId).update({
      'status': newStatus,
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ticket Status Updated to $newStatus"), backgroundColor: Colors.green));
  }

  Color _getSeverityColor(String severity) {
    if (severity.toUpperCase().contains('HIGH')) return Colors.red;
    if (severity.toUpperCase().contains('MEDIUM')) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101828),
        title: Text("Municipal Corp | Admin Portal", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: TextButton.icon(
              onPressed: () => AuthService().signOut(),
              icon: const Icon(Icons.logout, color: Colors.white70),
              label: const Text("Logout", style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
      body: Row(
        children: [
          // SIDEBAR
          Container(
            width: 250,
            color: Colors.white,
            child: Column(
              children: [
                const SizedBox(height: 30),
                const CircleAvatar(radius: 40, backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.admin_panel_settings, size: 40, color: Color(0xFF101828))),
                const SizedBox(height: 15),
                Text("Chief Engineer", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text("Central Command", style: TextStyle(color: Colors.grey)),
                const Divider(height: 50),
                ListTile(leading: const Icon(Icons.dashboard, color: Color(0xFF101828)), title: Text("Live Map", style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                ListTile(leading: const Icon(Icons.assignment, color: Colors.grey), title: Text("All Tickets", style: GoogleFonts.poppins())),
                ListTile(leading: const Icon(Icons.people, color: Colors.grey), title: Text("Contractors", style: GoogleFonts.poppins())),
              ],
            ),
          ),
          
          // MAIN CONTENT AREA
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("AI-Triage Live Feed", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // STATS ROW
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('reports').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      int total = snapshot.data!.docs.length;
                      int pending = snapshot.data!.docs.where((d) => (d.data() as Map)['status'] == 'Pending').length;
                      int resolved = snapshot.data!.docs.where((d) => (d.data() as Map)['status'] == 'Fixed').length;
                      
                      return Row(
                        children: [
                          _statCard("Total Reports", total.toString(), Colors.blue),
                          const SizedBox(width: 20),
                          _statCard("Action Required", pending.toString(), Colors.red),
                          const SizedBox(width: 20),
                          _statCard("AI Verified Fixed", resolved.toString(), Colors.green),
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: 30),
                  Text("Recent Tickets", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),

                  // REPORTS LIST
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('reports').orderBy('timestamp', descending: true).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        
                        var docs = snapshot.data!.docs;
                        if (docs.isEmpty) return const Text("No active reports.");

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            var data = docs[index].data() as Map<String, dynamic>;
                            String status = data['status'] ?? 'Pending';
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 15),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(20),
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: _getSeverityColor(data['severity'] ?? '').withOpacity(0.1), shape: BoxShape.circle),
                                  child: Icon(Icons.warning_rounded, color: _getSeverityColor(data['severity'] ?? '')),
                                ),
                                title: Text(data['description'] ?? "Issue", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 5),
                                    Text("📍 ${data['location'] ?? 'Unknown'} | Dept: ${data['dept'] ?? 'General'}"),
                                    const SizedBox(height: 5),
                                    Text("Impact Score: ${data['votes'] ?? 1} Citizens Affected", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                trailing: status == 'Fixed' 
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20)),
                                      child: const Text("AI VERIFIED", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                    )
                                  : PopupMenuButton<String>(
                                      onSelected: (val) => _updateStatus(docs[index].id, val),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                        decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange)),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(status, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                            const Icon(Icons.arrow_drop_down, color: Colors.orange),
                                          ],
                                        ),
                                      ),
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: "In Progress", child: Text("Mark In Progress")),
                                        const PopupMenuItem(value: "Fixed", child: Text("Force Close (Override AI)")),
                                      ],
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _statCard(String title, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(count, style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}