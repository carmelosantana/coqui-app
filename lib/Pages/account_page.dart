import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:coqui_app/Providers/account_provider.dart';
import 'package:coqui_app/Providers/auth_provider.dart';
import 'package:coqui_app/Theme/theme.dart';

/// Account page with profile, subscription, billing, and API token sections.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  @override
  void initState() {
    super.initState();
    // Load account data on first open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AccountProvider>().loadAll(),
          ),
        ],
      ),
      body: Consumer2<AuthProvider, AccountProvider>(
        builder: (context, auth, account, _) {
          if (!auth.isLoggedIn) {
            return const Center(
                child: Text('Please sign in to view your account.'));
          }

          if (account.isLoading && account.plans.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Error banner
              if (account.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: colorScheme.onErrorContainer, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          account.error!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: account.clearError,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Profile section
              _ProfileSection(),
              const SizedBox(height: 16),

              // Subscription section
              _SubscriptionSection(),
              const SizedBox(height: 16),

              // Billing section
              _BillingSection(),
              const SizedBox(height: 16),

              // API Token section
              _TokenSection(),
              const SizedBox(height: 16),

              // Logout
              FilledButton.tonalIcon(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileSection extends StatefulWidget {
  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  final _displayNameController = TextEditingController();
  final _sshKeyController = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _sshKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer2<AuthProvider, AccountProvider>(
      builder: (context, auth, account, _) {
        final profile = account.profile ?? auth.user;
        if (profile == null) return const SizedBox.shrink();

        if (!_editing) {
          _displayNameController.text = profile.displayName ?? '';
          _sshKeyController.text = profile.sshPublicKey ?? '';
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (profile.image != null)
                      CircleAvatar(
                        backgroundImage: NetworkImage(profile.image!),
                        radius: 24,
                      ),
                    if (profile.image != null) const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayLabel,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (profile.email != null)
                            Text(
                              profile.email!,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(_editing ? Icons.close : Icons.edit),
                      onPressed: () => setState(() => _editing = !_editing),
                    ),
                  ],
                ),
                if (_editing) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sshKeyController,
                    decoration: const InputDecoration(
                      labelText: 'SSH Public Key',
                      border: OutlineInputBorder(),
                      hintText: 'ssh-ed25519 AAAA...',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final success = await account.updateProfile(
                        displayName: _displayNameController.text,
                        sshPublicKey: _sshKeyController.text,
                      );
                      if (success && mounted) {
                        setState(() => _editing = false);
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SubscriptionSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<AccountProvider>(
      builder: (context, account, _) {
        final sub = account.activeSubscription;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subscription',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (sub == null) ...[
                  Text(
                    'No active subscription',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.pushNamed(context, '/pricing'),
                    child: const Text('View Plans'),
                  ),
                ] else ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      sub.isActive ? Icons.check_circle : Icons.cancel,
                      color:
                          sub.isActive ? CoquiColors.chart2 : colorScheme.error,
                    ),
                    title: Text(sub.plan?.displayName ?? 'Unknown Plan'),
                    subtitle: Text(sub.displayStatus),
                  ),
                  if (sub.currentPeriodEnd != null)
                    Text(
                      'Current period ends: ${_formatDate(sub.currentPeriodEnd!)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (sub.isActive && !sub.cancelAtPeriodEnd)
                        OutlinedButton(
                          onPressed: () => _showCancelDialog(context, account),
                          child: const Text('Cancel'),
                        ),
                      if (sub.cancelAtPeriodEnd)
                        FilledButton(
                          onPressed: () async {
                            await account.reactivateSubscription();
                          },
                          child: const Text('Reactivate'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCancelDialog(BuildContext context, AccountProvider account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: const Text(
          'Your subscription will remain active until the end of the current billing period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await account.cancelSubscription();
            },
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _BillingSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<AccountProvider>(
      builder: (context, account, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Billing',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final url = await account.getPortalUrl();
                        if (url != null) {
                          await launchUrlString(url);
                        }
                      },
                      child: const Text('Manage in Stripe'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (account.billingEvents.isEmpty)
                  Text(
                    'No billing history',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  )
                else
                  ...account.billingEvents.take(5).map(
                        (event) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(event.displayType),
                          subtitle: Text(event.description ?? ''),
                          trailing: Text(
                            event.formattedAmount,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TokenSection extends StatefulWidget {
  @override
  State<_TokenSection> createState() => _TokenSectionState();
}

class _TokenSectionState extends State<_TokenSection> {
  String? _newToken;
  bool _showToken = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<AccountProvider>(
      builder: (context, account, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'API Token',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use this token to authenticate API requests.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (_newToken != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(CoquiColors.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _showToken
                                ? _newToken!
                                : '${_newToken!.substring(0, 8)}${'•' * 20}',
                            style: textTheme.bodySmall?.copyWith(
                              fontFamily: 'GeistMono',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _showToken
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _showToken = !_showToken),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _newToken!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Token copied')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Regenerate Token?'),
                        content: const Text(
                          'Your current token will stop working immediately.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Regenerate'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      final token = await account.regenerateToken();
                      if (token != null && mounted) {
                        setState(() {
                          _newToken = token;
                          _showToken = true;
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerate Token'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
