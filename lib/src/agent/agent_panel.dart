import 'dart:async';
import 'package:flutter/material.dart';
import '../session/mnscloud_session_api.dart';
import '../session/mnscloud_session_controller.dart';
import 'agent_api.dart';
import '../i18n/phoneweb_strings.dart';

/// The same panel is embedded by the shared desktop/mobile/PWA session surface.
class AgentPanel extends StatefulWidget {
  const AgentPanel({super.key, required this.session, this.api});
  final MnscloudSessionController session;
  final AgentApi? api;
  @override
  State<AgentPanel> createState() => _AgentPanelState();
}

class _AgentPanelState extends State<AgentPanel> {
  late final AgentApi api;
  Map<String, dynamic>? agent;
  Map<String, dynamic>? contact;
  final notes = TextEditingController();
  String? disposition;
  bool notesDirty = false;
  List<Map<String, dynamic>> reasons = [];
  List<Map<String, dynamic>> queues = [];
  String? lineKey;
  String? reason;
  String? error;
  String cursor = '0';
  bool busy = false;
  bool unavailable = false;
  StreamSubscription<Map<String, dynamic>>? subscription;
  Timer? reconnect;
  Timer? clock;
  int failures = 0;

  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && agent?['VqaRuntimeStatus'] == 'WRAP_UP') setState(() {});
    });
    final server = widget.session.server!;
    api =
        widget.api ??
        AgentApi(server.replace(path: '/api/v1/', query: '', fragment: ''));
    unawaited(
      load().then((_) {
        if (mounted && !unavailable && agent != null) watch();
      }),
    );
  }

  Future<void> load() async {
    final token = widget.session.accessToken;
    if (token == null) return;
    try {
      final data = await api.request(token);
      if (!mounted) return;
      applySnapshot(data);
    } on MnscloudApiException catch (e) {
      if (mounted) {
        setState(() {
          unavailable = e.status == 402;
          error = e.code;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = tr('Connection unavailable'));
    }
  }

  void applySnapshot(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      agent = (data['agent'] as Map?)?.cast<String, dynamic>();
      final incoming = (data['contact'] as Map?)?.cast<String, dynamic>();
      if (!notesDirty) {
        contact = incoming;
        notes.text = contact?['VqcNotes']?.toString() ?? '';
        disposition = contact?['VqcDisposition']?.toString();
      }
      reasons = (data['pauseReasons'] as List? ?? [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      queues = (data['queues'] as List? ?? [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      error = null;
      unavailable = false;
    });
  }

  void watch() {
    final token = widget.session.accessToken;
    if (!mounted || token == null || unavailable) return;
    subscription = api
        .events(token, cursor)
        .listen(
          (data) {
            if (data['_cursor'] != null) cursor = data['_cursor'].toString();
            failures = 0;
            applySnapshot(data);
          },
          onError: (Object _) => retry(),
          onDone: retry,
          cancelOnError: true,
        );
  }

  void retry() {
    if (!mounted || reconnect?.isActive == true) return;
    failures = (failures + 1).clamp(1, 5);
    reconnect = Timer(Duration(seconds: 1 << failures), () {
      if (mounted) watch();
    });
  }

  Future<void> change(String action, [String? state]) async {
    final token = widget.session.accessToken;
    if (token == null || agent == null || busy) return;
    if (action == 'login' && lineKey == null) {
      setState(() => error = tr('Select a line.'));
      return;
    }
    if (state == 'PAUSED' && reason == null) {
      setState(() => error = tr('Select a pause reason.'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await api.request(
        token,
        action: action,
        body: {
          'revision': int.tryParse('${agent!['VqaRevision']}'),
          'lineKey': lineKey,
          'status': state ?? 'AVAILABLE',
          'reasonUUID': reason,
        },
      );
      if (mounted) {
        setState(
          () => agent = (data['agent'] as Map?)?.cast<String, dynamic>(),
        );
      }
    } on MnscloudApiException catch (e) {
      await load();
      if (mounted) setState(() => error = e.code);
    } catch (_) {
      if (mounted) setState(() => error = tr('Connection unavailable'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> saveNotes() async {
    final token = widget.session.accessToken;
    if (token == null || contact == null || busy) return;
    setState(() => busy = true);
    try {
      await api.request(
        token,
        action: 'contact',
        body: {
          'contactUUID': contact!['VqcUUID'],
          'revision': int.tryParse('${contact!['VqcRevision']}'),
          'notes': notes.text,
          'disposition': disposition,
        },
      );
      notesDirty = false;
      await load();
    } on MnscloudApiException catch (e) {
      if (mounted) setState(() => error = e.code);
    } catch (_) {
      if (mounted) setState(() => error = tr('Connection unavailable'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  int wrapUpSeconds() {
    final value = agent?['VqaWrapUpUntil']?.toString();
    if (value == null) return 0;
    final end = DateTime.tryParse(value.endsWith('Z') ? value : '${value}Z');
    return (end?.difference(DateTime.now().toUtc()).inSeconds ?? 0).clamp(
      0,
      3600,
    );
  }

  @override
  void dispose() {
    reconnect?.cancel();
    clock?.cancel();
    unawaited(subscription?.cancel());
    notes.dispose();
    api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (unavailable || (agent == null && error == null)) {
      return const SizedBox.shrink();
    }
    final status = agent?['VqaRuntimeStatus']?.toString() ?? 'LOGGED_OUT';
    final owns = agent?['SessionOwner']?.toString() != '0';
    final enabled = !busy && owns;
    final lines = widget.session.lines
        .where((line) => line.kind == 'pabx')
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Contact center'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('${tr('Status')}: ${tr(status)}'),
            if (agent?['VqaNextStatus'] != null)
              Text(
                '${tr('Next status')}: ${tr(agent!['VqaNextStatus'].toString())}',
              ),
            if (agent?['VqaPauseReason'] != null)
              Text('${agent!['VqaPauseReason']}'),
            if (agent?['VqaWrapUpUntil'] != null)
              Text(tr('Wrap-up: {seconds}s', {'seconds': wrapUpSeconds()})),
            if (!owns)
              Text(tr('This agent is controlled by another signed-in device.')),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            for (final queue in queues) Text('${queue['VpqName']}'),
            const SizedBox(height: 12),
            if (status == 'LOGGED_OUT') ...[
              DropdownButtonFormField<String>(
                initialValue: lines.any((line) => line.lineKey == lineKey)
                    ? lineKey
                    : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr('Line')),
                items: lines
                    .map(
                      (line) => DropdownMenuItem(
                        value: line.lineKey,
                        child: Text(
                          line.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: enabled
                    ? (value) => setState(() => lineKey = value)
                    : null,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: enabled ? () => change('login') : null,
                child: Text(tr('Join queues')),
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                initialValue: reasons.any((item) => item['VpzUUID'] == reason)
                    ? reason
                    : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr('Pause reason')),
                items: reasons
                    .map(
                      (item) => DropdownMenuItem(
                        value: '${item['VpzUUID']}',
                        child: Text(
                          '${item['VpzName']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: enabled
                    ? (value) => setState(() => reason = value)
                    : null,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: enabled
                        ? () => change('state', 'AVAILABLE')
                        : null,
                    child: Text(tr('Available')),
                  ),
                  OutlinedButton(
                    onPressed: enabled ? () => change('state', 'PAUSED') : null,
                    child: Text(tr('Pause')),
                  ),
                  OutlinedButton(
                    onPressed: enabled ? () => change('logout') : null,
                    child: Text(tr('Leave queues')),
                  ),
                  if (status == 'WRAP_UP')
                    OutlinedButton(
                      onPressed: enabled ? () => change('finish') : null,
                      child: Text(tr('Finish wrap-up')),
                    ),
                ],
              ),
            ],
            if (contact != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: disposition,
                isExpanded: true,
                decoration: InputDecoration(labelText: tr('Call outcome')),
                items:
                    const [
                          'resolved',
                          'follow_up',
                          'no_interest',
                          'wrong_number',
                          'voicemail',
                          'other',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              tr(
                                const {
                                  'resolved': 'Resolved',
                                  'follow_up': 'Follow up',
                                  'no_interest': 'No interest',
                                  'wrong_number': 'Wrong number',
                                  'voicemail': 'Voicemail',
                                  'other': 'Other',
                                }[value]!,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        disposition = value;
                        notesDirty = true;
                      }),
              ),
              TextField(
                controller: notes,
                maxLength: 4000,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: tr('Call notes')),
                onChanged: (_) => notesDirty = true,
              ),
              OutlinedButton(
                onPressed: busy ? null : saveNotes,
                child: Text(tr('Save call notes')),
              ),
            ],
            TextButton.icon(
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh),
              label: Text(tr('Refresh')),
            ),
          ],
        ),
      ),
    );
  }
}
