import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Import for date/time formatting

class AdminPanel extends StatefulWidget {
  final String adminRoll;

  const AdminPanel({Key? key, required this.adminRoll}) : super(key: key);

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> collections = ['events', 'workshops', 'notices', 'clubs'];
  final List<String> tabTitles = ['Events', 'Workshops', 'Notices', 'Clubs'];

  // Controllers for Events/Workshops
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  // Controllers for Notices (modified)
  final TextEditingController _noticeTitleController = TextEditingController();
  final TextEditingController _noticeDescriptionController = TextEditingController();
  final TextEditingController _noticeLinkController = TextEditingController();
  String _selectedNoticeType = 'General'; // Default notice type

  // Controllers for Clubs
  final TextEditingController _clubNameController = TextEditingController();
  final TextEditingController _clubInfoController = TextEditingController();
  final TextEditingController _clubGroupLinkController = TextEditingController();
  final TextEditingController _clubPageLinkController = TextEditingController();
  final TextEditingController _clubFormLinkController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;

  String? _editingDocId;
  String? _currentCollectionForDialog;

  // Notice types for dropdown
  final List<String> _noticeTypes = ['General', 'Urgent', 'Important', 'Event', 'Announcement'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: collections.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _placeController.dispose();
    _linkController.dispose();
    _noticeTitleController.dispose();
    _noticeDescriptionController.dispose();
    _noticeLinkController.dispose();
    _clubNameController.dispose();
    _clubInfoController.dispose();
    _clubGroupLinkController.dispose();
    _clubPageLinkController.dispose();
    _clubFormLinkController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'SELECT DATE',
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.deepPurple,
            colorScheme: const ColorScheme.light(primary: Colors.deepPurple),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime
          ? (_selectedStartTime ?? TimeOfDay.now())
          : (_selectedEndTime ?? TimeOfDay.now()),
      helpText: isStartTime ? 'SELECT START TIME' : 'SELECT END TIME',
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.deepPurple,
            colorScheme: const ColorScheme.light(primary: Colors.deepPurple),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _selectedStartTime = picked;
        } else {
          _selectedEndTime = picked;
        }
      });
    }
  }

  /// Add/Edit Events and Workshops - Keep subtitle for these
  void _showAddOrEditDialog({required String collectionName, DocumentSnapshot? doc}) {
    _currentCollectionForDialog = collectionName;
    if (doc != null) {
      _editingDocId = doc.id;
      final data = doc.data() as Map<String, dynamic>;
      _titleController.text = data['title'] ?? '';
      _subtitleController.text = data['subtitle'] ?? '';
      _placeController.text = data['place'] ?? '';
      _linkController.text = data['link'] ?? '';

      // Date
      _selectedDate = (data['date'] as Timestamp?)?.toDate();

      // Populate time fields for existing docs
      if (data['start_time'] != null && data['start_time'] is String) {
        try {
          final timeString = data['start_time'] as String;
          final format = DateFormat.jm();
          final dateTime = format.parse(timeString);
          _selectedStartTime = TimeOfDay.fromDateTime(dateTime);
        } catch (e) {
          print('Error parsing start_time: $e');
          _selectedStartTime = null;
        }
      } else {
        _selectedStartTime = null;
      }

      if (data['end_time'] != null && data['end_time'] is String) {
        try {
          final timeString = data['end_time'] as String;
          final format = DateFormat.jm();
          final dateTime = format.parse(timeString);
          _selectedEndTime = TimeOfDay.fromDateTime(dateTime);
        } catch (e) {
          print('Error parsing end_time: $e');
          _selectedEndTime = null;
        }
      } else {
        _selectedEndTime = null;
      }
    } else {
      _editingDocId = null;
      _titleController.clear();
      _subtitleController.clear();
      _placeController.clear();
      _linkController.clear();
      _selectedDate = DateTime.now();
      _selectedStartTime = null;
      _selectedEndTime = null;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(doc == null ? "Add ${collectionName.capitalize()}" : "Edit ${collectionName.capitalize()}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              TextField(
                controller: _subtitleController,
                decoration: const InputDecoration(labelText: "Subtitle"),
              ),
              TextField(
                controller: _placeController,
                decoration: const InputDecoration(labelText: "Place"),
              ),
              TextField(
                controller: _linkController,
                decoration: InputDecoration(
                  labelText: "${collectionName.capitalize()} Link",
                  hintText: "Enter a link (e.g., https://forms.gle/...)",
                  prefixIcon: const Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDate == null
                          ? "Date: Not Selected"
                          : "Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}",
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _pickDate(context),
                    tooltip: 'Select Date',
                  ),
                ],
              ),
              // Time pickers for events and workshops
              if (collectionName == 'events' || collectionName == 'workshops') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => _pickTime(context, true),
                        child: Text(
                          _selectedStartTime == null
                              ? 'Start Time: Select'
                              : 'Start: ${_selectedStartTime!.format(context)}',
                          style: TextStyle(color: Theme.of(context).primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: () => _pickTime(context, false),
                        child: Text(
                          _selectedEndTime == null
                              ? 'End Time: Select'
                              : 'End: ${_selectedEndTime!.format(context)}',
                          style: TextStyle(color: Theme.of(context).primaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (_titleController.text.isEmpty ||
                  _subtitleController.text.isEmpty ||
                  _placeController.text.isEmpty ||
                  _selectedDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields are required!")));
                return;
              }

              // Validate time range for events/workshops
              if ((collectionName == 'events' || collectionName == 'workshops') &&
                  (_selectedStartTime == null || _selectedEndTime == null)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a start and end time!")));
                return;
              }

              final collection = FirebaseFirestore.instance.collection(collectionName);
              final itemData = {
                'title': _titleController.text.trim(),
                'subtitle': _subtitleController.text.trim(),
                'place': _placeController.text.trim(),
                'date': Timestamp.fromDate(_selectedDate!),
                'link': _linkController.text.trim(),
              };

              // Add time data if applicable
              if (collectionName == 'events' || collectionName == 'workshops') {
                itemData['start_time'] = _selectedStartTime!.format(context);
                itemData['end_time'] = _selectedEndTime!.format(context);
              }

              try {
                if (_editingDocId == null) {
                  await collection.add(itemData);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("${collectionName.capitalize()} added successfully!"))
                  );
                } else {
                  await collection.doc(_editingDocId).update(itemData);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("${collectionName.capitalize()} updated successfully!"))
                  );
                }
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error saving ${collectionName.capitalize()} data: $e"))
                );
                print("Error saving item: $e");
              }
            },
            child: Text(doc == null ? "Add" : "Update"),
          ),
        ],
      ),
    );
  }

  /// NEW: Add/Edit Notices with different structure (title + description + link + type)
  void _showNoticeDialog({DocumentSnapshot? doc}) {
    if (doc != null) {
      _editingDocId = doc.id;
      final data = doc.data() as Map<String, dynamic>;
      _noticeTitleController.text = data['title'] ?? '';
      _noticeDescriptionController.text = data['description'] ?? '';
      _noticeLinkController.text = data['notice_link'] ?? '';
      _selectedNoticeType = data['type'] ?? 'General';
      _selectedDate = (data['date'] as Timestamp?)?.toDate();
    } else {
      _editingDocId = null;
      _noticeTitleController.clear();
      _noticeDescriptionController.clear();
      _noticeLinkController.clear();
      _selectedNoticeType = 'General';
      _selectedDate = DateTime.now();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(doc == null ? "Add Notice" : "Edit Notice"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _noticeTitleController,
                decoration: const InputDecoration(
                  labelText: "Notice Title",
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noticeDescriptionController,
                decoration: const InputDecoration(
                  labelText: "Notice Description",
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noticeLinkController,
                decoration: const InputDecoration(
                  labelText: "Notice Link (Optional)",
                  hintText: "Facebook post or relevant link",
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 12),
              // Notice Type Dropdown
              DropdownButtonFormField<String>(
                value: _selectedNoticeType,
                decoration: const InputDecoration(
                  labelText: "Notice Type",
                  prefixIcon: Icon(Icons.category),
                ),
                items: _noticeTypes.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedNoticeType = value!;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDate == null
                          ? "Date: Not Selected"
                          : "Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}",
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _pickDate(context),
                    tooltip: 'Select Date',
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (_noticeTitleController.text.trim().isEmpty ||
                  _noticeDescriptionController.text.trim().isEmpty ||
                  _selectedDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Title, description and date are required!")));
                return;
              }

              final noticesCollection = FirebaseFirestore.instance.collection('notices');
              final noticeData = {
                'title': _noticeTitleController.text.trim(),
                'description': _noticeDescriptionController.text.trim(),
                'notice_link': _noticeLinkController.text.trim(),
                'type': _selectedNoticeType,
                'date': Timestamp.fromDate(_selectedDate!),
              };

              try {
                if (_editingDocId == null) {
                  await noticesCollection.add(noticeData);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Notice added successfully!")));
                } else {
                  await noticesCollection.doc(_editingDocId).update(noticeData);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Notice updated successfully!")));
                }
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error saving notice: $e")));
                print("Error saving notice: $e");
              }
            },
            child: Text(doc == null ? "Add Notice" : "Update Notice"),
          ),
        ],
      ),
    );
  }

  /// Add/Edit Clubs - UPDATED WITH .trim() FOR LINKS
  void _showClubDialog({DocumentSnapshot? doc}) {
    if (doc != null) {
      _editingDocId = doc.id;
      final data = doc.data() as Map<String, dynamic>;
      _clubNameController.text = data['name'] ?? '';
      _clubInfoController.text = data['info'] ?? '';
      _clubGroupLinkController.text = data['group_link'] ?? '';
      _clubPageLinkController.text = data['page_link'] ?? '';
      _clubFormLinkController.text = data['form_link'] ?? '';
    } else {
      _editingDocId = null;
      _clubNameController.clear();
      _clubInfoController.clear();
      _clubGroupLinkController.clear();
      _clubPageLinkController.clear();
      _clubFormLinkController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(doc == null ? "Add Club" : "Edit Club"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                  controller: _clubNameController,
                  decoration: const InputDecoration(
                    labelText: "Club Name",
                    hintText: "Enter club name",
                    prefixIcon: Icon(Icons.group),
                  )),
              const SizedBox(height: 12),
              TextField(
                controller: _clubInfoController,
                decoration: const InputDecoration(
                  labelText: "Club Info/Description",
                  hintText: "Enter club description",
                  prefixIcon: Icon(Icons.info),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _clubGroupLinkController,
                  decoration: const InputDecoration(
                    labelText: "Group Link",
                    hintText: "WhatsApp/Telegram group link",
                    prefixIcon: Icon(Icons.group_add),
                  )),
              const SizedBox(height: 12),
              TextField(
                  controller: _clubPageLinkController,
                  decoration: const InputDecoration(
                    labelText: "Club Page Link",
                    hintText: "Facebook page or website link",
                    prefixIcon: Icon(Icons.web),
                  )),
              const SizedBox(height: 12),
              TextField(
                  controller: _clubFormLinkController,
                  decoration: const InputDecoration(
                    labelText: "Google Form Link",
                    hintText: "Application/registration form link",
                    prefixIcon: Icon(Icons.assignment),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (_clubNameController.text.trim().isEmpty || _clubInfoController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Club name and info are required!")));
                return;
              }

              final clubsCollection = FirebaseFirestore.instance.collection('clubs');
              final clubData = {
                'name': _clubNameController.text.trim(),
                'info': _clubInfoController.text.trim(),
                'group_link': _clubGroupLinkController.text.trim(),
                'page_link': _clubPageLinkController.text.trim(),
                'form_link': _clubFormLinkController.text.trim(),
                if (_editingDocId == null) ...{
                  'upvotes': 0,
                  'voted_users': [],
                  'members': [],
                  'join_requests': [],
                  'created_at': FieldValue.serverTimestamp(),
                }
              };

              try {
                if (_editingDocId == null) {
                  await clubsCollection.add(clubData);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Club added successfully!")));
                } else {
                  await clubsCollection.doc(_editingDocId).update(clubData);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Club updated successfully!")));
                }
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error saving club data: $e")));
                print("Error saving club data: $e");
              }
            },
            child: Text(doc == null ? "Add Club" : "Update Club"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(String collectionName, String docId) async {
    final bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete this ${collectionName.capitalize()} item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmDelete) {
      try {
        await FirebaseFirestore.instance.collection(collectionName).doc(docId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${collectionName.capitalize()} deleted successfully!')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete ${collectionName.capitalize()}: $e')));
        print("Error deleting item: $e");
      }
    }
  }

  /// Club manager
  Widget buildClubManager() {
    final collection = FirebaseFirestore.instance.collection('clubs');
    return StreamBuilder<QuerySnapshot>(
      stream: collection.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error loading Clubs: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No Clubs found.'));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final joinRequests = List<String>.from(data['join_requests'] ?? []);
            final members = List<String>.from(data['members'] ?? []);

            return Card(
              margin: const EdgeInsets.all(8),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ExpansionTile(
                leading: const Icon(Icons.group, color: Colors.deepPurple),
                title: Text(data['name'] ?? 'Untitled Club', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['info'] ?? 'No info available', maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
                childrenPadding: const EdgeInsets.all(16.0),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('${data['upvotes'] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Text('Upvotes', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('${members.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Text('Members', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('${joinRequests.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Text('Requests', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (data['group_link'] != null && (data['group_link'] as String).isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.group_add, color: Colors.green),
                      title: const Text('Group Link'),
                      subtitle: Text(data['group_link'], maxLines: 1, overflow: TextOverflow.ellipsis),
                      dense: true,
                    ),
                  if (data['page_link'] != null && (data['page_link'] as String).isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.web, color: Colors.blue),
                      title: const Text('Club Page'),
                      subtitle: Text(data['page_link'], maxLines: 1, overflow: TextOverflow.ellipsis),
                      dense: true,
                    ),
                  if (data['form_link'] != null && (data['form_link'] as String).isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.assignment, color: Colors.orange),
                      title: const Text('Application Form'),
                      subtitle: Text(data['form_link'], maxLines: 1, overflow: TextOverflow.ellipsis),
                      dense: true,
                    ),

                  if (joinRequests.isNotEmpty) ...[
                    const Divider(),
                    const Text("Join Requests:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...joinRequests.map((req) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      color: Colors.blue.shade50,
                      child: ListTile(
                        title: Text(req),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              onPressed: () async {
                                try {
                                  await collection.doc(doc.id).update({
                                    'join_requests': FieldValue.arrayRemove([req]),
                                    'members': FieldValue.arrayUnion([req]),
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approved request from $req')));
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to approve request: $e')));
                                  print('Error approving request: $e');
                                }
                              },
                              tooltip: 'Approve Request',
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () async {
                                try {
                                  await collection.doc(doc.id).update({
                                    'join_requests': FieldValue.arrayRemove([req]),
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rejected request from $req')));
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reject request: $e')));
                                  print('Error rejecting request: $e');
                                }
                              },
                              tooltip: 'Reject Request',
                            ),
                          ],
                        ),
                      ),
                    )),
                  ],

                  const SizedBox(height: 16),
                  ButtonBar(
                    alignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showClubDialog(doc: doc),
                        tooltip: 'Edit Club',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteItem('clubs', doc.id),
                        tooltip: 'Delete Club',
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Manager for other collections - UPDATED FOR NOTICES
  Widget buildCollectionManager(String collectionName) {
    if (collectionName == 'clubs') return buildClubManager();
    if (collectionName == 'notices') return buildNoticeManager();

    final collection = FirebaseFirestore.instance.collection(collectionName);
    return StreamBuilder<QuerySnapshot>(
      stream: collection.orderBy('date').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error loading ${collectionName.capitalize()}: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text('No ${collectionName.capitalize()} found.'));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            String subtitleText = '';
            if (data.containsKey('date')) {
              subtitleText += "Date: ${DateFormat('yyyy-MM-dd').format((data['date'] as Timestamp).toDate())}";
            }
            // Add time range to subtitle if available and applicable
            if ((collectionName == 'events' || collectionName == 'workshops') &&
                data.containsKey('start_time') && data.containsKey('end_time') &&
                data['start_time'] is String && data['end_time'] is String &&
                (data['start_time'] as String).isNotEmpty && (data['end_time'] as String).isNotEmpty) {
              subtitleText += "\nTime: ${data['start_time']} - ${data['end_time']}";
            }
            if (data.containsKey('place') && (data['place'] as String).isNotEmpty) {
              subtitleText += "\nPlace: ${data['place']}";
            }
            // Display link in subtitle if available
            if (data.containsKey('link') && (data['link'] as String).isNotEmpty) {
              subtitleText += "\nLink: ${data['link']}";
            }

            return Card(
              margin: const EdgeInsets.all(8),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: Icon(
                  collectionName == 'events' ? Icons.event :
                  collectionName == 'workshops' ? Icons.handyman :
                  Icons.announcement,
                  color: Theme.of(context).primaryColor,
                ),
                title: Text(data['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(subtitleText.trim()),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Add link icon if item has a link
                    if (data.containsKey('link') && (data['link'] as String).isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.link, color: Colors.green),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Link: ${data['link']}')),
                          );
                        },
                        tooltip: '${collectionName.capitalize()} Link',
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showAddOrEditDialog(collectionName: collectionName, doc: doc),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteItem(collectionName, doc.id),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// NEW: Notice manager with special handling
  Widget buildNoticeManager() {
    final collection = FirebaseFirestore.instance.collection('notices');
    return StreamBuilder<QuerySnapshot>(
      stream: collection.orderBy('date', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error loading Notices: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No Notices found.'));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            String subtitleText = '';
            if (data.containsKey('date')) {
              subtitleText += "Date: ${DateFormat('yyyy-MM-dd').format((data['date'] as Timestamp).toDate())}";
            }
            if (data.containsKey('type') && (data['type'] as String).isNotEmpty) {
              subtitleText += "\nType: ${data['type']}";
            }
            if (data.containsKey('notice_link') && (data['notice_link'] as String).isNotEmpty) {
              subtitleText += "\nHas Link: Yes";
            }

            return Card(
              margin: const EdgeInsets.all(8),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ExpansionTile(
                leading: Icon(
                  Icons.notifications,
                  color: _getNoticeTypeColor(data['type'] ?? 'General'),
                ),
                title: Text(data['title'] ?? 'Untitled Notice', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(subtitleText.trim()),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(data['description'] ?? 'No description available'),
                        if (data.containsKey('notice_link') && (data['notice_link'] as String).isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('Notice Link:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(data['notice_link'], style: const TextStyle(color: Colors.blue)),
                        ],
                        const SizedBox(height: 16),
                        ButtonBar(
                          alignment: MainAxisAlignment.end,
                          children: [
                            if (data.containsKey('notice_link') && (data['notice_link'] as String).isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.link, color: Colors.green),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Link: ${data['notice_link']}')),
                                  );
                                },
                                tooltip: 'Notice Link',
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showNoticeDialog(doc: doc),
                              tooltip: 'Edit Notice',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteItem('notices', doc.id),
                              tooltip: 'Delete Notice',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper method to get notice type color
  Color _getNoticeTypeColor(String type) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.deepPurple.shade200,
          indicatorColor: Colors.white,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: tabTitles.map((title) => Tab(text: title)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: collections.map((c) => buildCollectionManager(c)).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        onPressed: () {
          final currentCollection = collections[_tabController.index];
          if (currentCollection == 'clubs') {
            _showClubDialog();
          } else if (currentCollection == 'notices') {
            _showNoticeDialog();
          } else {
            _showAddOrEditDialog(collectionName: currentCollection);
          }
        },
        tooltip: 'Add New Item',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Helper extension to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}