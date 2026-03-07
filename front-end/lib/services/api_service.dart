import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://lokseva-connect.onrender.com';

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// POST /api/user/profile - Create or update user profile
  Future<UserProfileResponse> saveUserProfile({
    required String email,
    required String name,
    String? profilePic,
    int? age,
    String? phone,
    String? address,
    String? medicalHistory,
  }) async {
    final url = Uri.parse('$baseUrl/api/user/profile');

    final body = {
      'email': email,
      'name': name,
      if (profilePic != null) 'profilePic': profilePic,
      if (age != null) 'age': age,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (medicalHistory != null) 'medicalHistory': medicalHistory,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return UserProfileResponse.fromJson(data['user']);
      } else {
        throw ApiException('Failed to save profile: ${response.body}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  /// POST /api/audit-image - Home Safety Audit
  Future<AuditResponse> auditImage({
    required String imageBase64,
    String? roomType,
    String? userEmail,
  }) async {
    final url = Uri.parse('$baseUrl/api/audit-image');

    final body = {
      'imageBase64': imageBase64,
      if (roomType != null) 'roomType': roomType,
      if (userEmail != null) 'user_email': userEmail,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AuditResponse.fromJson(data);
      } else {
        throw ApiException('${response.statusCode} Audit failed: ${response.body}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  /// POST /api/chat - AI Chat with RAG
  Future<ChatResponse> sendChatMessage({
    required String userEmail,
    required String message,
    String? conversationId,
  }) async {
    final url = Uri.parse('$baseUrl/api/chat');

    final body = {
      'user_email': userEmail,
      'message': message,
      if (conversationId != null) 'conversationId': conversationId,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('📥 Chat Response status: ${response.statusCode}');
      print('📥 Chat Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ChatResponse.fromJson(data);
      } else {
        throw ApiException('Chat failed: ${response.body}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  /// GET /api/chat/history - Fetch chat history
  Future<ChatHistoryResponse> getChatHistory({
    required String userEmail,
    int page = 1,
    int limit = 10,
  }) async {
    final url = Uri.parse(
      '$baseUrl/api/chat/history?user_email=$userEmail&page=$page&limit=$limit',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📥 History Response status: ${response.statusCode}');
      print('📥 History Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ChatHistoryResponse.fromJson(data);
      } else {
        throw ApiException('Failed to fetch history: ${response.body}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }
}



// =============================================================================
// RESPONSE MODELS (FIXED)
// =============================================================================

class UserProfileResponse {
  final String email;
  final String name;
  final String? profilePic;
  final int? age;
  final String? phone;
  final String? address;
  final String? medicalHistory;
  final bool isComplete;

  UserProfileResponse({
    required this.email,
    required this.name,
    this.profilePic,
    this.age,
    this.phone,
    this.address,
    this.medicalHistory,
    required this.isComplete,
  });

  factory UserProfileResponse.fromJson(Map<String, dynamic> json) {
    // Parse age - handle both int and String
    int? parsedAge;
    if (json['age'] != null) {
      parsedAge = json['age'] is int
          ? json['age']
          : int.tryParse(json['age'].toString());
    }

    // Parse phone - ensure it's a String
    String? parsedPhone;
    if (json['phone'] != null) {
      parsedPhone = json['phone'].toString();
    }

    return UserProfileResponse(
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      profilePic: json['profilePic'],
      age: parsedAge,
      phone: parsedPhone,
      address: json['address'],
      medicalHistory: json['medicalHistory'],
      // Profile is complete if age, phone, and address are filled
      isComplete: json['age'] != null &&
          json['phone'] != null &&
          json['address'] != null &&
          json['phone'].toString().isNotEmpty &&
          json['address'].toString().isNotEmpty,
    );
  }

  @override
  String toString() {
    return 'UserProfileResponse(email: $email, name: $name, age: $age, isComplete: $isComplete)';
  }
}


class AuditResponse {
  final int safetyScore;
  final List<String> hazards;
  final List<String> recommendations;
  final String summary;

  AuditResponse({
    required this.safetyScore,
    required this.hazards,
    required this.recommendations,
    required this.summary,
  });

  factory AuditResponse.fromJson(Map<String, dynamic> json) {
    // Handle stringified JSON in 'audit_report'
    if (json.containsKey('audit_report')) {
      final reportString = json['audit_report'];
      final report = jsonDecode(reportString);  // Parse the stringified JSON
      return AuditResponse(
        safetyScore: report['safety_score'] ?? -1,
        hazards: List<String>.from(report['hazards'] ?? []),
        recommendations: List<String>.from(report['recommendations'] ?? []),
        summary: report['summary'] ?? '',
      );
    }

    // Fallback for direct JSON
    return AuditResponse(
      safetyScore: json['safety_score'] ?? json['safetyScore'] ?? -1,
      hazards: List<String>.from(json['hazards'] ?? []),
      recommendations: List<String>.from(json['recommendations'] ?? []),
      summary: json['summary'] ?? '',
    );
  }
}

class ChatResponse {
  final String reply;
  final String conversationId;
  final String? title;
  final List<Recommendation> recommendations;

  ChatResponse({
    required this.reply,
    required this.conversationId,
    this.title,
    required this.recommendations,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      reply: json['reply'] ?? '',
      conversationId: json['conversationId'] ?? '',
      title: json['title'],
      recommendations: (json['recommendations'] as List<dynamic>?)
          ?.map((r) => Recommendation.fromJson(r))
          .toList() ??
          [],
    );
  }
}

class Recommendation {
  final String name;
  final double rating;
  final String location;
  final String reason;

  Recommendation({
    required this.name,
    required this.rating,
    required this.location,
    required this.reason,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      name: json['name'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      location: json['location'] ?? '',
      reason: json['reason'] ?? '',
    );
  }
}

class ChatHistoryResponse {
  final List<ChatHistoryItem> history;
  final bool hasMore;

  ChatHistoryResponse({
    required this.history,
    required this.hasMore,
  });

  factory ChatHistoryResponse.fromJson(Map<String, dynamic> json) {
    return ChatHistoryResponse(
      history: (json['history'] as List<dynamic>?)
          ?.map((h) => ChatHistoryItem.fromJson(h))
          .toList() ??
          [],
      hasMore: json['hasMore'] ?? false,
    );
  }
}

class ChatHistoryItem {
  final String conversationId;
  final String title;
  final DateTime date;
  final String lastMessage;

  ChatHistoryItem({
    required this.conversationId,
    required this.title,
    required this.date,
    required this.lastMessage,
  });

  factory ChatHistoryItem.fromJson(Map<String, dynamic> json) {
    return ChatHistoryItem(
      conversationId: json['conversationId'] ?? '',
      title: json['title'] ?? 'Untitled Chat',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      lastMessage: json['lastMessage'] ?? '',
    );
  }
}

// Local message model for UI
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Recommendation>? recommendations;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.recommendations,
  });
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}