import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import 'server_view_mixin.dart';
import 'sse_parser.dart';

/// A view that renders A2UI surfaces streamed from a server via SSE.
///
/// Unlike [ServerView] which receives the full UI in one HTTP response,
/// this view opens an SSE connection and processes A2UI messages as they
/// arrive. This allows progressive rendering — components appear one by
/// one as the server (or LLM) generates them.
///
/// The flow:
/// 1. GET /api/sse/init opens an SSE stream
/// 2. Server pushes A2UI messages with delays (simulating LLM generation)
/// 3. Each message is parsed and fed to the SurfaceController immediately
/// 4. UI updates live as each message arrives
/// 5. When user taps a button, POST /api/sse/action opens another SSE stream
class SseServerView extends StatefulWidget {
  const SseServerView({
    super.key,
    required this.catalog,
    required this.serverUrl,
  });

  final Catalog catalog;
  final String serverUrl;

  @override
  State<SseServerView> createState() => _SseServerViewState();
}

class _SseServerViewState extends State<SseServerView>
    with ServerViewMixin {
  @override
  Catalog get catalog => widget.catalog;

  @override
  String get serverUrl => widget.serverUrl;

  /// Whether the SSE stream is currently open and receiving messages.
  bool _streaming = false;

  /// Subscription to the current SSE stream (init or action response).
  StreamSubscription<A2uiMessage>? _sseSubscription;

  @override
  void initState() {
    super.initState();
    initServerView();
    _connectSse();
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    disposeServerView();
    super.dispose();
  }

  /// Opens an SSE connection to GET /api/sse/init and processes
  /// messages as they stream in.
  Future<void> _connectSse() async {
    try {
      setState(() => _streaming = true);

      // Request a streaming response from the SSE endpoint.
      final response = await dio.get<ResponseBody>(
        '/api/sse/init',
        options: Options(responseType: ResponseType.stream),
      );

      // Parse the SSE byte stream into A2uiMessage objects.
      final Stream<A2uiMessage> messages =
          parseSseStream(response.data!.stream);

      _sseSubscription = messages.listen(
        (message) {
          // Feed each message to the controller as it arrives.
          // The Surface widget rebuilds automatically.
          surfaceController.handleMessage(message);

          // Clear loading state after the first message.
          if (loading) {
            setState(() => loading = false);
          }
        },
        onDone: () {
          setState(() => _streaming = false);
          // If no messages arrived, clear loading state.
          if (loading) {
            setState(() => loading = false);
          }
        },
        onError: (Object e) {
          debugPrint('SSE error: $e');
          setState(() {
            _streaming = false;
            if (loading) {
              loading = false;
              error = 'SSE stream error: $e';
            }
          });
        },
      );
    } catch (e) {
      setState(() {
        loading = false;
        _streaming = false;
        error = 'Could not connect to SSE: $e';
      });
    }
  }

  /// Sends a user action to POST /api/sse/action as SSE.
  ///
  /// The server responds with an SSE stream of A2UI messages
  /// (with delays to simulate LLM thinking), which are processed
  /// incrementally just like the init stream.
  @override
  Future<void> onAction(Map<String, dynamic> action) async {
    try {
      await _sseSubscription?.cancel();
      setState(() => _streaming = true);

      final response = await dio.post<ResponseBody>(
        '/api/sse/action',
        data: action,
        options: Options(responseType: ResponseType.stream),
      );

      final Stream<A2uiMessage> messages =
          parseSseStream(response.data!.stream);

      _sseSubscription = messages.listen(
        (message) {
          surfaceController.handleMessage(message);
        },
        onDone: () => setState(() => _streaming = false),
        onError: (Object e) {
          debugPrint('SSE action error: $e');
          setState(() => _streaming = false);
        },
      );
    } catch (e) {
      debugPrint('Error posting SSE action: $e');
      setState(() => _streaming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildSurfaceOrState(
      context,
      onRetry: () {
        setState(() {
          loading = true;
          error = null;
          surfaceIds.clear();
        });
        _connectSse();
      },
      // Show a streaming indicator while the SSE connection is open.
      header: _streaming
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer,
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Streaming...',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
