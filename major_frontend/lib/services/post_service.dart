import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart' as app_config;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart' as dio;
import '../screens/auth/auth_screens.dart';

class PostService {
  final String baseUrl = '${app_config.Config.baseUrl}/api/posts';
  final dio.Dio _dio = dio.Dio();

  Future<List<Map<String, dynamic>>> getFeed() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      
      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching feed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserPosts(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      
      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/user/$uid'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching user posts: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createPost(String content, {List<Map<String, dynamic>>? media}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'content': content,
          'media': media,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error creating post: $e');
      return null;
    }
  }

  Future<bool> toggleLike(int postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/$postId/like'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['liked'];
      }
      return false;
    } catch (e) {
      print('Error toggling like: $e');
      return false;
    }
  }

  Future<bool> toggleSave(int postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/$postId/save'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('PostService: Toggle save success: ${data['saved']}');
        return data['saved'];
      }
      print('PostService: Toggle save failed with status: ${response.statusCode}');
      return false;
    } catch (e) {
      print('Error toggling save: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getSavedPosts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('PostService: No current user for getSavedPosts');
        return [];
      }

      final token = await user.getIdToken();
      print('PostService: Fetching saved posts from $baseUrl/saved');
      final response = await http.get(
        Uri.parse('$baseUrl/saved'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('PostService: getSavedPosts status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('PostService: Error fetching saved posts: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCollectionsWithPostStatus(int postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final token = await user.getIdToken();
      print('PostService: Fetching collections for post $postId');
      final response = await http.get(
        Uri.parse('$baseUrl/collections/post/$postId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('PostService: Error fetching collections with post status: $e');
      return [];
    }
  }

  // Collections
  Future<List<Map<String, dynamic>>> getCollections() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      
      final token = await user.getIdToken();
      print('PostService: Fetching all collections from $baseUrl/collections/all');
      final response = await http.get(
        Uri.parse('$baseUrl/collections/all'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      print('PostService: getCollections status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('PostService: Error fetching collections: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createCollection(String name) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/collections'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': name}),
      );
      if (response.statusCode == 201) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> addPostToCollection(int collectionId, int postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/collections/$collectionId/add'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'postId': postId}),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removePostFromCollection(int collectionId, int postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final token = await user.getIdToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/collections/$collectionId/remove/$postId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getPostsByCollection(int collectionId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/collections/$collectionId/posts'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteCollection(int collectionId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final token = await user.getIdToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/collections/$collectionId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateCollection(int collectionId, String name) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final token = await user.getIdToken();
      final response = await http.put(
        Uri.parse('$baseUrl/collections/$collectionId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': name}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> uploadPostMedia(String filePath) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final token = await user.getIdToken();
      
      final fileName = filePath.split('/').last;
      final formData = dio.FormData.fromMap({
        'media': await dio.MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post(
        '$baseUrl/upload',
        data: formData,
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('Error uploading post media with Dio: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> addComment(int postId, String content, {int? parentCommentId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/$postId/comment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'content': content,
          'parentCommentId': parentCommentId,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding comment: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> updatePost(int postId, String content) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final token = await user.getIdToken();
      final response = await http.put(
        Uri.parse('$baseUrl/$postId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error updating post: $e');
      return null;
    }
  }

  Future<bool> deletePost(int postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final token = await user.getIdToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/$postId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting post: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getPostById(int postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/$postId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error fetching post by ID: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getComments(int postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/$postId/comments'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching comments: $e');
      return [];
    }
  }

  Future<bool> updateComment(int commentId, String content) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final token = await user.getIdToken();
      final response = await http.put(
        Uri.parse('$baseUrl/comments/$commentId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'content': content}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating comment: $e');
      return false;
    }
  }

  Future<bool> deleteComment(int commentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final token = await user.getIdToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/comments/$commentId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting comment: $e');
      return false;
    }
  }
}
