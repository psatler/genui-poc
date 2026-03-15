import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

/// Shared logic for views that communicate with a backend server
/// and render A2UI surfaces.
///
/// Both [ServerView] (plain HTTP) and [SseServerView] (SSE streaming)
/// use this mixin to avoid duplicating surface management, action
/// handling, and message processing code.
///
/// Subclasses must:
/// - Call [initServerView] in `initState`
/// - Call [disposeServerView] in `dispose`
/// - Implement their own fetch strategy (HTTP or SSE)
/// - Use [buildSurfaceOrState] to render the UI
mixin ServerViewMixin<T extends StatefulWidget> on State<T> {
  /// The widget catalog used to render components.
  Catalog get catalog;

  /// Base URL of the backend server.
  String get serverUrl;

  /// The engine that processes A2UI messages, manages surface state,
  /// and emits user interaction events.
  late SurfaceController surfaceController;

  /// Dio HTTP client shared across all requests.
  late Dio dio;

  /// Active surface IDs. A surface is added when the server sends
  /// a createSurface message and removed on deleteSurface.
  final List<String> surfaceIds = [];

  StreamSubscription<SurfaceUpdate>? _surfaceSubscription;
  StreamSubscription<ChatMessage>? _actionSubscription;

  bool loading = true;
  String? error;

  /// Call this in `initState` to set up the controller and listeners.
  void initServerView() {
    dio = Dio(BaseOptions(baseUrl: serverUrl));
    surfaceController = SurfaceController(catalogs: [catalog]);
    _setupSurfaceListener();
    _setupActionListener();
  }

  /// Call this in `dispose` to clean up subscriptions and controller.
  void disposeServerView() {
    _surfaceSubscription?.cancel();
    _actionSubscription?.cancel();
    surfaceController.dispose();
    dio.close();
  }

  /// Listens to surface lifecycle events from the SurfaceController.
  ///
  /// SurfaceAdded is emitted when createSurface is processed.
  /// SurfaceRemoved is emitted when deleteSurface is processed.
  void _setupSurfaceListener() {
    _surfaceSubscription = surfaceController.surfaceUpdates.listen((update) {
      if (update is SurfaceAdded) {
        if (!surfaceIds.contains(update.surfaceId)) {
          setState(() => surfaceIds.add(update.surfaceId));
        }
      } else if (update is SurfaceRemoved) {
        setState(() => surfaceIds.remove(update.surfaceId));
      }
    });
  }

  /// Listens to user interaction events (button taps, etc.).
  ///
  /// When a user interacts with a component that has an action,
  /// the SurfaceController wraps the event as a ChatMessage with
  /// a UiInteractionPart. We extract the action payload and
  /// call [onAction] so the subclass can forward it to the server.
  void _setupActionListener() {
    _actionSubscription = surfaceController.onSubmit.listen((message) async {
      final UiInteractionPart? interaction =
          message.parts.uiInteractionParts.firstOrNull;
      if (interaction == null) return;

      debugPrint('User action: ${interaction.interaction}');
      final Map<String, dynamic> parsed =
          jsonDecode(interaction.interaction) as Map<String, dynamic>;
      final Map<String, dynamic>? action =
          parsed['action'] as Map<String, dynamic>?;

      if (action == null) return;

      await onAction(action);
    });
  }

  /// Called when the user triggers an action. Subclasses implement
  /// this to decide how to send the action to the server (HTTP POST
  /// or SSE stream).
  Future<void> onAction(Map<String, dynamic> action);

  /// Parses a JSON array of A2UI messages and feeds each one to the
  /// SurfaceController in order.
  void handleMessages(List<dynamic> messages) {
    for (final msg in messages) {
      surfaceController.handleMessage(
        A2uiMessage.fromJson(msg as Map<String, dynamic>),
      );
    }
  }

  /// Sends a user action to the server via POST and processes the
  /// response as a JSON array of A2UI messages.
  ///
  /// Used by the HTTP server view directly. The SSE view overrides
  /// [onAction] with its own streaming implementation.
  Future<void> postActionHttp(
    String endpoint,
    Map<String, dynamic> action,
  ) async {
    try {
      final response = await dio.post<List<dynamic>>(
        endpoint,
        data: action,
      );
      if (response.data != null) {
        handleMessages(response.data!);
      }
    } catch (e) {
      debugPrint('Error posting action: $e');
    }
  }

  /// Builds the surface widget or a loading/error/empty state.
  ///
  /// This is the shared build logic — subclasses call it from their
  /// own `build` method, optionally passing an [onRetry] callback
  /// and extra [header] widget (e.g. a streaming indicator).
  Widget buildSurfaceOrState(
    BuildContext context, {
    VoidCallback? onRetry,
    Widget? header,
  }) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              if (onRetry != null)
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
      );
    }
    if (surfaceIds.isEmpty) {
      return const Center(child: Text('No surfaces'));
    }
    return Column(
      children: [
        if (header != null) header,
        Expanded(
          child: SingleChildScrollView(
            child: Surface(
              key: ValueKey(surfaceIds.first),
              surfaceContext:
                  surfaceController.contextFor(surfaceIds.first),
            ),
          ),
        ),
      ],
    );
  }
}
