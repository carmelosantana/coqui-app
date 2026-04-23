import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:coqui_app/Models/coqui_channel.dart';
import 'package:coqui_app/Models/coqui_channel_conversation.dart';
import 'package:coqui_app/Models/coqui_channel_delivery.dart';
import 'package:coqui_app/Models/coqui_channel_driver.dart';
import 'package:coqui_app/Models/coqui_channel_event.dart';
import 'package:coqui_app/Models/coqui_channel_link.dart';
import 'package:coqui_app/Models/coqui_channel_stats.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

class ChannelProvider extends ChangeNotifier {
  final CoquiApiService _apiService;

  List<CoquiChannel> _channels = [];
  List<CoquiChannelDriver> _drivers = [];
  CoquiChannelStats _stats = CoquiChannelStats.empty;
  CoquiChannelStats _managerStats = CoquiChannelStats.empty;
  final Map<String, CoquiChannel> _detailsById = {};
  final Map<String, List<CoquiChannelConversation>> _conversationsByChannelId =
      {};
  final Map<String, List<CoquiChannelLink>> _linksByChannelId = {};
  final Map<String, List<CoquiChannelEvent>> _eventsByChannelId = {};
  final Map<String, List<CoquiChannelDelivery>> _deliveriesByChannelId = {};
  final Set<String> _loadingDetailIds = {};
  final Set<String> _mutatingIds = {};
  final Set<String> _testingIds = {};
  Timer? _pollTimer;

  bool _isLoading = false;
  bool _isLoadingDrivers = false;
  String? _error;
  bool? _enabledFilter;
  String? _driverFilter;

  ChannelProvider({required CoquiApiService apiService})
      : _apiService = apiService;

  List<CoquiChannel> get channels => _channels;
  List<CoquiChannelDriver> get drivers => _drivers;
  CoquiChannelStats get stats => _stats;
  CoquiChannelStats get managerStats => _managerStats;
  bool get isLoading => _isLoading;
  bool get isLoadingDrivers => _isLoadingDrivers;
  String? get error => _error;
  bool? get enabledFilter => _enabledFilter;
  String? get driverFilter => _driverFilter;

  bool get hasIssues => _channels.any((channel) =>
      channel.hasIssues ||
      channel.consecutiveFailures > 0 ||
      (channel.lastError?.isNotEmpty ?? false));

  bool get hasHealthyChannels => _channels.any((channel) => channel.isHealthy);

  int get activeChannelsCount =>
      _channels.where((channel) => channel.isHealthy).length;

  int get issueChannelsCount => _channels
      .where((channel) =>
          channel.hasIssues ||
          channel.consecutiveFailures > 0 ||
          (channel.lastError?.isNotEmpty ?? false))
      .length;

  CoquiChannel? channelById(String id) =>
      _detailsById[id] ??
      _channels.cast<CoquiChannel?>().firstWhere(
            (channel) => channel?.id == id || channel?.name == id,
            orElse: () => null,
          );

  List<CoquiChannelLink> linksForChannel(String channelId) =>
      List.unmodifiable(_linksByChannelId[channelId] ?? const []);

  List<CoquiChannelConversation> conversationsForChannel(String channelId) =>
      List.unmodifiable(_conversationsByChannelId[channelId] ?? const []);

  List<CoquiChannelEvent> eventsForChannel(String channelId) =>
      List.unmodifiable(_eventsByChannelId[channelId] ?? const []);

  List<CoquiChannelDelivery> deliveriesForChannel(String channelId) =>
      List.unmodifiable(_deliveriesByChannelId[channelId] ?? const []);

  bool isDetailLoading(String channelId) =>
      _loadingDetailIds.contains(channelId);

  bool isMutating(String channelId) => _mutatingIds.contains(channelId);

  bool isTesting(String channelId) => _testingIds.contains(channelId);

  Future<void> fetchChannels({
    bool? enabled,
    String? driver,
    bool silent = false,
  }) async {
    _enabledFilter = enabled;
    _driverFilter = driver;
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final response = await _apiService.listChannels(
        enabled: enabled,
        driver: driver,
      );
      _channels = response.channels;
      _stats = response.stats;
      _managerStats = response.manager;
      _synchronizeDetails();
      _error = null;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> fetchDrivers({bool force = false}) async {
    if (_drivers.isNotEmpty && !force) {
      return;
    }

    _isLoadingDrivers = true;
    notifyListeners();

    try {
      _drivers = await _apiService.listChannelDrivers();
    } catch (e) {
      _error = CoquiException.friendly(e).message;
    } finally {
      _isLoadingDrivers = false;
      notifyListeners();
    }
  }

  Future<void> refreshDashboard({bool silent = false}) async {
    await Future.wait([
      fetchChannels(
        enabled: _enabledFilter,
        driver: _driverFilter,
        silent: silent,
      ),
      fetchDrivers(),
    ]);
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      unawaited(fetchChannels(
        enabled: _enabledFilter,
        driver: _driverFilter,
        silent: true,
      ));
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<CoquiChannel?> loadChannelDetail(
    String id, {
    bool force = false,
  }) async {
    if (_loadingDetailIds.contains(id)) {
      return channelById(id);
    }
    if (!force && _detailsById.containsKey(id)) {
      return _detailsById[id];
    }

    _loadingDetailIds.add(id);
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        _apiService.getChannel(id),
        _apiService.listChannelConversations(id),
        _apiService.listChannelLinks(id),
        _apiService.listChannelEvents(id),
        _apiService.listChannelDeliveries(id),
      ]);
      final channel = results[0] as CoquiChannel;
      _detailsById[channel.id] = channel;
      _replaceChannel(channel);
      _conversationsByChannelId[channel.id] =
          results[1] as List<CoquiChannelConversation>;
      _linksByChannelId[channel.id] = results[2] as List<CoquiChannelLink>;
      _eventsByChannelId[channel.id] = results[3] as List<CoquiChannelEvent>;
      _deliveriesByChannelId[channel.id] =
          results[4] as List<CoquiChannelDelivery>;
      _error = null;
      return channel;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _loadingDetailIds.remove(id);
      notifyListeners();
    }
  }

  Future<CoquiChannel?> createChannel({
    required String name,
    required String driver,
    bool enabled = true,
    String? displayName,
    String? defaultProfile,
    String? boundSessionId,
    Map<String, dynamic>? settings,
    List<String>? allowedScopes,
    Map<String, dynamic>? security,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final channel = await _apiService.createChannel(
        name: name,
        driver: driver,
        enabled: enabled,
        displayName: displayName,
        defaultProfile: defaultProfile,
        boundSessionId: boundSessionId,
        settings: settings,
        allowedScopes: allowedScopes,
        security: security,
      );
      _detailsById[channel.id] = channel;
      _channels = [
        channel,
        ..._channels.where((item) => item.id != channel.id)
      ];
      await fetchChannels(
        enabled: _enabledFilter,
        driver: _driverFilter,
        silent: true,
      );
      return channel;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CoquiChannel?> updateChannel(
    String id, {
    String? driver,
    bool? enabled,
    String? displayName,
    String? defaultProfile,
    String? boundSessionId,
    Map<String, dynamic>? settings,
    List<String>? allowedScopes,
    Map<String, dynamic>? security,
  }) async {
    _mutatingIds.add(id);
    _error = null;
    notifyListeners();

    try {
      final channel = await _apiService.updateChannel(
        id,
        driver: driver,
        enabled: enabled,
        displayName: displayName,
        defaultProfile: defaultProfile,
        boundSessionId: boundSessionId,
        settings: settings,
        allowedScopes: allowedScopes,
        security: security,
      );
      _detailsById[channel.id] = channel;
      _replaceChannel(channel);
      await loadChannelDetail(channel.id, force: true);
      return channel;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingIds.remove(id);
      notifyListeners();
    }
  }

  Future<CoquiChannel?> toggleChannelEnabled(String id, bool enabled) async {
    _mutatingIds.add(id);
    _error = null;
    notifyListeners();

    try {
      final channel = enabled
          ? await _apiService.enableChannel(id)
          : await _apiService.disableChannel(id);
      _detailsById[channel.id] = channel;
      _replaceChannel(channel);
      return channel;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingIds.remove(id);
      notifyListeners();
    }
  }

  Future<CoquiChannel?> testChannel(String id) async {
    _testingIds.add(id);
    _error = null;
    notifyListeners();

    try {
      final channel = await _apiService.testChannel(id);
      _detailsById[channel.id] = channel;
      _replaceChannel(channel);
      await loadChannelDetail(channel.id, force: true);
      return channel;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _testingIds.remove(id);
      notifyListeners();
    }
  }

  Future<bool> deleteChannel(String id) async {
    _mutatingIds.add(id);
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteChannel(id);
      _channels
          .removeWhere((channel) => channel.id == id || channel.name == id);
      _detailsById.remove(id);
      _conversationsByChannelId.remove(id);
      _linksByChannelId.remove(id);
      _eventsByChannelId.remove(id);
      _deliveriesByChannelId.remove(id);
      await fetchChannels(
        enabled: _enabledFilter,
        driver: _driverFilter,
        silent: true,
      );
      return true;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return false;
    } finally {
      _mutatingIds.remove(id);
      notifyListeners();
    }
  }

  Future<CoquiChannelLink?> createLink(
    String channelId, {
    required String remoteUserKey,
    required String profile,
    String? remoteScopeKey,
  }) async {
    _mutatingIds.add(channelId);
    _error = null;
    notifyListeners();

    try {
      final link = await _apiService.createChannelLink(
        channelId,
        remoteUserKey: remoteUserKey,
        profile: profile,
        remoteScopeKey: remoteScopeKey,
      );
      final links =
          List<CoquiChannelLink>.from(_linksByChannelId[channelId] ?? const []);
      links.insert(0, link);
      _linksByChannelId[channelId] = links;
      return link;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingIds.remove(channelId);
      notifyListeners();
    }
  }

  Future<bool> deleteLink(String channelId, String linkId) async {
    _mutatingIds.add(channelId);
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteChannelLink(channelId, linkId);
      final links =
          List<CoquiChannelLink>.from(_linksByChannelId[channelId] ?? const []);
      links.removeWhere((link) => link.id == linkId);
      _linksByChannelId[channelId] = links;
      return true;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return false;
    } finally {
      _mutatingIds.remove(channelId);
      notifyListeners();
    }
  }

  Future<void> refreshActivity(String channelId) async {
    try {
      final results = await Future.wait<dynamic>([
        _apiService.listChannelConversations(channelId),
        _apiService.listChannelEvents(channelId),
        _apiService.listChannelDeliveries(channelId),
      ]);
      _conversationsByChannelId[channelId] =
          results[0] as List<CoquiChannelConversation>;
      _eventsByChannelId[channelId] = results[1] as List<CoquiChannelEvent>;
      _deliveriesByChannelId[channelId] =
          results[2] as List<CoquiChannelDelivery>;
      notifyListeners();
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _replaceChannel(CoquiChannel channel) {
    final index = _channels.indexWhere((item) => item.id == channel.id);
    if (index >= 0) {
      _channels[index] = channel;
    } else {
      _channels = [channel, ..._channels];
    }
  }

  void _synchronizeDetails() {
    for (final channel in _channels) {
      _detailsById[channel.id] = channel;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
