import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Providers/auth_provider.dart';
import 'package:coqui_app/Theme/theme.dart';

/// Login page with GitHub OAuth button.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App icon
                    ClipRRect(
                      borderRadius: BorderRadius.circular(CoquiColors.radiusLg),
                      child: Image.asset(
                        AppConstants.appIconPng,
                        width: 80,
                        height: 80,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Sign in to CoquiBot',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage hosted instances, subscriptions,\nand billing from your app.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Error message
                    if (auth.error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius:
                              BorderRadius.circular(CoquiColors.radiusMd),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: colorScheme.onErrorContainer, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                auth.error!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // GitHub sign-in button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: auth.isLoading ? null : auth.startLogin,
                        icon: auth.isLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.code),
                        label: Text(
                          auth.isLoading
                              ? 'Opening browser...'
                              : 'Sign in with GitHub',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'We\'ll open GitHub in your browser to\ncomplete the sign-in.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
