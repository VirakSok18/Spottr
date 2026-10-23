import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/post_service.dart';
import '../../widgets/post_widget.dart';
import '../../widgets/collection_widgets.dart';
import 'package:flutter/services.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({Key? key}) : super(key: key);

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final PostService _postService = PostService();
  List<PostModel> _savedPosts = [];
  List<Map<String, dynamic>> _collections = [];
  Map<String, dynamic>? _selectedCollection; // null means viewing all collections
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (_selectedCollection == null) {
        // Load All Posts (for 'All' folder) and Collections list
        final postsData = await _postService.getSavedPosts();
        final collsData = await _postService.getCollections();
        if (mounted) {
          setState(() {
            _savedPosts = postsData.map((json) => PostModel.fromJson(json)).toList();
            _collections = collsData;
          });
        }
      } else if (_selectedCollection!['id'] == 'all') {
         final postsData = await _postService.getSavedPosts();
         if (mounted) {
           setState(() {
             _savedPosts = postsData.map((json) => PostModel.fromJson(json)).toList();
           });
         }
      } else {
        // Load posts for specific collection
        final postsData = await _postService.getPostsByCollection(_selectedCollection!['id']);
        if (mounted) {
          setState(() {
            _savedPosts = postsData.map((json) => PostModel.fromJson(json)).toList();
          });
        }
      }
    } catch (e) {
      print('Error fetching favorite data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _createNewCollection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return NewCollectionSheet(
          onCreated: (name) async {
            if (name.isNotEmpty) {
              await _postService.createCollection(name);
              _fetchData();
            }
          },
        );
      },
    );
  }

  Future<void> _deleteCollection(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text('Delete Collection?', style: GoogleFonts.poppins(color: Colors.white)),
        content: const Text('All items will still be available in your "All" folder.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _postService.deleteCollection(id);
      _fetchData();
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: Icon(_selectedCollection == null ? Icons.arrow_back : Icons.chevron_left, color: Colors.white),
          onPressed: () {
            if (_selectedCollection != null) {
              setState(() => _selectedCollection = null);
              _fetchData();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _selectedCollection == null ? 'Favorite' : _selectedCollection!['name'],
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_selectedCollection == null)
            IconButton(
              icon: const Icon(Icons.add, color: Color(0xFFB794F6)),
              onPressed: _createNewCollection,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFB794F6)))
          : _selectedCollection == null
              ? _buildCollectionsGrid()
              : _buildPostsList(),
    );
  }

  Widget _buildCollectionsGrid() {
    // Generate the "All" collection dynamically
    final allCollection = {
      'id': 'all',
      'name': 'All Posts',
      'postCount': _savedPosts.length,
      'coverUrl': _savedPosts.isNotEmpty && _savedPosts.first.media.isNotEmpty 
          ? _savedPosts.first.media.first['url'] 
          : null,
    };

    final List<Map<String, dynamic>> displayItems = [allCollection, ..._collections];

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: const Color(0xFFB794F6),
      child: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 24,
          childAspectRatio: 0.68,
        ),
        itemCount: displayItems.length,
        itemBuilder: (context, index) {
          final coll = displayItems[index];
          return CollectionCard(
            collection: coll,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedCollection = coll);
              _fetchData();
            },
            onDelete: coll['id'] == 'all' ? null : () => _deleteCollection(coll['id']),
            onRename: coll['id'] == 'all' ? null : (newName) async {
              await _postService.updateCollection(coll['id'], newName);
              _fetchData();
            },
          );
        },
      ),
    );
  }

  Widget _buildPostsList() {
    if (_savedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No posts in this collection', style: GoogleFonts.poppins(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: const Color(0xFFB794F6),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _savedPosts.length,
        itemBuilder: (context, index) {
          final post = _savedPosts[index];
          return PostWidget(
            post: post,
            onLike: () async {
              // PostWidget handles internal model update, we just refresh parent state if needed
              if (mounted) setState(() {});
            },
            onSave: () async {
              // PostWidget handles toggleSave, but for specific collections, 
              // we also need to explicitly remove the item if it was an unsave action
              if (_selectedCollection!['id'] != 'all' && !post.isSaved) {
                await _postService.removePostFromCollection(_selectedCollection!['id'], post.id);
              }
              _fetchData();
            },
          );
        },
      ),
    );
  }
}
