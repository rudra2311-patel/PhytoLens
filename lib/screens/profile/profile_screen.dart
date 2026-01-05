import 'package:flutter/material.dart';
import '../../services/auth_services.dart';
import '../../services/api_services.dart';
import '../../services/farm_database_helper.dart';
import '../auth/login_screen.dart';
import '../alerts/notification_settings_screen.dart';
import 'developer_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _farmsCount = 0;
  int _scansCount = 0;
  int _alertsCount = 0;
  bool _isLoading = true;
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _username = '';

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    try {
      // Try to get profile from backend
      Map<String, dynamic>? profile;
      try {
        profile = await ApiService.getUserProfile();
        setState(() {
          _firstName = profile!['first_name'] ?? '';
          _lastName = profile['last_name'] ?? '';
          _email = profile['email'] ?? '';
          _username = profile['username'] ?? '';
        });
      } catch (profileError) {
        debugPrint('❌ Failed to load profile from backend: $profileError');
        // Show error message to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load profile: ${profileError.toString()}',
              ),
              duration: const Duration(seconds: 5),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
        // Use empty data on error
        setState(() {
          _firstName = '';
          _lastName = '';
          _email = '';
          _username = 'User';
        });
      }

      final farmsCount = await FarmDatabaseHelper.instance.getFarmsCount();
      final alertsCount = await FarmDatabaseHelper.instance
          .getUnreadAlertsCount();

      setState(() {
        _farmsCount = farmsCount;
        _scansCount = 0; // Will be updated when scan API is integrated
        _alertsCount = alertsCount;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load statistics: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Call backend logout API to revoke token
      try {
        await ApiService.logoutUser();
      } catch (e) {
        debugPrint('⚠️ Backend logout failed: $e');
      }

      // SECURITY FIX: Clear local database before logout
      try {
        await FarmDatabaseHelper.instance.clearAllUserData();
        debugPrint('✅ Local database cleared');
      } catch (e) {
        debugPrint('⚠️ Failed to clear database: $e');
      }

      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildProfileHeader(),
                _buildStatisticsCard(),
                _buildSettingsSection(),
                _buildHelpSection(),
                _buildAppInfoSection(),
                _buildLogoutButton(),
              ],
            ),
    );
  }

  Widget _buildProfileHeader() {
    final bool isBackendConfigured = _username != 'Backend Setup Required';
    final initials = _firstName.isNotEmpty && _lastName.isNotEmpty
        ? '${_firstName[0]}${_lastName[0]}'.toUpperCase()
        : _username.isNotEmpty && isBackendConfigured
        ? _username.substring(0, 2).toUpperCase()
        : '⚙️';
    final displayName = _firstName.isNotEmpty && _lastName.isNotEmpty
        ? '$_firstName $_lastName'
        : _username.isNotEmpty && isBackendConfigured
        ? _username
        : '⚠️ Backend Setup Required';
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF4CAF50),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 36,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _email.isNotEmpty ? _email : 'No email',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit profile feature coming soon'),
                ),
              );
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 STATISTICS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Farms',
                  _farmsCount.toString(),
                  Icons.agriculture,
                ),
                _buildStatItem(
                  'Scans',
                  _scansCount.toString(),
                  Icons.photo_camera,
                ),
                _buildStatItem(
                  'Alerts',
                  _alertsCount.toString(),
                  Icons.notifications,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: const Color(0xFF4CAF50)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '⚙️ SETTINGS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ),
        _buildListTile(Icons.person, 'Account Settings', () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account settings coming soon')),
          );
        }),
        _buildListTile(Icons.notifications, 'Notifications', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationSettingsScreen(),
            ),
          );
        }),
        _buildListTile(Icons.language, 'Language', () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Language settings coming soon')),
          );
        }),
        _buildListTile(Icons.agriculture, 'Default Crop', () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Default crop settings coming soon')),
          );
        }),
        _buildListTile(Icons.location_on, 'Location Access', () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location settings coming soon')),
          );
        }),
        _buildListTile(Icons.palette, 'Theme', () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Theme settings coming soon')),
          );
        }),
        _buildListTile(
          Icons.developer_mode,
          'Developer Settings',
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DeveloperScreen()),
            );
          },
          subtitle: 'Cache stats & management',
        ),
      ],
    );
  }

  Widget _buildHelpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '📚 HELP & SUPPORT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ),
        _buildListTile(Icons.help, 'How to Use', () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Tutorial coming soon')));
        }),
        _buildListTile(Icons.menu_book, 'Disease Guide', () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Disease guide coming soon')),
          );
        }),
        _buildListTile(Icons.chat, 'Contact Support', () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Support coming soon')));
        }),
        _buildListTile(Icons.star, 'Rate App', () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Rate app coming soon')));
        }),
        _buildListTile(Icons.privacy_tip, 'Privacy Policy', () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Privacy policy coming soon')),
          );
        }),
        _buildListTile(Icons.description, 'Terms of Service', () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Terms coming soon')));
        }),
      ],
    );
  }

  Widget _buildAppInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'ℹ️ APP INFO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ),
        ListTile(
          title: const Text('Version'),
          trailing: const Text('1.0.0', style: TextStyle(color: Colors.grey)),
        ),
        ListTile(
          title: const Text('Last Updated'),
          trailing: const Text(
            'Jan 2025',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF4CAF50)),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            )
          : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
