import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text("City Accountability Rankings", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF1A237E), fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1A237E)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reports').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var docs = snapshot.data!.docs.toList();
          
          // --- 📊 THE COMPLEX GROUPING MATH ---
          // Structure: { "Ward 1": { "Total": 10, "Fixed": 5, "Depts": { "Roads": { "Total": 5, "Fixed": 2 } } } }
          Map<String, Map<String, dynamic>> wardStats = {};

          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            String ward = data['ward'] ?? 'Ward 1';
            String dept = data['dept'] ?? 'General';
            bool isFixed = data['status'] == 'Fixed';

            // Initialize Ward if not exists
            wardStats.putIfAbsent(ward, () => {'total': 0, 'fixed': 0, 'depts': <String, Map<String, int>>{}});
            
            // Update Ward totals
            wardStats[ward]!['total']++;
            if (isFixed) wardStats[ward]!['fixed']++;

            // Initialize Dept inside Ward if not exists
            Map<String, Map<String, int>> depts = wardStats[ward]!['depts'];
            depts.putIfAbsent(dept, () => {'total': 0, 'fixed': 0});
            
            // Update Dept totals
            depts[dept]!['total'] = depts[dept]!['total']! + 1;
            if (isFixed) depts[dept]!['fixed'] = depts[dept]!['fixed']! + 1;
          }

          // Convert to List and Sort Wards by Score (Highest to Lowest)
          List<Map<String, dynamic>> sortedWards = wardStats.entries.map((e) {
            double score = e.value['total'] == 0 ? 0 : (e.value['fixed'] / e.value['total']) * 100;
            return {
              'ward': e.key,
              'score': score,
              'total': e.value['total'],
              'fixed': e.value['fixed'],
              'depts': e.value['depts'],
            };
          }).toList();

          sortedWards.sort((a, b) => b['score'].compareTo(a['score']));

          if (sortedWards.isEmpty) {
            return Center(child: Text("No data available yet.", style: GoogleFonts.poppins(color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: sortedWards.length,
            itemBuilder: (context, index) {
              var wardData = sortedWards[index];
              String wardName = wardData['ward'];
              double wardScore = wardData['score'];
              Color scoreColor = _getScoreColor(wardScore);
              
              // Sort departments within this ward
              Map<String, Map<String, int>> depts = wardData['depts'];
              List<Map<String, dynamic>> sortedDepts = depts.entries.map((e) {
                double dScore = e.value['total']! == 0 ? 0 : (e.value['fixed']! / e.value['total']!) * 100;
                return {'dept': e.key, 'score': dScore, 'total': e.value['total'], 'fixed': e.value['fixed']};
              }).toList();
              sortedDepts.sort((a, b) => b['score'].compareTo(a['score']));

              return FadeInUp(
                duration: Duration(milliseconds: 400 + (index * 100)),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 2,
                  shadowColor: Colors.black12,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent), // Removes borders
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: CircleAvatar(
                        backgroundColor: scoreColor.withOpacity(0.1),
                        child: Text("#${index + 1}", style: GoogleFonts.poppins(color: scoreColor, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(wardName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text("${wardData['fixed']}/${wardData['total']} Issues Resolved", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: scoreColor, borderRadius: BorderRadius.circular(20)),
                        child: Text("${wardScore.toInt()}%", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("DEPARTMENT BREAKDOWN", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1)),
                              const SizedBox(height: 10),
                              ...sortedDepts.map((d) {
                                double dScore = d['score'];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(d['dept'], style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500))),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: LinearProgressIndicator(
                                            value: dScore / 100,
                                            backgroundColor: Colors.grey[200],
                                            valueColor: AlwaysStoppedAnimation(_getScoreColor(dScore)),
                                            minHeight: 6,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 15),
                                      SizedBox(
                                        width: 40,
                                        child: Text("${dScore.toInt()}%", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: _getScoreColor(dScore)), textAlign: TextAlign.right),
                                      )
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}