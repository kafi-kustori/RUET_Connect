import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ClubsPage extends StatefulWidget {
  final String? currentUserId; // Accept user ID as parameter

  const ClubsPage({Key? key, this.currentUserId}) : super(key: key);

  @override
  State<ClubsPage> createState() => _ClubsPageState();
}

class _ClubsPageState extends State<ClubsPage> {
  late final String currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'upvotes_desc'; // Default sort option: Most Upvotes
  // Removed _isLoading as it was not being used.

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUserId ?? "2203014"; // Fallback if not provided
    // Listen to search controller for real-time filtering
    _searchController.addListener(() {
      if (_searchController.text.toLowerCase() != _searchQuery) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Handles voting/unvoting for a club with optimistic updates and error handling.
  Future<void> _voteClub(String clubId, String clubName) async {
    try {
      final clubRef = FirebaseFirestore.instance.collection('clubs').doc(clubId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(clubRef);
        // Ensure club exists before proceeding
        if (!snapshot.exists) {
          throw Exception("Club does not exist!");
        }

        final clubData = snapshot.data() as Map<String, dynamic>;
        // Ensure voted_users is a list of strings
        final votedUsers = List<String>.from(clubData['voted_users'] ?? []);
        final currentVotes = (clubData['upvotes'] ?? 0) as int;

        if (votedUsers.contains(currentUser)) {
          // User has already voted, so unvote
          votedUsers.remove(currentUser);
          final newVotes = (currentVotes - 1).clamp(0, double.infinity).toInt(); // Ensure votes don't go negative
          transaction.update(clubRef, {
            'upvotes': newVotes,
            'voted_users': votedUsers,
          });
          _showSnackBar('Vote removed from $clubName', Colors.orange.shade700);
        } else {
          // User has not voted, so vote
          votedUsers.add(currentUser);
          final newVotes = currentVotes + 1;
          transaction.update(clubRef, {
            'upvotes': newVotes,
            'voted_users': votedUsers,
          });
          _showSnackBar('You upvoted $clubName', Colors.blue.shade700);
        }
      });
    } catch (e) {
      _showSnackBar('Failed to vote. Please try again.', Colors.red.shade700);
      print('Error voting: $e'); // For debugging purposes
    }
  }

  /// Opens a given URL in an external application with better error handling.
  Future<void> _openLink(String url, String linkType) async {
    print('DEBUG: Attempting to open $linkType with URL: $url'); // Debug print
    if (url.isEmpty) {
      _showSnackBar('$linkType link is not available.', Colors.orange.shade700);
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
        _showSnackBar('Opening $linkType...', Colors.green.shade700);
      } else {
        print('DEBUG: canLaunchUrl returned false for: $uri. Check platform configuration (AndroidManifest/Info.plist) or URL validity.'); // Debug print
        _showSnackBar('Could not open $linkType. Please check the URL and ensure the required app is installed.', Colors.red.shade700);
      }
    } on FormatException catch (e) {
      print('DEBUG: FormatException occurred for $linkType: $e, Original URL: $url'); // Debug print
      _showSnackBar('Invalid $linkType format. URL might be malformed.', Colors.red.shade700);
    } catch (e) {
      print('DEBUG: An unexpected error occurred while opening the $linkType: $e, Original URL: $url'); // Debug print
      _showSnackBar('An unexpected error occurred while opening the $linkType.', Colors.red.shade700);
    }
  }

  /// Displays a customized SnackBar message.
  void _showSnackBar(String message, Color backgroundColor) {
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

  /// Builds the search bar widget.
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.shade50.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search clubs...',
            hintStyle: TextStyle(color: Colors.grey.shade500),
            prefixIcon: Icon(Icons.search, color: Colors.deepPurple.shade400, size: 26),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear, color: Colors.deepPurple.shade400),
              onPressed: () {
                _searchController.clear();
                // setState is handled by the listener
              },
            )
                : null,
            border: InputBorder.none, // No border for cleaner look
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
          style: TextStyle(color: Colors.deepPurple.shade800, fontSize: 16),
        ),
      ),
    );
  }

  /// Filters clubs based on the current search query.
  List<DocumentSnapshot> _filterClubs(List<DocumentSnapshot> clubs) {
    if (_searchQuery.isEmpty) return clubs;

    return clubs.where((clubDoc) {
      final clubData = clubDoc.data() as Map<String, dynamic>;
      final name = (clubData['name'] ?? '').toLowerCase();
      final info = (clubData['info'] ?? '').toLowerCase();
      final category = (clubData['category'] ?? '').toLowerCase(); // Also search by category

      return name.contains(_searchQuery) ||
          info.contains(_searchQuery) ||
          category.contains(_searchQuery);
    }).toList();
  }

  /// Sorts clubs based on the selected criteria (only upvotes now).
  List<DocumentSnapshot> _sortClubs(List<DocumentSnapshot> clubs) {
    clubs.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      // Only sort by upvotes now
      final upvotesA = (dataA['upvotes'] ?? 0) as int;
      final upvotesB = (dataB['upvotes'] ?? 0) as int;
      return upvotesB.compareTo(upvotesA); // Descending order (most upvotes first)
    });
    return clubs;
  }

  /// Builds an individual club card.
  Widget _buildClubCard(DocumentSnapshot clubDoc) {
    final club = clubDoc.data() as Map<String, dynamic>;
    final clubId = clubDoc.id;
    final members = List<String>.from(club['members'] ?? []);
    final votedUsers = List<String>.from(club['voted_users'] ?? []);
    final isMember = members.contains(currentUser);
    final hasVoted = votedUsers.contains(currentUser);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      elevation: 8, // Increased elevation for a floating effect
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // More rounded corners
      shadowColor: Colors.deepPurple.shade100.withOpacity(0.6), // Enhanced shadow
      child: InkWell( // Added InkWell for ripple effect on tap
        onTap: () {
          // Optional: Navigate to a club detail page
          _showSnackBar('Tapped on ${club['name']}', Colors.deepPurple.shade400);
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20), // Increased padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          club['name'] ?? 'Unnamed Club',
                          style: TextStyle(
                            fontSize: 22, // Larger title
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade800, // Darker purple
                            letterSpacing: 0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (club['category'] != null && (club['category'] as String).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Chip(
                              label: Text(
                                club['category'],
                                style: TextStyle(
                                  color: Colors.deepPurple.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: Colors.deepPurple.shade100,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isMember)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 18, color: Colors.green.shade700),
                          const SizedBox(width: 6),
                          Text('Member', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                club['info'] ?? 'No description available for this club.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                maxLines: 3, // Limit description lines
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 18),
              // Only show upvotes count now
              Row(
                children: [
                  Icon(Icons.recommend_outlined, size: 20, color: Colors.deepPurple.shade400),
                  const SizedBox(width: 6),
                  Text(
                    '${club['upvotes'] ?? 0} upvotes',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Action buttons for all three link types
              Wrap(
                spacing: 12, // Space between buttons
                runSpacing: 12, // Space between rows of buttons
                children: [
                  // Group Link Button (WhatsApp/Telegram)
                  // Added .trim() to ensure no leading/trailing whitespace causes issues
                  if (club['group_link'] != null && (club['group_link'] as String).trim().isNotEmpty)
                    _buildActionButton(
                      icon: Icons.group_add_outlined,
                      label: 'Join Group',
                      onPressed: () => _openLink(club['group_link'], 'Group'),
                      color: Colors.green.shade700,
                    ),
                  // Club Page Button (Facebook/Website)
                  if (club['page_link'] != null && (club['page_link'] as String).trim().isNotEmpty)
                    _buildActionButton(
                      icon: Icons.web_outlined,
                      label: 'Club Page',
                      onPressed: () => _openLink(club['page_link'], 'Club Page'),
                      color: Colors.blue.shade700,
                    ),
                  // Google Form Button
                  if (club['form_link'] != null && (club['form_link'] as String).trim().isNotEmpty)
                    _buildActionButton(
                      icon: Icons.assignment_outlined,
                      label: 'Apply Now',
                      onPressed: () => _openLink(club['form_link'], 'Application Form'),
                      color: Colors.pinkAccent.shade700,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Upvote Button
              Row(
                mainAxisAlignment: MainAxisAlignment.end, // Align to end
                children: [
                  GestureDetector(
                    onTap: () => _voteClub(clubId, club['name'] ?? 'Club'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: hasVoted ? Colors.deepPurple.shade600 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: hasVoted ? Colors.deepPurple.shade700 : Colors.grey.shade300,
                          width: hasVoted ? 1.5 : 1,
                        ),
                        boxShadow: hasVoted
                            ? [
                          BoxShadow(
                            color: Colors.deepPurple.shade200.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasVoted ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                            color: hasVoted ? Colors.white : Colors.deepPurple.shade600,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasVoted ? 'Voted!' : 'Upvote',
                            style: TextStyle(
                              color: hasVoted ? Colors.white : Colors.deepPurple.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for action buttons with better styling and icons
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
      ),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color, // Use provided color
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 4,
        shadowColor: color.withOpacity(0.4),
      ),
    );
  }

  /// Shows the sort options dialog - simplified to only show upvotes.
  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Clubs By', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOption('Most Upvotes', 'upvotes_desc'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Done', style: TextStyle(color: Colors.deepPurple.shade700, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Helper to build a single sort option RadioListTile.
  Widget _buildSortOption(String title, String value) {
    return RadioListTile<String>(
      title: Text(title, style: TextStyle(color: Colors.grey.shade800, fontSize: 16)),
      value: value,
      groupValue: _sortBy,
      onChanged: (newValue) {
        setState(() {
          _sortBy = newValue!;
        });
        Navigator.pop(context); // Close dialog after selection
      },
      activeColor: Colors.deepPurple.shade600,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Student Clubs',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 26, // Larger and bolder app bar title
          ),
        ),
        elevation: 0, // No shadow for a modern look
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF673AB7), Color(0xFF9575CD)], // Slightly adjusted gradient for depth
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white, // White icons and text
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded, size: 28), // Larger, rounded sort icon
            onPressed: _showSortDialog,
            tooltip: 'Sort Clubs',
          ),
          const SizedBox(width: 8), // Padding on the right
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 80, color: Colors.redAccent),
                        const SizedBox(height: 20),
                        Text(
                          'Error loading clubs: ${snapshot.error}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.red.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => setState(() {}), // Retrigger stream
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.deepPurple.shade400),
                        const SizedBox(height: 20),
                        Text(
                          'Loading exciting clubs...',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final allClubs = snapshot.data!.docs;
                final filteredClubs = _filterClubs(allClubs);
                final sortedClubs = _sortClubs(filteredClubs);

                if (sortedClubs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.category_outlined,
                          size: 90,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 25),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No clubs match your search criteria'
                              : 'No clubs found yet. Check back soon!',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              _searchController.clear();
                            },
                            icon: const Icon(Icons.clear_all_rounded),
                            label: const Text('Clear Search'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple.shade400,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: sortedClubs.length,
                  itemBuilder: (context, index) {
                    return _buildClubCard(sortedClubs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      backgroundColor: Colors.deepPurple.shade50, // Lighter background for the entire page
    );
  }
}