import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRealtimeService {
  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static bool _initialized = false;

  static bool get isConfigured =>
      _url.trim().isNotEmpty && _publishableKey.trim().isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured || _initialized) return;
    await Supabase.initialize(
      url: _url.trim(),
      publishableKey: _publishableKey.trim(),
    );
    _initialized = true;
  }

  static RealtimeChannel? subscribeToDriverLocation({
    required String driverUid,
    required void Function(Map<String, dynamic> location) onLocation,
  }) {
    if (!_initialized || driverUid.trim().isEmpty) return null;

    final channel = Supabase.instance.client
        .channel('driver-location:${driverUid.trim()}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_uid',
            value: driverUid.trim(),
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              onLocation(Map<String, dynamic>.from(record));
            }
          },
        )
        .subscribe();

    return channel;
  }

  static Future<void> removeChannel(RealtimeChannel? channel) async {
    if (!_initialized || channel == null) return;
    await Supabase.instance.client.removeChannel(channel);
  }
}
