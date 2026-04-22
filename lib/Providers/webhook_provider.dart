import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_webhook.dart';
import 'package:coqui_app/Models/coqui_webhook_delivery.dart';
import 'package:coqui_app/Models/coqui_webhook_stats.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

class WebhookProvider extends ChangeNotifier {
  final CoquiApiService _apiService;

  List<CoquiWebhook> _webhooks = [];
  CoquiWebhookStats _stats = CoquiWebhookStats.empty;
  final Map<String, CoquiWebhook> _detailsById = {};
  final Map<String, List<CoquiWebhookDelivery>> _deliveriesByWebhookId = {};
  final Set<String> _loadingDetailIds = {};
  final Set<String> _mutatingIds = {};

  bool _isLoading = false;
  bool _isCreating = false;
  String? _error;
  bool? _enabledFilter;

  WebhookProvider({required CoquiApiService apiService})
      : _apiService = apiService;

  List<CoquiWebhook> get webhooks => _webhooks;
  CoquiWebhookStats get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get error => _error;
  bool? get enabledFilter => _enabledFilter;

  CoquiWebhook? webhookById(String id) =>
      _detailsById[id] ??
      _webhooks.cast<CoquiWebhook?>().firstWhere(
            (webhook) => webhook?.id == id,
            orElse: () => null,
          );

  List<CoquiWebhookDelivery> deliveriesForWebhook(String webhookId) =>
      List.unmodifiable(_deliveriesByWebhookId[webhookId] ?? const []);

  bool isDetailLoading(String webhookId) =>
      _loadingDetailIds.contains(webhookId);

  bool isMutating(String webhookId) => _mutatingIds.contains(webhookId);

  Future<void> fetchWebhooks({bool? enabled, bool silent = false}) async {
    _enabledFilter = enabled;
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final result = await _apiService.listWebhooks(enabled: enabled);
      _webhooks = result.webhooks;
      _stats = result.stats;
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

  Future<CoquiWebhook?> loadWebhookDetail(
    String id, {
    bool force = false,
  }) async {
    if (_loadingDetailIds.contains(id)) return webhookById(id);
    if (!force && _detailsById.containsKey(id)) return _detailsById[id];

    _loadingDetailIds.add(id);
    notifyListeners();

    try {
      final webhook = await _apiService.getWebhook(id);
      _detailsById[id] = webhook;
      _replaceWebhook(webhook);
      _error = null;
      return webhook;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _loadingDetailIds.remove(id);
      notifyListeners();
    }
  }

  Future<CoquiWebhook?> createWebhook({
    required String name,
    required String promptTemplate,
    required String source,
    required String role,
    String? profile,
    int maxIterations = 48,
    String? description,
    String? eventFilter,
    bool enabled = true,
  }) async {
    _isCreating = true;
    _error = null;
    notifyListeners();

    try {
      final webhook = await _apiService.createWebhook(
        name: name,
        promptTemplate: promptTemplate,
        source: source,
        role: role,
        profile: profile,
        maxIterations: maxIterations,
        description: description,
        eventFilter: eventFilter,
      );
      final normalized = enabled == webhook.enabled
          ? webhook
          : await _apiService.updateWebhook(webhook.id, enabled: enabled);
      _detailsById[normalized.id] = normalized;
      _webhooks = [
        normalized,
        ..._webhooks.where((item) => item.id != normalized.id)
      ];
      _stats = CoquiWebhookStats(
        total: _stats.total + 1,
        enabled: _stats.enabled + (normalized.enabled ? 1 : 0),
        disabled: _stats.disabled + (normalized.enabled ? 0 : 1),
        totalTriggers: _stats.totalTriggers,
      );
      notifyListeners();
      return normalized;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<CoquiWebhook?> updateWebhook(
    String id, {
    String? name,
    String? description,
    String? source,
    String? promptTemplate,
    String? role,
    String? profile,
    bool clearProfile = false,
    int? maxIterations,
    bool? enabled,
    String? eventFilter,
  }) async {
    _mutatingIds.add(id);
    _error = null;
    notifyListeners();

    try {
      final webhook = await _apiService.updateWebhook(
        id,
        name: name,
        description: description,
        source: source,
        promptTemplate: promptTemplate,
        role: role,
        profile: profile,
        clearProfile: clearProfile,
        maxIterations: maxIterations,
        enabled: enabled,
        eventFilter: eventFilter,
      );
      _detailsById[id] = webhook;
      _replaceWebhook(webhook);
      unawaited(fetchWebhooks(enabled: _enabledFilter, silent: true));
      return webhook;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingIds.remove(id);
      notifyListeners();
    }
  }

  Future<bool> deleteWebhook(String id) async {
    _mutatingIds.add(id);
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteWebhook(id);
      _webhooks = _webhooks.where((webhook) => webhook.id != id).toList();
      _detailsById.remove(id);
      _deliveriesByWebhookId.remove(id);
      unawaited(fetchWebhooks(enabled: _enabledFilter, silent: true));
      return true;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return false;
    } finally {
      _mutatingIds.remove(id);
      notifyListeners();
    }
  }

  Future<String?> rotateSecret(String id) async {
    _mutatingIds.add(id);
    _error = null;
    notifyListeners();

    try {
      final secret = await _apiService.rotateWebhookSecret(id);
      final existing = webhookById(id);
      if (existing != null) {
        final updated = existing.copyWith(
            secret: secret, updatedAt: DateTime.now().toUtc());
        _detailsById[id] = updated;
        _replaceWebhook(updated);
      }
      return secret;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingIds.remove(id);
      notifyListeners();
      unawaited(loadWebhookDetail(id, force: true));
    }
  }

  Future<void> refreshDeliveries(String id, {int limit = 50}) async {
    try {
      _deliveriesByWebhookId[id] =
          await _apiService.listWebhookDeliveries(id, limit: limit);
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

  void _replaceWebhook(CoquiWebhook webhook) {
    final index = _webhooks.indexWhere((item) => item.id == webhook.id);
    if (index == -1) {
      _webhooks = [webhook, ..._webhooks];
      return;
    }
    _webhooks[index] = webhook;
  }

  void _synchronizeDetails() {
    for (final webhook in _webhooks) {
      _detailsById[webhook.id] = webhook;
    }
  }
}
