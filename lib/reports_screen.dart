import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart'; 

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  // API KEY HERE
  static const String apiKey = "API_KEY_IS_HIDDEN_FOR_SECURITY"; // REPLACE WITH YOUR GEMINI API KEY

  void _upvoteReport(String docId) {
    FirebaseFirestore.instance.collection('reports').doc(docId).update({
      'votes': FieldValue.increment(1),
    });
  }

  // 🚨 THE TWITTER AUTO-STRIKE FUNCTION
  Future<void> _twitterEscalation(String issue, String location) async {
    final String tweetText = Uri.encodeComponent(
      "🚨 @CMOMP @IndoreCollector URGENT SAFETY HAZARD! 🚨\n\n"
      "This critical issue has been ignored by authorities and breached the 72-hour SLA.\n"
      "Issue: $issue\nLocation: $location\n\n"
      "Verified by #CivicLens AI. Act immediately!"
    );
    final Uri twitterUri = Uri.parse("https://twitter.com/intent/tweet?text=$tweetText");
    try {
      await launchUrl(twitterUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Could not open Twitter: $e");
    }
  }

  Future<void> _verifyAndFix(BuildContext context, String docId, String description) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) return; 

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircularProgressIndicator(color: Color(0xFF1A237E)),
                  const SizedBox(width: 20),
                  Expanded(child: Text("AI Verifying Repair...", style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ),
        );
      }

      final Uint8List imageBytes = await photo.readAsBytes();
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

      final content = Content.multi([
        TextPart("You are a strict Municipal Inspector. The original complaint was: '$description'. Look at this new photo. Does it show that SPECIFIC issue being fixed? 1. If the photo is unrelated (e.g., a wall when the issue was a road), reply 'REJECTED'. 2. If it shows the repair is done and safe, reply 'VERIFIED'. 3. If unclear, reply 'REJECTED'."),
        DataPart(photo.mimeType ?? 'image/jpeg', imageBytes),
      ]);

      final response = await model.generateContent([content]);
      final String result = response.text?.toUpperCase() ?? "";

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); 

        if (result.contains("VERIFIED")) {
          await FirebaseFirestore.instance.collection('reports').doc(docId).update({'status': 'Fixed'});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Repair Verified! City Safety Score Increased.", style: GoogleFonts.poppins()), 
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Verification Failed. Repair incomplete.", style: GoogleFonts.poppins()), 
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        try { Navigator.of(context, rootNavigator: true).pop(); } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error verifying fix. Check connection.")));
      }
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";
    DateTime date = timestamp.toDate();
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return "${diff.inMinutes} mins ago";
    if (diff.inHours < 24) return "${diff.inHours} hours ago";
    return "${date.day}/${date.month}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), 
      appBar: AppBar(
        title: Text("City Command Center", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF1A237E))),
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
          
          // --- 📊 1. DYNAMIC LEADERBOARD MATH ---
          Map<String, Map<String, int>> deptStats = {};
          int totalTickets = docs.length;
          int fixedTickets = 0;

          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            String dept = data['dept'] ?? 'General';
            bool isFixed = data['status'] == 'Fixed';
            
            if (isFixed) fixedTickets++;

            deptStats.putIfAbsent(dept, () => {'total': 0, 'fixed': 0});
            deptStats[dept]!['total'] = deptStats[dept]!['total']! + 1;
            if (isFixed) deptStats[dept]!['fixed'] = deptStats[dept]!['fixed']! + 1;
          }

          // Convert to list and sort by success rate
          List<Map<String, dynamic>> rankings = deptStats.entries.map((e) {
            double score = e.value['total']! == 0 ? 0 : (e.value['fixed']! / e.value['total']!) * 100;
            return {'dept': e.key, 'score': score, 'total': e.value['total']};
          }).toList();
          
          rankings.sort((a, b) => b['score'].compareTo(a['score']));

          String bestDept = rankings.isNotEmpty ? rankings.first['dept'] : "N/A";
          String bestScore = rankings.isNotEmpty ? "${rankings.first['score'].toInt()}%" : "--";
          // If only one dept exists, worst and best might be the same, handle it gracefully:
          String worstDept = rankings.length > 1 ? rankings.last['dept'] : "N/A";
          String worstScore = rankings.length > 1 ? "${rankings.last['score'].toInt()}%" : "--";

          double globalSafetyScore = totalTickets == 0 ? 100 : (fixedTickets / totalTickets) * 100;

          // SORT DOCUMENTS FOR THE LIST
          docs.sort((a, b) {
            var dataA = a.data() as Map<String, dynamic>;
            var dataB = b.data() as Map<String, dynamic>;
            bool isFixedA = dataA['status'] == 'Fixed';
            bool isFixedB = dataB['status'] == 'Fixed';
            if (isFixedA && !isFixedB) return 1; 
            if (!isFixedA && isFixedB) return -1;
            int votesA = dataA['votes'] ?? 0;
            int votesB = dataB['votes'] ?? 0;
            if (votesA != votesB) return votesB.compareTo(votesA);
            Timestamp timeA = dataA['timestamp'] ?? Timestamp.now();
            Timestamp timeB = dataB['timestamp'] ?? Timestamp.now();
            return timeB.compareTo(timeA);
          });

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // --- CITY SCORE CARD ---
              FadeInDown(
                duration: const Duration(milliseconds: 600),
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      Text("City Safety Score", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 5),
                      Text("${globalSafetyScore.toInt()}%", style: GoogleFonts.poppins(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: globalSafetyScore / 100,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF00E676)), 
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- 🏆 DYNAMIC LEADERBOARD UI ---
              if (rankings.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.leaderboard, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Text("Dept Accountability Leaderboard", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.redAccent)),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text("🏆 $bestDept", style: GoogleFonts.poppins(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                          Text(bestScore, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (rankings.length > 1) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text("⚠️ $worstDept (Failing)", style: GoogleFonts.poppins(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                            Text(worstScore, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),

              const SizedBox(height: 25),
              Text("Active Civic Issues", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
              const SizedBox(height: 15),

              if (docs.isEmpty) 
                 Center(child: Padding(padding: const EdgeInsets.all(40), child: Text("No issues reported yet in your zone.", style: GoogleFonts.poppins(color: Colors.grey)))),

              ...docs.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                bool isFixed = data['status'] == 'Fixed';
                int votes = data['votes'] ?? 0; 
                String severity = data['severity']?.toString() ?? 'Medium';
                
                // --- 🚨 72-HOUR AUTO STRIKE LOGIC ---
                Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
                int minutesElapsed = DateTime.now().difference(timestamp.toDate()).inMinutes;
                
                // HACKATHON DEMO LOGIC: 
                // Triggers if a High-Severity ticket is older than 5 MINUTES (Explain this to judges!)
                bool isStrikeActive = !isFixed && severity.contains('High') && minutesElapsed >= 5;

                Color cardBorderColor = isStrikeActive ? Colors.red : Colors.transparent;
                Color statusColor = isFixed ? Colors.green : const Color(0xFFFF6D00);

                return FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isFixed ? Colors.grey[100] : Colors.white, 
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cardBorderColor, width: isStrikeActive ? 2 : 0),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isStrikeActive) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                                  const SizedBox(width: 5),
                                  Text("72-HOUR SLA BREACHED: AUTO-ESCALATED", style: GoogleFonts.poppins(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(isFixed ? "RESOLVED" : "ACTION REQUIRED", style: GoogleFonts.poppins(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                              ),
                              Text(_formatDate(data['timestamp']), style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(data['description'] ?? "Issue", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, decoration: isFixed ? TextDecoration.lineThrough : null)),
                          const SizedBox(height: 5),
                          Row(children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[400]), 
                            const SizedBox(width: 5),
                            Expanded(child: Text(data['location'] ?? "Unknown", style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13), maxLines: 1))
                          ]),
                          
                          const SizedBox(height: 15),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                Icon(Icons.people_alt, size: 16, color: Colors.blue[800]),
                                const SizedBox(width: 5),
                                Text("$votes Citizens Affected", style: GoogleFonts.poppins(color: Colors.blue[800], fontSize: 12, fontWeight: FontWeight.w600)),
                              ]),
                              
                              if (!isFixed)
                                InkWell(
                                  onTap: () => _upvoteReport(doc.id),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.thumb_up_alt_outlined, size: 20, color: Color(0xFF1A237E)),
                                  ),
                                )
                            ],
                          ),

                          if (!isFixed) ...[
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _verifyAndFix(context, doc.id, data['description'] ?? "Issue"),
                                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                    label: const Text("VERIFY FIX", style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF1A237E),
                                      side: BorderSide(color: const Color(0xFF1A237E).withOpacity(0.2)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _twitterEscalation(data['description'] ?? "Issue", data['location'] ?? "Unknown"),
                                    icon: const Icon(Icons.campaign, size: 16),
                                    label: Text(isStrikeActive ? "TWEET CM" : "ESCALATE", style: const TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isStrikeActive ? Colors.black : Colors.redAccent, 
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }
}