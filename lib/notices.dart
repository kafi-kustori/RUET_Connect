import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class NoticesPage extends StatelessWidget {
  const NoticesPage({Key? key}) : super(key: key);

  // Utility method to format date nicely
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Get color based on notice type
  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'urgent':
        return Colors.redAccent.shade700;
      case 'important':
        return Colors.deepOrangeAccent.shade700;
      case 'event':
        return Colors.teal.shade600;
      case 'announcement':
        return Colors.indigo.shade600;
      default:
        return Colors.blueGrey.shade400;
    }
  }

  // Get icon based on notice type
  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'urgent':
        return Icons.priority_high;
      case 'important':
        return Icons.star;
      case 'event':
        return Icons.event;
      case 'announcement':
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }

  /// Opens a given URL in an external application with better error handling.
  Future<void> _openLink(BuildContext context, String url, String linkType) async {
    print('DEBUG: Attempting to open $linkType with URL: $url'); // Debug print
    if (url.isEmpty) {
      _showSnackBar(context, '$linkType link is not available.', Colors.orange.shade700);
      print('DEBUG: $linkType link is empty or null.'); // Debug print
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
        _showSnackBar(context, 'Opening $linkType...', Colors.green.shade700);
      } else {
        print('DEBUG: canLaunchUrl returned false for: $uri. Check platform configuration (AndroidManifest/Info.plist) or URL validity.'); // Debug print
        _showSnackBar(context, 'Could not open $linkType. Please check the URL and ensure the required app is installed.', Colors.red.shade700);
      }
    } on FormatException catch (e) {
      print('DEBUG: FormatException occurred for $linkType: $e, Original URL: $url'); // Debug print
      _showSnackBar(context, 'Invalid $linkType format. URL might be malformed.', Colors.red.shade700);
    } catch (e) {
      print('DEBUG: An unexpected error occurred while opening the $linkType: $e, Original URL: $url'); // Debug print
      _showSnackBar(context, 'An unexpected error occurred while opening the $linkType.', Colors.red.shade700);
    }
  }

  /// Displays a customized SnackBar message.
  void _showSnackBar(BuildContext context, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // Show notice details in a modal bottom sheet
  void _showNoticeDetails(BuildContext context, Map<String, dynamic> notice, DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                notice['title'] ?? 'Untitled Notice',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Posted on ${_formatDate(date)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              if (notice['description'] != null)
                Text(
                  notice['description'],
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              const SizedBox(height: 20),
              // Add link button in the modal if link exists
              if (notice['notice_link'] != null && (notice['notice_link'] as String).trim().isNotEmpty)
                _buildLinkButton(
                  context: context,
                  url: notice['notice_link'],
                  label: 'View Full Post',
                  icon: Icons.open_in_new,
                  color: Colors.blue.shade700,
                ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build link button
  Widget _buildLinkButton({
    required BuildContext context,
    required String url,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        onPressed: () => _openLink(context, url, 'Notice Link'),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 4,
          shadowColor: color.withOpacity(0.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Notices', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('notices').orderBy('date', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  const Text('Error loading notices', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading notices...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final notices = snapshot.data!.docs;

          if (notices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No notices found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: notices.length,
              itemBuilder: (context, index) {
                final notice = notices[index].data() as Map<String, dynamic>;
                final Timestamp? dateTimestamp = notice['date'];
                final date = dateTimestamp?.toDate() ?? DateTime.now();
                final type = notice['type'] ?? 'General';
                final hasLink = notice['notice_link'] != null && (notice['notice_link'] as String).trim().isNotEmpty;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: _getTypeColor(type),
                      child: Icon(_getTypeIcon(type), color: Colors.white, size: 20),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            notice['title'] ?? 'Untitled Notice',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasLink)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.link,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getTypeColor(type).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            type.toUpperCase(),
                            style: TextStyle(
                              color: _getTypeColor(type),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[700]),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(date),
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            ),
                            if (hasLink) ...[
                              const Spacer(),
                              GestureDetector(
                                onTap: () => _openLink(context, notice['notice_link'], 'Notice Link'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade600,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.open_in_new, size: 12, color: Colors.white),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'View',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showNoticeDetails(context, notice, date),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}