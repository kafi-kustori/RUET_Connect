import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // Ensure this is imported

class WorkshopsPage extends StatefulWidget {
  final String currentUserRoll; // Pass logged-in user's roll/ID

  const WorkshopsPage({Key? key, required this.currentUserRoll})
      : super(key: key);

  @override
  State<WorkshopsPage> createState() => _WorkshopsPageState();
}

class _WorkshopsPageState extends State<WorkshopsPage> {
  Future<void> _toggleUpvote(String workshopId, Map<String, dynamic> upvotes) async {
    final userId = widget.currentUserRoll;
    final docRef = FirebaseFirestore.instance.collection('workshops').doc(workshopId);

    // Create a new map to avoid modifying the original during async operations
    final Map<String, dynamic> newUpvotes = Map.from(upvotes);

    if (newUpvotes.containsKey(userId)) {
      // Remove upvote
      newUpvotes.remove(userId);
    } else {
      // Add upvote
      newUpvotes[userId] = true;
    }

    try {
      await docRef.update({'upvotes': newUpvotes});
      _showSnackBar('Vote updated!', Icons.check_circle, Colors.teal);
    } catch (e) {
      _showSnackBar('Failed to update vote', Icons.error, Colors.redAccent);
      print('Error updating upvote: $e'); // For debugging
    }
  }

  /// Opens workshop link with proper URL handling and error management
  Future<void> _openWorkshopLink(String url, String workshopTitle) async {
    print('DEBUG: Attempting to open workshop link with URL: $url'); // Debug print
    if (url.isEmpty) {
      _showSnackBar('Workshop link is not available.', Icons.link_off, Colors.orange.shade700);
      print('DEBUG: Workshop link is empty or null.'); // Debug print
      return;
    }

    try {
      // Trim whitespace and process URL to ensure proper protocol
      String processedUrl = url.trim();
      if (!processedUrl.startsWith('http://') && !processedUrl.startsWith('https://')) {
        processedUrl = 'https://$processedUrl';
        print('DEBUG: Prepending https:// to URL. Processed URL: $processedUrl'); // Debug print
      }

      final uri = Uri.parse(processedUrl);
      print('DEBUG: Parsed URI: $uri'); // Debug print

      if (await canLaunchUrl(uri)) {
        print('DEBUG: canLaunchUrl returned true for: $uri. Attempting to launch.'); // Debug print
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSnackBar('Opening workshop link...', Icons.open_in_new, Colors.green.shade700);
      } else {
        print('DEBUG: canLaunchUrl returned false for: $uri. Check platform configuration or URL validity.'); // Debug print
        _showSnackBar('Could not open workshop link. Please check the URL.', Icons.error, Colors.red.shade700);
      }
    } on FormatException catch (e) {
      print('DEBUG: FormatException occurred for workshop link: $e, Original URL: $url'); // Debug print
      _showSnackBar('Invalid workshop link format. URL might be malformed.', Icons.error, Colors.red.shade700);
    } catch (e) {
      print('DEBUG: An unexpected error occurred while opening the workshop link: $e, Original URL: $url'); // Debug print
      _showSnackBar('An unexpected error occurred while opening the workshop link.', Icons.error, Colors.red.shade700);
    }
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return; // Prevent showing snackbar if widget is disposed
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [Icon(icon, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(message))]),
      backgroundColor: color,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(10),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workshops', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workshops')
            .orderBy('date', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading workshops: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final workshops = snapshot.data!.docs;
          if (workshops.isEmpty) {
            return Center(child: Text('No workshops found.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)));
          }
          return ListView.builder(
            itemCount: workshops.length,
            itemBuilder: (context, index) {
              final doc = workshops[index];
              final workshop = doc.data() as Map<String, dynamic>;
              final Timestamp? dateTimestamp = workshop['date'];
              final date = dateTimestamp != null
                  ? dateTimestamp.toDate()
                  : DateTime.now(); // Fallback if date is missing

              final upvotes = Map<String, dynamic>.from(workshop['upvotes'] ?? {});
              final totalUpvotes = upvotes.length;
              final userHasUpvoted = upvotes.containsKey(widget.currentUserRoll);

              // *** FIXED: Now check for the generic 'link' field from Admin Panel ***
              final workshopLink = workshop['link'] as String?;
              final hasWorkshopLink = workshopLink != null && workshopLink.trim().isNotEmpty;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(20.0), // Increased padding for better aesthetics
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workshop['title'] ?? 'Untitled Workshop',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (workshop['subtitle'] != null && (workshop['subtitle'] as String).isNotEmpty)
                        Text(
                          workshop['subtitle'],
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.deepPurple.shade600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 16, color: Colors.deepPurple.shade600),
                          const SizedBox(width: 8),
                          Text("Date: ${date.toLocal().toString().split(' ')[0]}",
                              style: TextStyle(color: Colors.deepPurple.shade600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Display workshop link if available
                      if (hasWorkshopLink) ...[
                        Row(
                          children: [
                            Icon(Icons.link, size: 16, color: Colors.deepPurple.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                workshopLink!,
                                style: TextStyle(
                                  color: Colors.deepPurple.shade600,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        workshop['details'] ?? 'No details available.',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      ),
                      const SizedBox(height: 15),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Upvote Section
                          Row(
                            children: [
                              Tooltip(
                                message: userHasUpvoted ? 'Remove Upvote' : 'Upvote',
                                child: IconButton(
                                  icon: Icon(
                                    userHasUpvoted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                                    color: userHasUpvoted ? Colors.teal.shade600 : Colors.grey.shade400,
                                    size: 26,
                                  ),
                                  onPressed: () => _toggleUpvote(doc.id, upvotes),
                                  splashRadius: 24,
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: totalUpvotes > 0 ? Colors.teal.shade100 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: totalUpvotes > 0 ? Colors.teal.shade300 : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  totalUpvotes.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: totalUpvotes > 0 ? Colors.teal.shade700 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Register Button
                          // *** FIXED: Use workshopLink and hasWorkshopLink ***
                          if (hasWorkshopLink)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.app_registration, color: Colors.white, size: 20),
                              label: const Text(
                                'Register',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                              onPressed: () => _openWorkshopLink(workshopLink!, workshop['title'] ?? 'Workshop'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 4,
                                shadowColor: Colors.deepPurple.shade300.withOpacity(0.4),
                              ),
                            )
                          else
                            Tooltip(
                              message: "No registration link available for this workshop.",
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.link_off, color: Colors.grey, size: 20),
                                label: const Text(
                                  'No Link',
                                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                                onPressed: null, // Disable the button
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade200,
                                  foregroundColor: Colors.grey.shade600,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  elevation: 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
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