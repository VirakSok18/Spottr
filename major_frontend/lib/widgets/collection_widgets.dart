import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/post_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CollectionSelectionSheet extends StatefulWidget {
  final int postId;
  final String? postCover;

  const CollectionSelectionSheet({
    Key? key,
    required this.postId,
    this.postCover,
  }) : super(key: key);

  @override
  State<CollectionSelectionSheet> createState() => _CollectionSelectionSheetState();
}

class _CollectionSelectionSheetState extends State<CollectionSelectionSheet> {
  final PostService _postService = PostService();
  List<Map<String, dynamic>> _collections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final data = await _postService.getCollectionsWithPostStatus(widget.postId);
    if (mounted) {
      setState(() {
        _collections = data;
        _isLoading = false;
      });
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
              final newColl = await _postService.createCollection(name);
              if (newColl != null) {
                _loadCollections();
                _toggleCollection(newColl['id'], false);
              }
            }
          },
        );
      },
    );
  }

  Future<void> _toggleCollection(int collId, bool alreadyIn) async {
    bool success;
    if (alreadyIn) {
      success = await _postService.removePostFromCollection(collId, widget.postId);
    } else {
      success = await _postService.addPostToCollection(collId, widget.postId);
    }

    if (success && mounted) {
      setState(() {
        final index = _collections.indexWhere((c) => c['id'] == collId);
        if (index != -1) {
          _collections[index]['isInCollection'] = alreadyIn ? 0 : 1;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(alreadyIn ? 'Removed from collection' : 'Added to collection'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B1B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Collections',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: _createNewCollection,
                  child: Text(
                    'New collection',
                    style: GoogleFonts.poppins(color: const Color(0xFFB794F6)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 48,
                height: 48,
                color: Colors.grey[800],
                child: widget.postCover != null 
                  ? CachedNetworkImage(imageUrl: widget.postCover!, fit: BoxFit.cover)
                  : const Icon(Icons.bookmark, color: Colors.white70),
              ),
            ),
            title: Text('Saved', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text('Private', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.bookmark, color: Color(0xFFB794F6)),
            onTap: () {
              // Unsave globally
              Navigator.pop(context, 'unsave_globally');
            },
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFB794F6))),
            )
          else if (_collections.isNotEmpty)
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _collections.length,
                itemBuilder: (context, index) {
                  final coll = _collections[index];
                  final bool isInColl = coll['isInCollection'] == 1 || coll['isInCollection'] == true;
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey[800],
                        child: coll['coverUrl'] != null 
                          ? CachedNetworkImage(imageUrl: coll['coverUrl'], fit: BoxFit.cover)
                          : const Icon(Icons.folder, color: Colors.white70),
                      ),
                    ),
                    title: Text(coll['name'], style: GoogleFonts.poppins(color: Colors.white)),
                    subtitle: Text('Private', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                    trailing: Icon(
                      isInColl ? Icons.check_circle : Icons.add_circle_outline, 
                      color: isInColl ? const Color(0xFFB794F6) : Colors.white54
                    ),
                    onTap: () => _toggleCollection(coll['id'], isInColl),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class CollectionCard extends StatelessWidget {
  final Map<String, dynamic> collection;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Function(String)? onRename;

  const CollectionCard({
    Key? key,
    required this.collection,
    this.onTap,
    this.onDelete,
    this.onRename,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: collection['coverUrl'] != null
                    ? CachedNetworkImage(
                        imageUrl: collection['coverUrl'],
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Icon(
                          collection['name'] == 'All' ? Icons.bookmark : Icons.folder_open,
                          size: 40,
                          color: Colors.white24,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  collection['name'],
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (collection['id'] != null) // Don't show menu for "All" folder
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white54, size: 16),
                  padding: EdgeInsets.zero,
                  color: const Color(0xFF2A2A2A),
                  onSelected: (val) {
                    if (val == 'delete' && onDelete != null) onDelete!();
                    if (val == 'rename' && onRename != null) {
                      _showRenameDialog(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
            ],
          ),
          Text(
            '${collection['postCount'] ?? 0} items',
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return NewCollectionSheet(
          initialName: collection['name'],
          title: 'Rename Collection',
          actionLabel: 'Rename',
          onCreated: (newName) {
            if (onRename != null) onRename!(newName);
          },
        );
      },
    );
  }
}

class NewCollectionSheet extends StatefulWidget {
  final Function(String) onCreated;
  final String? initialName;
  final String title;
  final String actionLabel;

  const NewCollectionSheet({
    Key? key,
    required this.onCreated,
    this.initialName,
    this.title = 'New collection',
    this.actionLabel = 'Next',
  }) : super(key: key);

  @override
  State<NewCollectionSheet> createState() => _NewCollectionSheetState();
}

class _NewCollectionSheetState extends State<NewCollectionSheet> {
  late final TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _hasText = _controller.text.trim().isNotEmpty;
    _controller.addListener(() {
      setState(() {
        _hasText = _controller.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF262626),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicator
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                widget.title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _hasText
                    ? () {
                        widget.onCreated(_controller.text.trim());
                        Navigator.pop(context);
                      }
                    : null,
                child: Text(
                  widget.actionLabel,
                  style: GoogleFonts.poppins(
                    color: _hasText ? const Color(0xFFB794F6) : Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Text Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white38, width: 1.5),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Collection name',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_hasText)
                  GestureDetector(
                    onTap: () => _controller.clear(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
