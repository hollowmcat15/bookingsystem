import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'manage_notifications.dart';

class NotificationsPage extends StatefulWidget {
  final String userId;  // This should now be the auth ID
  final String role;

  const NotificationsPage({
    Key? key,
    required this.userId,
    required this.role,
  }) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with SingleTickerProviderStateMixin {
  int _unreadCount = 0;
  late TabController _tabController;
  
  // Add notification settings variables
  bool clientReminders = true;
  bool therapistNotifications = true;
  bool receptionistAlerts = true;
  bool managerFeedback = true;
  TimeOfDay reminderTime = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUnreadCount();
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final count = await NotificationManager.getUnreadCount(
      widget.userId,
      widget.role,
    );
    setState(() {
      _unreadCount = count;
    });
  }

  void _markAsRead(int notificationId) {
    NotificationManager.markAsRead(notificationId).then((_) {
      _loadUnreadCount();
    });
  }

  String _formatDate(String dateString) {
    final dateTime = DateTime.parse(dateString).toLocal();
    return DateFormat('MMM d, h:mm a').format(dateTime);
  }

  Future<void> _loadSettings() async {
    final settings = await NotificationManager.getNotificationSettings(widget.userId);
    setState(() {
      clientReminders = settings['clientReminders'] ?? true;
      therapistNotifications = settings['therapistNotifications'] ?? true;
      receptionistAlerts = settings['receptionistAlerts'] ?? true;
      managerFeedback = settings['managerFeedback'] ?? true;
      reminderTime = TimeOfDay(
        hour: settings['reminderHour'] ?? 8,
        minute: settings['reminderMinute'] ?? 0,
      );
    });
  }

  Future<void> _saveSettings() async {
    await NotificationManager.saveNotificationSettings(
      widget.userId,
      {
        'clientReminders': clientReminders,
        'therapistNotifications': therapistNotifications,
        'receptionistAlerts': receptionistAlerts,
        'managerFeedback': managerFeedback,
        'reminderHour': reminderTime.hour,
        'reminderMinute': reminderTime.minute,
      },
    );
  }

  Widget _buildNotificationsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: NotificationManager.getNotifications(widget.userId, widget.role),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final notifications = snapshot.data!;
        
        // Sort notifications by created_at in descending order (newest first)
        notifications.sort((a, b) {
          final aDate = DateTime.parse(a['created_at']);
          final bDate = DateTime.parse(b['created_at']);
          return bDate.compareTo(aDate); // Descending order
        });
        
        if (notifications.isEmpty) {
          return const Center(
            child: Text('No notifications'),
          );
        }

        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            final isRead = notification['is_read'] ?? false;
            
            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              child: ListTile(
                title: Text(
                  notification['title'],
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification['message']),
                    Text(
                      _formatDate(notification['created_at']),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                leading: CircleAvatar(
                  child: Icon(
                    isRead ? Icons.notifications : Icons.notifications_active,
                  ),
                ),
                onTap: () {
                  if (!isRead) {
                    _markAsRead(notification['notification_id']);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsSection() {
    switch (widget.role) {
      case 'client':
        return Column(
          children: [
            SwitchListTile(
              title: const Text('Appointment Reminders'),
              subtitle: const Text('Receive reminders for upcoming appointments'),
              value: clientReminders,
              onChanged: (value) {
                setState(() {
                  clientReminders = value;
                  _saveSettings();
                });
              },
            ),
            ListTile(
              title: const Text('Reminder Time'),
              subtitle: Text('${reminderTime.format(context)}'),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: reminderTime,
                );
                if (picked != null) {
                  setState(() {
                    reminderTime = picked;
                    _saveSettings();
                  });
                }
              },
            ),
          ],
        );
      
      case 'therapist':
        return Column(
          children: [
            SwitchListTile(
              title: const Text('New Appointment Alerts'),
              subtitle: const Text('Get notified when you receive new bookings'),
              value: therapistNotifications,
              onChanged: (value) {
                setState(() {
                  therapistNotifications = value;
                  _saveSettings();
                });
              },
            ),
            SwitchListTile(
              title: const Text('Daily Schedule Reminders'),
              subtitle: const Text('Receive your daily appointment schedule'),
              value: clientReminders, // Reusing client setting for daily reminders
              onChanged: (value) {
                setState(() {
                  clientReminders = value;
                  _saveSettings();
                });
              },
            ),
            ListTile(
              title: const Text('Schedule Notification Time'),
              subtitle: Text('${reminderTime.format(context)}'),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: reminderTime,
                );
                if (picked != null) {
                  setState(() {
                    reminderTime = picked;
                    _saveSettings();
                  });
                }
              },
            ),
          ],
        );

      case 'receptionist':
        return Column(
          children: [
            SwitchListTile(
              title: const Text('New Booking Notifications'),
              subtitle: const Text('Get notified of new appointments'),
              value: receptionistAlerts,
              onChanged: (value) {
                setState(() {
                  receptionistAlerts = value;
                  _saveSettings();
                });
              },
            ),
            SwitchListTile(
              title: const Text('Schedule Changes'),
              subtitle: const Text('Get notified of appointment changes or cancellations'),
              value: therapistNotifications, // Reusing therapist setting for changes
              onChanged: (value) {
                setState(() {
                  therapistNotifications = value;
                  _saveSettings();
                });
              },
            ),
            SwitchListTile(
              title: const Text('Daily Summary'),
              subtitle: const Text('Receive daily appointment summaries'),
              value: clientReminders, // Reusing client setting for summaries
              onChanged: (value) {
                setState(() {
                  clientReminders = value;
                  _saveSettings();
                });
              },
            ),
          ],
        );

      case 'manager':
        return Column(
          children: [
            SwitchListTile(
              title: const Text('New Feedback Alerts'),
              subtitle: const Text('Get notified when clients leave reviews'),
              value: managerFeedback,
              onChanged: (value) {
                setState(() {
                  managerFeedback = value;
                  _saveSettings();
                });
              },
            ),
            SwitchListTile(
              title: const Text('Booking Updates'),
              subtitle: const Text('Get notified of new bookings and changes'),
              value: receptionistAlerts, // Reusing receptionist setting for bookings
              onChanged: (value) {
                setState(() {
                  receptionistAlerts = value;
                  _saveSettings();
                });
              },
            ),
            SwitchListTile(
              title: const Text('Daily Reports'),
              subtitle: const Text('Receive daily business summaries'),
              value: clientReminders, // Reusing client setting for reports
              onChanged: (value) {
                setState(() {
                  clientReminders = value;
                  _saveSettings();
                });
              },
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications ${_unreadCount > 0 ? "($_unreadCount)" : ""}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Notifications'),
            Tab(text: 'Settings'),
          ],
        ),
        actions: [
          // Add test actions in debug mode
          if (const bool.fromEnvironment('dart.vm.product') == false)
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'test',
                  child: const Text('Create Test Notifications'),
                ),
                PopupMenuItem(
                  value: 'clear',
                  child: const Text('Clear All Notifications'),
                ),
              ],
              onSelected: (value) async {
                if (value == 'test') {
                  await NotificationManager.createTestNotifications(
                    widget.userId,
                    widget.role,
                  );
                } else if (value == 'clear') {
                  await NotificationManager.clearAllNotifications(
                    widget.userId,
                    widget.role,
                  );
                }
                await _loadUnreadCount();
              },
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationsList(),
          ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Notification Preferences',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              _buildSettingsSection(),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Note: Some notifications are essential and cannot be disabled.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}