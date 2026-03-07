import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lokseva/services/api_service.dart';
import 'package:lokseva/services/complete_profile_screen.dart';
import 'package:lokseva/services/user_state.dart';
import 'package:lokseva/strings/localization.dart';
import 'package:image_picker/image_picker.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Key to access SearchContent state for chat operations
  final GlobalKey<SearchContentState> _searchContentKey = GlobalKey<SearchContentState>();

  Localization localization = Localization();

  @override
  void initState() {
    super.initState();
  }

  late final List<Widget> _pages = [
    const HomeAudit(),
    SearchContent(key: _searchContentKey), // Pass key to access state
    const ProfileContent(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Get current chat title from SearchContent
  String _getAppBarTitle() {
    if (_selectedIndex == 1) {
      final chatTitle = _searchContentKey.currentState?.currentTitle;
      return chatTitle ?? 'LokSeva AI Assistant';
    }
    return 'LokSeva';
  }

  // Handle new chat button press
  void _onNewChatPressed() {
    _searchContentKey.currentState?.startNewChat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          _getAppBarTitle(),
          maxLines: 1,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold),
          overflow: TextOverflow.clip,
        ),
        leading: _selectedIndex == 1
        ? IconButton(
          icon: const Icon(Icons.history),
          onPressed: () {
            // Force refresh history before opening drawer
            _searchContentKey.currentState?.loadChatHistory();
            setState(() {}); // Rebuild to ensure fresh state
            _scaffoldKey.currentState?.openDrawer();
          },
          tooltip: 'Chat History')
        : null),
      drawer: _selectedIndex == 1
        ? Builder(builder: (context) => _buildHistoryDrawer())
        : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        child: Theme(
          data: Theme.of(context).copyWith(splashFactory: NoSplash.splashFactory),
          child: Padding(
            padding: EdgeInsetsGeometry.fromLTRB(0, 8, 0, 0),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.black,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: Colors.deepPurpleAccent,
              unselectedItemColor: Colors.grey,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home),
                  label: localization.homeAuditLabel,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.chat),
                  label: localization.chatLabel,
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // History drawer - delegates to SearchContent for data
  Widget _buildHistoryDrawer() {
    return Drawer(
      backgroundColor: Color.fromARGB(255, 29, 0, 37),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Colors.deepPurpleAccent),
                  const SizedBox(width: 12),
                  const Text(
                    'Chat History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.deepPurpleAccent),
                    onPressed: () {
                      _onNewChatPressed();
                      Navigator.pop(context);
                    },
                    tooltip: 'New Chat',
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.grey),

            // History List - delegated to SearchContent
            Expanded(
              child: Builder(
                builder: (context) {
                  final searchState = _searchContentKey.currentState;
                  if (searchState == null) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  return _buildHistoryListFromState(searchState);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // REPLACE _buildHistoryList() with this:
  Widget _buildHistoryListFromState(SearchContentState searchState) {
    final chatHistory = searchState.chatHistory;
    final isLoadingHistory = searchState.isLoadingHistory;
    final hasMoreHistory = searchState.hasMoreHistory;

    if (isLoadingHistory && chatHistory.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chatHistory.isEmpty) {
      return const Center(
        child: Text(
          'No chat history yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: chatHistory.length + (hasMoreHistory ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatHistory.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: isLoadingHistory
                  ? null
                  : () => searchState.loadChatHistory(loadMore: true),
              child: isLoadingHistory
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Load More'),
            ),
          );
        }
        return _buildHistoryItem(chatHistory[index], searchState);
      },
    );
  }

  Widget _buildHistoryItem(ChatHistoryItem item, SearchContentState searchState) {
    final isSelected = item.conversationId == searchState.currentConversationId;
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.deepPurpleAccent.withOpacity(0.3) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () {
          searchState.loadConversation(item);
          Navigator.pop(context); // Close drawer
          setState(() {}); // Refresh AppBar title
        },
        leading: const Icon(Icons.chat_bubble_outline, color: Colors.grey),
        title: Text(
          item.title,
          style: const TextStyle(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.lastMessage,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              dateFormat.format(item.date),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
            ),
          ],
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Colors.deepPurpleAccent, size: 16)
            : null,
      ),
    );
  }
}

// =============================================================================
// HOME AUDIT (unchanged)
// =============================================================================

class HomeAudit extends StatefulWidget {
  const HomeAudit({super.key});

  @override
  State<HomeAudit> createState() => _HomeAuditState();
}

class _HomeAuditState extends State<HomeAudit> {
  final UserState _userState = UserState();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  String? _selectedRoomType;
  bool _isLoading = false;
  AuditResponse? _auditResult;

  final List<String> _roomTypes = [
    'Bathroom',
    'Bedroom',
    'Kitchen',
    'Living Room',
    'Stairs',
    'Hallway',
    'Entrance',
    'Other',
  ];

  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _auditResult = null;
        });
      }
    } catch (e) {
      _showError('Failed to access camera: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _auditResult = null;
        });
      }
    } catch (e) {
      _showError('Failed to access gallery: $e');
    }
  }

  Future<String> _imageToBase64(File image) async {
    final bytes = await image.readAsBytes();
    final base64String = base64Encode(bytes);
    final extension = image.path.split('.').last.toLowerCase();
    final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
    return 'data:$mimeType;base64,$base64String';
  }

  Future<void> _submitAudit() async {
    if (_selectedImage == null) {
      _showError('Please select an image first');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final imageBase64 = await _imageToBase64(_selectedImage!);

      print('🔍 DEBUG - Sending audit request...');
      print('🔍 DEBUG - Room type: $_selectedRoomType');
      print('🔍 DEBUG - Image size: ${imageBase64.length} characters');
      print('🔍 DEBUG - Email: ${_userState.currentUser?.email}');

      final result = await _apiService.auditImage(
        imageBase64: imageBase64,
        roomType: _selectedRoomType,
        userEmail: _userState.currentUser?.email,
      );

      setState(() {
        _auditResult = result;
      });

      _showSuccess('Audit completed successfully!');
    } on ApiException catch (e) {
      _showError('Audit failed: ${e.message}');
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Image Source',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickFromCamera();
                    },
                  ),
                  _buildSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickFromGallery();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.home_outlined, size: 60, color: Colors.deepPurpleAccent),
          const SizedBox(height: 12),
          const Text(
            'Upload a photo of your room',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Our AI will analyze it for fall risks based on NBC 2016 Standards',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 30),

          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              )
                  : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 50, color: Colors.deepPurpleAccent),
                  SizedBox(height: 12),
                  Text(
                    'Tap to select image',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRoomType,
                hint: const Text('Select Room Type', style: TextStyle(color: Colors.grey)),
                dropdownColor: Colors.grey.shade900,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.deepPurpleAccent),
                items: _roomTypes.map((room) {
                  return DropdownMenuItem(
                    value: room,
                    child: Text(room, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedRoomType = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 30),

          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitAudit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Analyze Room', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 30),

          if (_auditResult != null) _buildAuditResults(),
        ],
      ),
    );
  }

  Widget _buildAuditResults() {
    final result = _auditResult!;
    final scoreColor = Colors.green;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Safety Score: ',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scoreColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${result.safetyScore}/10',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (result.summary.isNotEmpty) ...[
            const Text(
              'Summary',
              style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(result.summary, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
          ],

          if (result.hazards.isNotEmpty) ...[
            const Text(
              'Hazards Found',
              style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...result.hazards.map((hazard) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(hazard, style: const TextStyle(color: Colors.white70))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// SEARCH CONTENT (Chat) - Removed Scaffold and AppBar
// =============================================================================

class SearchContent extends StatefulWidget {
  const SearchContent({super.key});

  @override
  State<SearchContent> createState() => SearchContentState();
}

class SearchContentState extends State<SearchContent> {
  final ApiService _apiService = ApiService();
  final UserState _userState = UserState();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  List<ChatHistoryItem> _chatHistory = [];
  String? _currentConversationId;
  String? _currentTitle;
  bool _isLoading = false;
  bool _isLoadingHistory = false;
  bool _hasMoreHistory = false;
  int _historyPage = 1;

  // Public getters for parent widget to access
  String? get currentTitle => _currentTitle;
  String? get currentConversationId => _currentConversationId;
  List<ChatHistoryItem> get chatHistory => _chatHistory;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get hasMoreHistory => _hasMoreHistory;

  @override
  void initState() {
    super.initState();
    loadChatHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? get _userEmail => _userState.currentUser?.email;

  // Made public for parent access
  Future<void> loadChatHistory({bool loadMore = false}) async {
    if (_userEmail == null) return;

    if (loadMore) {
      _historyPage++;
    } else {
      _historyPage = 1;
    }

    setState(() => _isLoadingHistory = true);

    try {
      final response = await _apiService.getChatHistory(
        userEmail: _userEmail!,
        page: _historyPage,
        limit: 10,
      );

      setState(() {
        if (loadMore) {
          _chatHistory.addAll(response.history);
        } else {
          _chatHistory = response.history;
        }
        _hasMoreHistory = response.hasMore;
      });
    } on ApiException catch (e) {
      _showError('Failed to load history: ${e.message}');
    } finally {
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _userEmail == null) return;

    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _apiService.sendChatMessage(
        userEmail: _userEmail!,
        message: message,
        conversationId: _currentConversationId,
      );

      setState(() {
        _currentConversationId = response.conversationId;
        _currentTitle = response.title ?? _currentTitle;

        _messages.add(ChatMessage(
          text: response.reply,
          isUser: false,
          timestamp: DateTime.now(),
          recommendations: response.recommendations.isNotEmpty
              ? response.recommendations
              : null,
        ));
      });

      loadChatHistory();
      _scrollToBottom();

      // Notify parent to update AppBar title
      _notifyParent();
    } on ApiException catch (e) {
      _showError('Failed to send message: ${e.message}');
      setState(() {
        _messages.removeLast();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Made public for parent access
  void startNewChat() {
    setState(() {
      _messages = [];
      _currentConversationId = null;
      _currentTitle = null;
    });
    _notifyParent();
  }

  // Made public for parent access
  void loadConversation(ChatHistoryItem item) {
    setState(() {
      _messages = [];
      _currentConversationId = item.conversationId;
      _currentTitle = item.title;
      _messages.add(ChatMessage(
        text: 'Continuing conversation: "${item.title}"',
        isUser: false,
        timestamp: item.date,
      ));
    });
    _notifyParent();
  }

  void _notifyParent() {
    // Force parent rebuild to update AppBar
    // This is handled by setState in parent when needed
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    // No Scaffold or AppBar - just the content
    return Column(
      children: [
        // Messages List
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _isLoading) {
                return _buildTypingIndicator();
              }
              return _buildMessageBubble(_messages[index]);
            },
          ),
        ),

        // Input Field
        _buildInputField(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade700),
          const SizedBox(height: 16),
          const Text(
            'How can I help you today?',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask about healthcare services, safety tips, or home assistance',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip('Find a nurse near me'),
              _buildSuggestionChip('Home safety tips'),
              _buildSuggestionChip('Emergency contacts'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.grey.shade800,
      onPressed: () {
        _messageController.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
        message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: message.isUser
                  ? Colors.deepPurpleAccent
                  : Colors.grey.shade800,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                bottomRight: Radius.circular(message.isUser ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(message.timestamp),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          if (message.recommendations != null &&
              message.recommendations!.isNotEmpty)
            _buildRecommendationsSection(message.recommendations!),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection(List<Recommendation> recommendations) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Recommendations',
              style: TextStyle(
                color: Colors.deepPurpleAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: recommendations.length,
              itemBuilder: (context, index) {
                return _buildRecommendationCard(recommendations[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Recommendation rec) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade900, Colors.grey.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rec.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      rec.rating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.location_on, color: Colors.grey.shade500, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  rec.location,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Expanded(
            child: Text(
              rec.reason,
              style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _showError('Contact feature coming soon!');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Contact', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.4 + (value * 0.6)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  filled: true,
                  fillColor: Colors.grey.shade800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: const BoxDecoration(
                color: Colors.deepPurpleAccent,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PROFILE CONTENT (unchanged)
// =============================================================================

class ProfileContent extends StatelessWidget {
  const ProfileContent({super.key});

  @override
  Widget build(BuildContext context) {
    final user = UserState().currentUser;

    if (user == null) {
      return const Center(
        child: Text(
          'Please log in to view your profile',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Profile Picture
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurpleAccent,
                  Colors.deepPurpleAccent.shade700,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey.shade900,
              backgroundImage: user.profilePic != null && user.profilePic!.isNotEmpty
                  ? NetworkImage(user.profilePic!)
                  : null,
              child: user.profilePic == null || user.profilePic!.isEmpty
                  ? Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurpleAccent,
                ),
              )
                  : null,
            ),
          ),
          const SizedBox(height: 20),

          // Name
          Text(
            user.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),

          // Email
          Text(
            user.email,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),

          // Profile Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: user.isComplete
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: user.isComplete ? Colors.green : Colors.orange,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  user.isComplete ? Icons.verified : Icons.pending,
                  size: 16,
                  color: user.isComplete ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  user.isComplete ? 'Profile Complete' : 'Profile Incomplete',
                  style: TextStyle(
                    color: user.isComplete ? Colors.green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Info Cards
          _buildInfoCard(
            icon: Icons.cake,
            label: 'Age',
            value: user.age != null ? '${user.age} years old' : 'Not set',
            isSet: user.age != null,
          ),
          _buildInfoCard(
            icon: Icons.phone,
            label: 'Phone',
            value: user.phone ?? 'Not set',
            isSet: user.phone != null && user.phone!.isNotEmpty,
          ),
          _buildInfoCard(
            icon: Icons.location_on,
            label: 'Address',
            value: user.address ?? 'Not set',
            isSet: user.address != null && user.address!.isNotEmpty,
          ),
          _buildInfoCard(
            icon: Icons.medical_services,
            label: 'Medical History',
            value: user.medicalHistory ?? 'None',
            isSet: user.medicalHistory != null && user.medicalHistory!.isNotEmpty,
          ),

          const SizedBox(height: 30),

          // Edit Profile Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                final user = UserState().currentUser;
                if (user != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CompleteProfileScreen(initialProfile: user),
                    ),
                  );
                }
              },
              icon: Icon(user.isComplete ? Icons.edit : Icons.add_circle_outline),
              label: Text(
                user.isComplete ? 'Edit Profile' : 'Complete Profile',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {
                _showLogoutDialog(context);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout', style: TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isSet,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.deepPurpleAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),

          // Label & Value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: isSet ? Colors.white : Colors.grey.shade600,
                    fontSize: 15,
                    fontStyle: isSet ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // Status indicator
          Icon(
            isSet ? Icons.check_circle : Icons.add_circle_outline,
            color: isSet ? Colors.green : Colors.grey.shade600,
            size: 20,
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Clear user state
              UserState().clearUser();
              Navigator.pop(context);
              // Navigate to login
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}