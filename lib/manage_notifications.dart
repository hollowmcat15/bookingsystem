import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum NotificationType {
  appointmentReminder,
  newFeedback,
  dailySummary,
  newAppointment,
}

class NotificationManager {
  static final supabase = Supabase.instance.client;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initializeNotifications() async {
    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(initSettings);
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const iosDetails = DarwinNotificationDetails();
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }

  static String _formatTimeString(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  // Enhanced method to be more specific about notification types
  static Future<void> checkTodayAppointments(String userId, String role) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Get user's auth ID from role table
      final userResponse = await supabase
          .from(role)
          .select('auth_id')
          .eq('${role}_id', userId)
          .single();
      
      if (userResponse == null || userResponse['auth_id'] == null) return;
      final authId = userResponse['auth_id'];

      // Query appointments with more details
      final response = await supabase
          .from('appointment')
          .select('''
            *,
            client:client_id(first_name, last_name),
            service:service_id(service_name),
            therapist:therapist_id(first_name, last_name),
            spa:spa_id(spa_name)
          ''')
          .eq(role == 'client' ? 'client_id' : '${role}_id', userId)
          .eq('booking_date', today)
          .eq('status', 'Scheduled');  // Only get scheduled appointments

      if (response == null || response.isEmpty) return;

      for (final booking in response) {
        final startTime = DateTime.parse(booking['booking_start_time']);
        final formattedTime = _formatTimeString(startTime);
        String message;
        String title;

        switch (role) {
          case 'client':
            title = 'Appointment Today';
            message = 'Reminder: Your appointment is today at $formattedTime';
            if (booking['therapist'] != null) {
              message += ' with ${booking['therapist']['first_name']} ${booking['therapist']['last_name']}';
            }
            break;
          case 'therapist':
            title = 'Upcoming Appointment';
            message = 'You have an appointment with ${booking['client']['first_name']} ${booking['client']['last_name']} at $formattedTime';
            break;
          case 'receptionist':
            title = 'Scheduled Appointment';
            message = 'Client ${booking['client']['first_name']} ${booking['client']['last_name']} has an appointment at $formattedTime';
            break;
          default:
            continue;
        }

        await createNotification(
          userId: authId,
          userRole: role,
          title: title,
          message: message,
          type: NotificationType.appointmentReminder,
        );
      }
    } catch (e) {
      print('Error checking appointments: $e');
    }
  }

  // For Receptionist appointment notifications
  static Future<void> checkReceptionistAppointments(String userId) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final response = await supabase
          .from('bookings')
          .select('''
            *,
            spas!inner(receptionist_id)
          ''')
          .eq('spas.receptionist_id', userId)
          .eq('booking_date', today);

      if (response != null && response.isNotEmpty) {
        for (final booking in response) {
          final startTime = DateTime.parse(booking['booking_start_time']);
          final formattedTime = _formatTimeString(startTime);

          await supabase.from('notification').insert({
            'user_id': userId,
            'user_role': 'receptionist',
            'title': 'Scheduled Appointment',
            'message': 'You have a scheduled appointment at $formattedTime today.',
            'is_read': false,
          });
        }
      }
    } catch (e) {
      print('Error checking receptionist appointments: $e');
    }
  }

  // Enhanced feedback notification method
  static Future<void> createFeedbackNotification({
    required String managerId,
    required String clientName,
    String? feedbackSummary,  // Optional brief summary
  }) async {
    try {
      final managerResponse = await supabase
          .from('manager')
          .select('auth_id')
          .eq('manager_id', managerId)
          .single();

      if (managerResponse == null || managerResponse['auth_id'] == null) return;

      final message = feedbackSummary != null 
          ? 'New feedback from $clientName: "$feedbackSummary"'
          : 'New feedback received from $clientName';

      await createNotification(
        userId: managerResponse['auth_id'],
        userRole: 'manager',
        title: 'New Feedback',
        message: message,
        type: NotificationType.newFeedback,
      );
    } catch (e) {
      print('Error creating feedback notification: $e');
    }
  }

  // For new appointment notifications
  static Future<void> createNewAppointmentNotification({
    required String clientName,
    required String therapistName,
    required DateTime appointmentTime,
    required String spaName,
    required Map<String, dynamic> recipientIds, // Change type to allow dynamic values
  }) async {
    try {
      final formattedTime = _formatTimeString(appointmentTime);
      final formattedDate = DateFormat('MMM d, yyyy').format(appointmentTime);

      for (final entry in recipientIds.entries) {
        final role = entry.key;
        final userId = entry.value?.toString() ?? ''; // Convert value to string safely
        
        // Skip if userId is empty
        if (userId.isEmpty) continue;

        String title;
        String message;

        switch (role) {
          case 'client':
            title = 'New Appointment Scheduled';
            message = 'Your appointment with $therapistName is scheduled for $formattedTime on $formattedDate at $spaName';
            break;
          case 'therapist':
            title = 'New Appointment';
            message = 'New appointment with $clientName scheduled for $formattedTime on $formattedDate';
            break;
          case 'receptionist':
            title = 'New Booking';
            message = 'New appointment: $clientName with $therapistName at $formattedTime on $formattedDate';
            break;
          case 'manager':
            title = 'New Booking';
            message = 'New appointment scheduled at $spaName for $formattedTime on $formattedDate';
            break;
          default:
            continue;
        }

        await createNotification(
          userId: userId,
          userRole: role,
          title: title,
          message: message,
          type: NotificationType.newAppointment,
        );
      }
    } catch (e) {
      print('Error creating new appointment notification: $e');
    }
  }

  // Update all stream methods to use proper filtering
  static Stream<List<Map<String, dynamic>>> getNotifications(String userId, String role) {
    return supabase
        .from('notification')
        .stream(primaryKey: ['notification_id'])
        .order('created_at')
        .map((data) {
          final List<Map<String, dynamic>> notifications = List<Map<String, dynamic>>.from(data);
          return notifications.where((notification) =>
            notification['user_id'] == userId &&
            notification['user_role'] == role
          ).toList();
        });
  }

  static Stream<List<Map<String, dynamic>>> getNotificationsByType(String userId, String role, String type) {
    final authId = supabase.auth.currentUser?.id;
    if (authId == null) return const Stream.empty();

    return supabase
        .from('notification')
        .stream(primaryKey: ['notification_id'])
        .order('created_at')
        .map((data) {
          final List<Map<String, dynamic>> notifications = List<Map<String, dynamic>>.from(data);
          return notifications.where((notification) =>
            notification['user_id'] == authId &&
            notification['user_role'] == role &&
            notification['type'] == type
          ).toList();
        });
  }

  static Stream<List<Map<String, dynamic>>> getUnreadNotifications(String userId, String role) {
    final authId = supabase.auth.currentUser?.id;
    if (authId == null) return const Stream.empty();

    return supabase
        .from('notification')
        .stream(primaryKey: ['notification_id'])
        .execute()
        .map((data) {
          return (data as List<dynamic>)
              .where((item) => 
                item['user_id'] == authId && 
                item['user_role'] == role &&
                item['is_read'] == false)
              .toList()
              .cast<Map<String, dynamic>>();
        });
  }

  static Future<void> markAsRead(int notificationId) async {
    await supabase
        .from('notification')
        .update({'is_read': true})
        .eq('notification_id', notificationId);
  }

  static Future<int> getUnreadCount(String userId, String role) async {
    final authId = supabase.auth.currentUser?.id;
    if (authId == null) return 0;

    final response = await supabase
        .from('notification')
        .select()
        .eq('user_id', authId)
        .eq('user_role', role)
        .eq('is_read', false);
    
    return response.length;
  }

  // Add this new method
  static Future<void> scheduleAppointmentNotification({
    required DateTime appointmentDateTime,
    required String clientName,
    required String therapistName,
    required String userId,
    required String userRole,
    required int appointmentId,
  }) async {
    try {
      // Get user's auth ID based on role and ID
      String? authId;
      final userResponse = await supabase
          .from(userRole)
          .select('auth_id')
          .eq('${userRole}_id', userId)
          .single();
      
      if (userResponse != null) {
        authId = userResponse['auth_id'];
      }

      if (authId == null) return;

      final formattedTime = _formatTimeString(appointmentDateTime);
      String title;
      String message;

      switch (userRole) {
        case 'client':
          title = 'Appointment Reminder';
          message = 'Your appointment is scheduled for $formattedTime';
          if (therapistName.isNotEmpty) {
            message += ' with $therapistName';
          }
          break;
        case 'therapist':
          title = 'Upcoming Appointment';
          message = 'You have an appointment with $clientName at $formattedTime';
          break;
        case 'receptionist':
          title = 'Appointment Schedule';
          message = 'Client $clientName has an appointment at $formattedTime';
          break;
        default:
          return;
      }

      await supabase.from('notification').insert({
        'user_id': authId,
        'user_role': userRole,
        'title': title,
        'message': message,
        'is_read': false,
        'type': 'appointment_reminder',
      });

    } catch (e) {
      print('Error scheduling appointment notification: $e');
    }
  }

  // Get notification settings for a user
  static Future<Map<String, dynamic>> getNotificationSettings(String userId) async {
    try {
      // Get current user's auth ID
      final authId = supabase.auth.currentUser?.id;
      if (authId == null) return _getDefaultSettings();

      final response = await supabase
          .from('user_notification_settings')
          .select()
          .eq('user_id', authId)
          .single();
      
      // Return settings if found, otherwise return defaults
      return (response?['settings'] as Map<String, dynamic>?) ?? _getDefaultSettings();
    } catch (e) {
      print('Error fetching notification settings: $e');
      return _getDefaultSettings();
    }
  }

  // Save notification settings for a user
  static Future<void> saveNotificationSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    try {
      // Get current user's auth ID
      final authId = supabase.auth.currentUser?.id;
      if (authId == null) return;

      await supabase
          .from('user_notification_settings')
          .upsert({
            'user_id': authId,
            'settings': settings,
            'updated_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Error saving notification settings: $e');
      rethrow;
    }
  }

  // Helper method for default settings
  static Map<String, dynamic> _getDefaultSettings() {
    return {
      'clientReminders': true,
      'therapistNotifications': true,
      'receptionistAlerts': true,
      'managerFeedback': true,
      'reminderHour': 8,
      'reminderMinute': 0,
    };
  }

  // Update the subscription method to use correct Supabase syntax
  static void subscribeToNotifications() {
    final channel = supabase.channel('notifications');
    
    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notification',
        callback: (payload) {
          print('New notification: $payload');
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'notification',
        callback: (payload) {
          print('Updated notification: $payload');
        },
      )
      .subscribe();
  }

  // Add this method for simple notification creation
  static Future<void> createNotification({
    required String userId,
    required String userRole,
    required String title,
    required String message,
    required NotificationType type,
  }) async {
    try {
      // Create database notification
      await supabase.from('notification').insert({
        'user_id': userId,
        'user_role': userRole,
        'title': title,
        'message': message,
        'is_read': false,
        'type': type.name,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Show system notification
      await showLocalNotification(
        title: title,
        body: message,
      );
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // Test method to create sample notifications
  static Future<void> createTestNotifications(String userId, String role) async {
    try {
      final authId = supabase.auth.currentUser?.id;
      if (authId == null) return;

      // Test appointment reminder
      await createNotification(
        userId: authId,
        userRole: role,
        title: 'Test Appointment',
        message: 'This is a test appointment reminder',
        type: NotificationType.appointmentReminder,
      );

      // Test feedback notification (for managers)
      if (role == 'manager') {
        await createNotification(
          userId: authId,
          userRole: role,
          title: 'Test Feedback',
          message: 'This is a test feedback notification',
          type: NotificationType.newFeedback,
        );
      }

      // Test daily summary
      await createNotification(
        userId: authId,
        userRole: role,
        title: 'Test Daily Summary',
        message: 'This is a test daily summary notification',
        type: NotificationType.dailySummary,
      );
    } catch (e) {
      print('Error creating test notifications: $e');
    }
  }

  // Add method to clear all notifications (for testing)
  static Future<void> clearAllNotifications(String userId, String role) async {
    try {
      final authId = supabase.auth.currentUser?.id;
      if (authId == null) return;

      await supabase
          .from('notification')
          .delete()
          .match({
            'user_id': authId,
            'user_role': role,
          });
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }

  // Update method to handle initial notifications on login
  static Future<void> checkInitialNotifications(String userId, String role) async {
    await checkTodayAppointments(userId, role);
    
    if (role == 'receptionist') {
      await checkReceptionistAppointments(userId);
    }
    
    // For managers, we might want to check for unread feedback
    if (role == 'manager') {
      await checkUnreadFeedback(userId);
    }
  }

  // Add method to check unread feedback for managers
  static Future<void> checkUnreadFeedback(String managerId) async {
    try {
      final managerResponse = await supabase
          .from('manager')
          .select('auth_id')
          .eq('manager_id', managerId)
          .single();

      if (managerResponse == null || managerResponse['auth_id'] == null) return;

      final feedbackResponse = await supabase
          .from('feedback')
          .select('*, client:client_id(first_name, last_name)')
          .eq('notified', false);

      for (final feedback in feedbackResponse) {
        final clientName = '${feedback['client']['first_name']} ${feedback['client']['last_name']}';
        await createFeedbackNotification(
          managerId: managerId,
          clientName: clientName,
          feedbackSummary: feedback['feedback_text'],
        );

        // Mark feedback as notified
        await supabase
            .from('feedback')
            .update({'notified': true})
            .eq('feedback_id', feedback['feedback_id']);
      }
    } catch (e) {
      print('Error checking unread feedback: $e');
    }
  }
}