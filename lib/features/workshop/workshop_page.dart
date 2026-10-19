import 'dart:async';
import 'package:flutter/material.dart';
import 'workshop_controller.dart';

class WorkshopPage extends StatefulWidget {
  const WorkshopPage({
    super.key,
    required this.controller,
    required this.firebaseStatus,
    required this.crashlyticsReady,
  });
  final WorkshopController controller;
  final String firebaseStatus;
  final bool crashlyticsReady;
  @override
  State<WorkshopPage> createState() => _WorkshopPageState();
}

class _WorkshopPageState extends State<WorkshopPage>
    with WidgetsBindingObserver {
  WorkshopController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(c.run(trigger: 'startup'));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(c.run(trigger: 'resume'));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _confirmCrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crash this app?'),
        content: const Text(
          'This intentionally closes the app. Reopen it to upload the report to Crashlytics.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crash now'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await c.crash();
  }

  Widget _step(String number, String title, String detail) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 17, child: Text(number)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(detail),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      return PopScope(
        canPop: !c.blocked,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('App Integrity Lab'),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 20),
                child: Icon(Icons.verified_user_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: c.blocked ? _blocked() : _dashboard(),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  List<Widget> _dashboard() => [
    Text(
      'Trust, then verify.',
      style: Theme.of(context).textTheme.headlineLarge,
    ),
    const SizedBox(height: 8),
    const Text(
      'A hands-on Firebase workshop: inspect the device, acquire attestation, and ask the API.',
    ),
    const SizedBox(height: 16),
    Text(widget.firebaseStatus),
    Text(
      'Crashlytics: ${widget.crashlyticsReady ? 'enabled' : 'disabled / unavailable'}',
    ),
    if (c.config.firebaseEnabled)
      Text(
        'App Check provider: ${c.config.debugAppCheck ? 'DEBUG • workshop only' : 'Play Integrity / App Attest'}',
      ),
    const SizedBox(height: 12),
    _step(
      '1',
      'Local detection',
      c.local == null
          ? 'Not checked'
          : '${c.local!.verdict.name} • ${c.local!.signals.isEmpty ? 'no signals reported' : c.local!.signals.join(', ')}',
    ),
    _step('2', 'Firebase App Check', c.appCheckStatus),
    _step('3', 'API decision', c.apiStatus),
    const SizedBox(height: 12),
    Semantics(liveRegion: true, child: Text(c.message)),
    const SizedBox(height: 16),
    FilledButton.icon(
      onPressed: c.busy ? null : () => c.run(),
      icon: const Icon(Icons.shield_outlined),
      label: Text(c.busy ? 'Checking…' : 'Run security check'),
    ),
    if (c.busy)
      const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(),
      ),
    if (c.config.testControls) ...[
      const SizedBox(height: 28),
      Text('Workshop controls', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text(
        'Simulations exercise the block flow without modifying this device.',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: c.busy
                ? null
                : () => c.run(trigger: 'test_button', simulation: 'jailbreak'),
            child: const Text('Simulate jailbreak'),
          ),
          OutlinedButton(
            onPressed: c.busy
                ? null
                : () => c.run(trigger: 'test_button', simulation: 'root'),
            child: const Text('Simulate root'),
          ),
          OutlinedButton(
            onPressed: c.busy || !widget.crashlyticsReady ? null : c.nonFatal,
            child: const Text('Log non-fatal error'),
          ),
          OutlinedButton(
            onPressed: c.busy || !widget.crashlyticsReady
                ? null
                : _confirmCrash,
            child: const Text('Intentional native crash'),
          ),
        ],
      ),
    ],
    const SizedBox(height: 24),
    const Text(
      'Local checks can be hooked. App Check tokens must be verified by the backend. A token alone is not a guarantee that a device is clean.',
      style: TextStyle(color: Color(0xff52605a)),
    ),
  ];

  List<Widget> _blocked() => [
    const SizedBox(height: 24),
    const Icon(Icons.gpp_bad_outlined, size: 64, color: Color(0xffa13030)),
    const SizedBox(height: 20),
    Text(
      c.local?.compromised == true
          ? 'Ooops you are jailbroken/rooted'
          : 'Access blocked by the server',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 12),
    Text(c.message, textAlign: TextAlign.center),
    const SizedBox(height: 24),
    ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.network(
        c.config.gifUrl,
        height: 230,
        fit: BoxFit.cover,
        semanticLabel: 'Rick Astley dancing',
        errorBuilder: (_, error, stack) => const SizedBox(
          height: 180,
          child: Center(
            child: Text(
              'Never gonna give you up 🎵\nRick Astley GIF is unavailable offline.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const SizedBox(
                height: 230,
                child: Center(child: CircularProgressIndicator()),
              ),
      ),
    ),
    const SizedBox(height: 20),
    Text('App Check: ${c.appCheckStatus}'),
    Text('API: ${c.apiStatus}'),
    const SizedBox(height: 16),
    const Text(
      'Observed findings are submitted to Crashlytics when configured. Reports may arrive after the next app launch.',
    ),
    if (c.local?.simulated == true && c.config.testControls) ...[
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: c.busy ? null : c.resetSimulation,
        child: const Text('End simulation and recheck device'),
      ),
    ],
  ];
}
