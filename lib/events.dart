import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class EventsPage extends StatefulWidget {
  final String currentUserRoll;

  const EventsPage({Key? key, required this.currentUserRoll}) : super(key: key);

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fabAnimationController;

  String _sortBy = 'date'; // 'date', 'votes'
  bool _ascending = true; // Always ascending for dates and votes
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scrollController.addListener(_handleScroll);
    _searchController.addListener(() {
      if (_searchController.text != _searchQuery) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_fabAnimationController.isCompleted) _fabAnimationController.reverse();
    } else {
      if (_fabAnimationController.isDismissed) _fabAnimationController.forward();
    }
  }

  Future<void> _updateVotes(String docId, bool isUpvote) async {
    try {
      final eventRef = FirebaseFirestore.instance.collection('events').doc(docId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(eventRef);
        if (!doc.exists) throw Exception('Event not found');

        final data = doc.data() as Map<String, dynamic>;
        final Map<String, int> votes = Map<String, int>.from(data['votes'] ?? {});
        final currentVote = votes[widget.currentUserRoll] ?? 0;

        // Only handle upvotes - toggle between 0 and 1
        if (isUpvote) {
          votes[widget.currentUserRoll] = (currentVote == 1) ? 0 : 1;
        }

        transaction.update(eventRef, {'votes': votes});
      });

      _showSnackBar('Vote updated successfully!', Icons.check_circle, Colors.teal.shade600);
    } catch (e) {
      _showSnackBar('Failed to update vote', Icons.error, Colors.red.shade600);
      print('Error updating vote: $e');
    }
  }

  int _calculateVoteCount(Map<String, dynamic>? votes) {
    if (votes == null) return 0;
    // Only count positive votes (upvotes)
    return votes.values.fold<int>(0, (sum, vote) => sum + (vote > 0 ? vote as int : 0));
  }

  /// Opens event link with proper URL handling and error management
  Future<void> _openEventLink(String url, String eventTitle) async {
    print('DEBUG: Attempting to open event link with URL: $url'); // Debug print
    if (url.isEmpty) {
      _showSnackBar('Event link is not available.', Icons.link_off, Colors.orange.shade700);
      print('DEBUG: Event link is empty or null.'); // Debug print
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
        _showSnackBar('Opening event link...', Icons.open_in_new, Colors.green.shade700);
      } else {
        print('DEBUG: canLaunchUrl returned false for: $uri. Check platform configuration or URL validity.'); // Debug print
        _showSnackBar('Could not open event link. Please check the URL.', Icons.error, Colors.red.shade700);
      }
    } on FormatException catch (e) {
      print('DEBUG: FormatException occurred for event link: $e, Original URL: $url'); // Debug print
      _showSnackBar('Invalid event link format. URL might be malformed.', Icons.error, Colors.red.shade700);
    } catch (e) {
      print('DEBUG: An unexpected error occurred while opening the event link: $e, Original URL: $url'); // Debug print
      _showSnackBar('An unexpected error occurred while opening the event link.', Icons.error, Colors.red.shade700);
    }
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [Icon(icon, color: Colors.white), const SizedBox(width: 8), Expanded(child: Text(message))]),
      backgroundColor: color,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(10),
    ));
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Events', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Date (Earliest First)'),
              value: 'date',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
              activeColor: Colors.teal.shade600, // UI Color Change
            ),
            RadioListTile<String>(
              title: const Text('Votes (Highest First)'),
              value: 'votes',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
              activeColor: Colors.teal.shade600, // UI Color Change
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Done', style: TextStyle(color: Colors.deepPurple.shade700)), // UI Color Change
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot> _sortEvents(List<QueryDocumentSnapshot> events) {
    events.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      int comparison = 0;
      switch (_sortBy) {
        case 'votes':
          final votesA = _calculateVoteCount(dataA['votes']);
          final votesB = _calculateVoteCount(dataB['votes']);
          comparison = votesB.compareTo(votesA); // Descending order (most votes first)
          break;
        default:
          final dateA = (dataA['date'] as Timestamp).toDate();
          final dateB = (dataB['date'] as Timestamp).toDate();
          comparison = dateA.compareTo(dateB); // Ascending order (earliest first)
          break;
      }
      return comparison; // Always ascending
    });
    return events;
  }

  List<QueryDocumentSnapshot> _filterEvents(List<QueryDocumentSnapshot> events) {
    if (_searchQuery.isEmpty) return events;
    final query = _searchQuery.toLowerCase();
    return events.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toString().toLowerCase();
      final subtitle = (data['subtitle'] ?? '').toString().toLowerCase();
      final place = (data['place'] ?? '').toString().toLowerCase();
      final description = (data['description'] ?? '').toString().toLowerCase();
      return title.contains(query) || subtitle.contains(query) || place.contains(query) || description.contains(query);
    }).toList();
  }

  /// Helper method to build action button for event link
  Widget _buildEventLinkButton({
    required String url,
    required String eventTitle,
  }) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.link, color: Colors.white, size: 20),
      label: const Text(
        'View Details',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
      ),
      onPressed: () => _openEventLink(url, eventTitle),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple.shade600, // UI Color Change
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 4,
        shadowColor: Colors.deepPurple.shade300.withOpacity(0.4), // UI Color Change
      ),
    );
  }

  Widget _buildEventCard(QueryDocumentSnapshot doc) {
    final event = doc.data() as Map<String, dynamic>;
    final eventId = doc.id;
    final dateTimestamp = event['date'] as Timestamp;
    final date = dateTimestamp.toDate();
    final formattedDate = DateFormat('MMM dd, yyyy').format(date);

    // Handle time formatting - check if start_time and end_time exist
    String formattedTime = '';
    if (event['start_time'] != null && event['end_time'] != null) {
      formattedTime = '${event['start_time']} - ${event['end_time']}';
    } else {
      // Fallback to date time if start/end times are not available
      formattedTime = DateFormat('hh:mm a').format(date);
    }

    final votes = Map<String, dynamic>.from(event['votes'] ?? {});
    final voteCount = _calculateVoteCount(votes);
    final userVote = votes[widget.currentUserRoll] ?? 0;

    final eventLink = event['link'] as String?;
    final hasEventLink = eventLink != null && eventLink.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50, // UI Color Change
              border: Border(bottom: BorderSide(color: Colors.deepPurple.shade100, width: 0.5)), // UI Color Change
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title'] ?? 'Untitled Event',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700, // UI Color Change
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (event['subtitle'] != null && (event['subtitle'] as String).isNotEmpty)
                  Text(
                    event['subtitle'],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.deepPurple.shade600), // UI Color Change
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 16, color: Colors.deepPurple.shade600), // UI Color Change
                    const SizedBox(width: 8),
                    Text(formattedDate, style: TextStyle(color: Colors.deepPurple.shade600)), // UI Color Change
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 16, color: Colors.deepPurple.shade600), // UI Color Change
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formattedTime,
                        style: TextStyle(color: Colors.deepPurple.shade600), // UI Color Change
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: Colors.deepPurple.shade600), // UI Color Change
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event['place'] ?? 'No location specified',
                        style: TextStyle(color: Colors.deepPurple.shade600), // UI Color Change
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Show link preview if available
                if (hasEventLink) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.link, size: 16, color: Colors.deepPurple.shade600), // UI Color Change
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          eventLink!,
                          style: TextStyle(
                            color: Colors.deepPurple.shade600, // UI Color Change
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Event link button (if available)
                if (hasEventLink) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildEventLinkButton(
                          url: eventLink!,
                          eventTitle: event['title'] ?? 'Event',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                // Voting section
                Row(
                  children: [
                    Tooltip(
                      message: userVote == 1 ? 'Remove Like' : 'Like',
                      child: IconButton(
                        icon: Icon(
                          Icons.thumb_up_rounded,
                          color: userVote == 1 ? Colors.teal.shade600 : Colors.grey.shade400, // UI Color Change
                          size: 26,
                        ),
                        onPressed: () => _updateVotes(doc.id, true),
                        splashRadius: 24,
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: voteCount > 0 ? Colors.teal.shade100 : Colors.grey.shade100, // UI Color Change
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: voteCount > 0 ? Colors.teal.shade300 : Colors.grey.shade300, // UI Color Change
                        ),
                      ),
                      child: Text(
                        voteCount.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: voteCount > 0 ? Colors.teal.shade700 : Colors.grey.shade700, // UI Color Change
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple.shade700, // UI Color Change
        foregroundColor: Colors.white, // UI Color Change
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortDialog,
            tooltip: 'Sort Events',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
              _showSnackBar('Refreshing events...', Icons.refresh, Colors.deepPurple.shade700); // UI Color Change
            },
            tooltip: 'Refresh Events',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.shade700, // UI Color Change
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search events...',
                hintStyle: TextStyle(color: Colors.deepPurple.shade200), // UI Color Change
                prefixIcon: Icon(Icons.search, color: Colors.deepPurple.shade200), // UI Color Change
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.deepPurple.shade200), // UI Color Change
                  onPressed: () {
                    _searchController.clear();
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white, // UI Color Change
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('events').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                List<QueryDocumentSnapshot> events = snapshot.data!.docs;
                events = _filterEvents(events);
                events = _sortEvents(events);

                if (events.isEmpty) {
                  return Center(
                      child: Text(
                        _searchQuery.isNotEmpty ? 'No matching events found.' : 'No events available yet.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16), // UI Color Change
                      ));
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: events.length,
                  itemBuilder: (context, index) => _buildEventCard(events[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimationController,
        child: FloatingActionButton(
          onPressed: () {
            _showSnackBar('Add new event functionality coming soon!', Icons.add_circle, Colors.deepPurple.shade700); // UI Color Change
          },
          backgroundColor: Colors.deepPurple.shade700, // UI Color Change
          foregroundColor: Colors.white, // UI Color Change
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}