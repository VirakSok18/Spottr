import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'config.dart' as app_config;

class PostService {
  Future<List<Map<String, dynamic>>> getFeed() async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final res = await app_config.Config.supabase
          .from('feed_posts_view')
          .select()
          .order('createdAt', ascending: false);

      List<dynamic> likedIds = [];
      List<dynamic> savedIds = [];
      if (currentUid != null) {
        final likes = await app_config.Config.supabase
            .from('likes')
            .select('postId')
            .eq('userUid', currentUid);
        likedIds = likes.map((l) => l['postId']).toList();

        final saved = await app_config.Config.supabase
            .from('saved_posts')
            .select('postId')
            .eq('userUid', currentUid);
        savedIds = saved.map((s) => s['postId']).toList();
      }

      return res.map<Map<String, dynamic>>((post) {
        final m = Map<String, dynamic>.from(post);
        m['isLiked'] = likedIds.contains(m['id']);
        m['isSaved'] = savedIds.contains(m['id']);
        return m;
      }).toList();
    } catch (e) {
      print('PostService: Error fetching feed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserPosts(String uid) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final res = await app_config.Config.supabase
          .from('feed_posts_view')
          .select()
          .eq('userUid', uid)
          .order('createdAt', ascending: false);

      List<dynamic> likedIds = [];
      List<dynamic> savedIds = [];
      if (currentUid != null) {
        final likes = await app_config.Config.supabase
            .from('likes')
            .select('postId')
            .eq('userUid', currentUid);
        likedIds = likes.map((l) => l['postId']).toList();

        final saved = await app_config.Config.supabase
            .from('saved_posts')
            .select('postId')
            .eq('userUid', currentUid);
        savedIds = saved.map((s) => s['postId']).toList();
      }

      return res.map<Map<String, dynamic>>((post) {
        final m = Map<String, dynamic>.from(post);
        m['isLiked'] = likedIds.contains(m['id']);
        m['isSaved'] = savedIds.contains(m['id']);
        return m;
      }).toList();
    } catch (e) {
      print('PostService: Error fetching user posts: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createPost(
    String content, {
    List<Map<String, dynamic>>? media,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final inserted = await app_config.Config.supabase.from('posts').insert({
        'userUid': user.uid,
        'content': content,
        'createdAt': DateTime.now().toIso8601String(),
      }).select().single();

      final postId = inserted['id'];

      if (media != null && media.isNotEmpty) {
        for (var m in media) {
          await app_config.Config.supabase.from('post_media').insert({
            'postId': postId,
            'mediaUrl': m['url'] ?? m['mediaUrl'],
            'mediaType': m['type'] ?? m['mediaType'] ?? 'image',
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
      }

      return inserted;
    } catch (e) {
      print('PostService: Error creating post: $e');
      return null;
    }
  }

  Future<bool> toggleLike(int postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final existing = await app_config.Config.supabase
          .from('likes')
          .select('id')
          .eq('postId', postId)
          .eq('userUid', user.uid)
          .maybeSingle();

      if (existing != null) {
        await app_config.Config.supabase
            .from('likes')
            .delete()
            .eq('postId', postId)
            .eq('userUid', user.uid);
        return false;
      } else {
        await app_config.Config.supabase.from('likes').insert({
          'postId': postId,
          'userUid': user.uid,
          'createdAt': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      print('PostService: Error toggling like: $e');
      return false;
    }
  }

  Future<bool> toggleSave(int postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final existing = await app_config.Config.supabase
          .from('saved_posts')
          .select('id')
          .eq('postId', postId)
          .eq('userUid', user.uid)
          .maybeSingle();

      if (existing != null) {
        await app_config.Config.supabase
            .from('saved_posts')
            .delete()
            .eq('postId', postId)
            .eq('userUid', user.uid);
        return false;
      } else {
        await app_config.Config.supabase.from('saved_posts').insert({
          'postId': postId,
          'userUid': user.uid,
          'createdAt': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      print('PostService: Error toggling save: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getSavedPosts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final saved = await app_config.Config.supabase
          .from('saved_posts')
          .select('postId')
          .eq('userUid', user.uid);

      final ids = saved.map((s) => s['postId']).toList();
      if (ids.isEmpty) return [];

      final res = await app_config.Config.supabase
          .from('feed_posts_view')
          .select()
          .inFilter('id', ids)
          .order('createdAt', ascending: false);

      return res.map<Map<String, dynamic>>((post) {
        final m = Map<String, dynamic>.from(post);
        m['isSaved'] = true;
        return m;
      }).toList();
    } catch (e) {
      print('PostService: Error fetching saved posts: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCollectionsWithPostStatus(int postId) async {
    return [];
  }

  Future<List<Map<String, dynamic>>> getCollections() async {
    return [];
  }

  Future<Map<String, dynamic>?> createCollection(String name) async {
    return null;
  }

  Future<bool> addPostToCollection(int collectionId, int postId) async {
    return false;
  }

  Future<bool> removePostFromCollection(int collectionId, int postId) async {
    return false;
  }

  Future<List<Map<String, dynamic>>> getPostsByCollection(int collectionId) async {
    return [];
  }

  Future<bool> deleteCollection(int collectionId) async {
    return false;
  }

  Future<bool> updateCollection(int collectionId, String name) async {
    return false;
  }

  Future<Map<String, dynamic>?> uploadPostMedia(String filePath) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final ext = filePath.split('.').last.toLowerCase();
      final fileName = '${user.uid}_post_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await app_config.Config.supabase.storage.from('posts').uploadBinary(fileName, bytes);
      final publicUrl = app_config.Config.supabase.storage.from('posts').getPublicUrl(fileName);

      return {
        'url': publicUrl,
        'type': ext == 'mp4' || ext == 'mov' ? 'video' : 'image',
      };
    } catch (e) {
      print('PostService: Error uploading post media: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> addComment(
    int postId,
    String content, {
    int? parentCommentId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final inserted = await app_config.Config.supabase.from('comments').insert({
        'postId': postId,
        'userUid': user.uid,
        'content': content,
        'parentCommentId': parentCommentId,
        'createdAt': DateTime.now().toIso8601String(),
      }).select().single();

      return inserted;
    } catch (e) {
      print('PostService: Error adding comment: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> updatePost(int postId, String content) async {
    try {
      final updated = await app_config.Config.supabase
          .from('posts')
          .update({'content': content})
          .eq('id', postId)
          .select()
          .single();
      return updated;
    } catch (e) {
      print('PostService: Error updating post: $e');
      return null;
    }
  }

  Future<bool> deletePost(int postId) async {
    try {
      await app_config.Config.supabase.from('posts').delete().eq('id', postId);
      return true;
    } catch (e) {
      print('PostService: Error deleting post: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getPostById(int postId) async {
    try {
      final res = await app_config.Config.supabase
          .from('feed_posts_view')
          .select()
          .eq('id', postId)
          .maybeSingle();
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
      return null;
    } catch (e) {
      print('PostService: Error fetching post by ID: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getComments(int postId) async {
    try {
      final comments = await app_config.Config.supabase
          .from('comments')
          .select()
          .eq('postId', postId)
          .order('createdAt', ascending: true);

      if (comments.isEmpty) return [];

      final uids = comments.map((c) => c['userUid']).toSet().toList();
      final users = await app_config.Config.supabase
          .from('users')
          .select('firebaseUid, fullName, profilePictureUrl')
          .inFilter('firebaseUid', uids);

      final userMap = {for (var u in users) u['firebaseUid']: u};

      return comments.map<Map<String, dynamic>>((c) {
        final m = Map<String, dynamic>.from(c);
        final u = userMap[m['userUid']];
        m['userName'] = u?['fullName'] ?? 'Athlete';
        m['userAvatar'] = u?['profilePictureUrl'];
        return m;
      }).toList();
    } catch (e) {
      print('PostService: Error fetching comments: $e');
      return [];
    }
  }

  Future<bool> updateComment(int commentId, String content) async {
    try {
      await app_config.Config.supabase
          .from('comments')
          .update({'content': content})
          .eq('id', commentId);
      return true;
    } catch (e) {
      print('PostService: Error updating comment: $e');
      return false;
    }
  }

  Future<bool> deleteComment(int commentId) async {
    try {
      await app_config.Config.supabase
          .from('comments')
          .delete()
          .eq('id', commentId);
      return true;
    } catch (e) {
      print('PostService: Error deleting comment: $e');
      return false;
    }
  }
}
