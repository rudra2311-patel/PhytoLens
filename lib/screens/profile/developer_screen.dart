import 'package:flutter/material.dart';
import '../../services/translation_service.dart';

/// Developer/Debug Screen for Translation Cache Management
/// Shows cache statistics and allows cache clearing
class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  CacheStats? _cacheStats;
  bool _isLoading = true;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  Future<void> _loadCacheStats() async {
    setState(() => _isLoading = true);

    final stats = await TranslationService.getCacheStats();

    setState(() {
      _cacheStats = stats;
      _isLoading = false;
    });
  }

  Future<void> _clearCache({String? language}) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Translation Cache?'),
        content: Text(
          language != null
              ? 'This will clear all cached translations for ${TranslationService.getLanguageName(language)}. They will be re-fetched from the API on next use.'
              : 'This will clear ALL cached translations. They will be re-fetched from the API on next use.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isClearing = true);

    final success = await TranslationService.clearCache(language: language);

    setState(() => _isClearing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Cache cleared successfully' : 'Failed to clear cache',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }

    if (success) {
      _loadCacheStats(); // Refresh stats
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Settings'),
        backgroundColor: Colors.blueGrey[800],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCacheStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 24),

                    // Cache Statistics Card
                    if (_cacheStats != null) _buildCacheStatsCard(),

                    const SizedBox(height: 24),

                    // Cache Management Section
                    _buildCacheManagementSection(),

                    const SizedBox(height: 24),

                    // Info Section
                    _buildInfoSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Card(
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.developer_mode, size: 40, color: Colors.blueGrey[700]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Translation Cache',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Monitor and manage Redis caching',
                    style: TextStyle(fontSize: 14, color: Colors.blueGrey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheStatsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Cache Statistics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildStatRow(
              'Total Translations',
              '${_cacheStats!.totalCachedTranslations}',
              Icons.text_fields,
              Colors.blue,
            ),
            _buildStatRow(
              'Memory Used',
              _cacheStats!.memoryUsed,
              Icons.memory,
              Colors.orange,
            ),
            _buildStatRow(
              'Cache TTL',
              '${_cacheStats!.cacheTtlHours} hours',
              Icons.timer,
              Colors.green,
            ),
            _buildStatRow(
              'Cost Saved',
              _cacheStats!.estimatedCostSaved,
              Icons.savings,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheManagementSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cleaning_services, color: Colors.red[700]),
                const SizedBox(width: 8),
                const Text(
                  'Cache Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Clear All Cache Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isClearing ? null : () => _clearCache(),
                icon: _isClearing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_sweep),
                label: const Text('Clear All Cache'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Clear by Language (Example: Hindi)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isClearing
                    ? null
                    : () => _clearCache(language: 'hi'),
                icon: const Icon(Icons.language),
                label: const Text('Clear Hindi Cache Only'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'How Caching Works',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoItem('⚡ Cache Hit', '~5ms response time, ₹0 cost'),
            _buildInfoItem(
              '🌐 Cache Miss',
              '~250ms response time, ₹0.125 cost',
            ),
            _buildInfoItem('🔄 Auto-refresh', 'Cache expires after 24 hours'),
            _buildInfoItem('💾 Storage', 'Redis in-memory cache'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: Colors.blueGrey[900]),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
