import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;

/// A view that renders A2UI surfaces fetched from a remote server.
///
/// On initialization, it fetches the initial UI from the server via
/// POST /api/init. When the user interacts with a component (e.g. taps
/// a button), the action is forwarded to POST /api/action and the
/// server's response replaces the current UI.
class ServerView extends StatefulWidget {
  const ServerView({
    super.key,
    required this.catalog,
    required this.serverUrl,
  });

  /// The widget catalog used to render A2UI components. Must include
  /// any custom widgets (e.g. LocationPicker, WeatherCard) that the
  /// server may reference in its responses.
  final Catalog catalog;

  /// Base URL of the backend server (e.g. "http://localhost:3001").
  final String serverUrl;

  @override
  State<ServerView> createState() => _ServerViewState();
}

class _ServerViewState extends State<ServerView> {
  /// The engine that processes A2UI messages and manages surface state.
  /// It holds the component tree, data model, and emits events when
  /// the user interacts with the UI.
  late SurfaceController _surfaceController;

  /// Tracks active surface IDs so we know which surface to render.
  /// A surface is added when the server sends a createSurface message
  /// and removed when it sends deleteSurface.
  final List<String> _surfaceIds = [];

  /// Subscription to surface lifecycle events (added/removed).
  StreamSubscription<SurfaceUpdate>? _surfaceSubscription;

  /// Subscription to user interaction events (button taps, etc.).
  StreamSubscription<ChatMessage>? _actionSubscription;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Create the controller with our catalog so it knows how to
    // build widgets from A2UI component definitions.
    _surfaceController = SurfaceController(
      catalogs: [widget.catalog],
    );

    _setupSurfaceListener();
    _setupActionListener();
    _fetchInitialUi();
  }

  @override
  void dispose() {
    _surfaceSubscription?.cancel();
    _actionSubscription?.cancel();
    _surfaceController.dispose();
    super.dispose();
  }

  /// Listens to surface lifecycle events from the SurfaceController.
  ///
  /// When the server sends a createSurface message, the controller
  /// emits SurfaceAdded — we track the ID so we can render it.
  /// When deleteSurface is received, SurfaceRemoved is emitted.
  void _setupSurfaceListener() {
    _surfaceSubscription = _surfaceController.surfaceUpdates
        .listen((update) {
      if (update is SurfaceAdded) {
        if (!_surfaceIds.contains(update.surfaceId)) {
          setState(() => _surfaceIds.add(update.surfaceId));
        }
      } else if (update is SurfaceRemoved) {
        setState(() => _surfaceIds.remove(update.surfaceId));
      }
    });
  }

  /// Listens to user interaction events from the SurfaceController.
  ///
  /// When the user taps a button or interacts with any component that
  /// has an action, the controller wraps the event in a ChatMessage
  /// containing a UiInteractionPart. We extract the action payload
  /// from it and POST it to the server.
  ///
  /// The action payload looks like:
  /// ```json
  /// {
  ///   "version": "v0.9",
  ///   "action": {
  ///     "name": "select",
  ///     "surfaceId": "main",
  ///     "sourceComponentId": "btn_sao_paulo",
  ///     "context": {"value": "BrasilSaoPaulo"}
  ///   }
  /// }
  /// ```
  ///
  /// We extract the inner "action" object and send it to the server.
  void _setupActionListener() {
    _actionSubscription = _surfaceController.onSubmit
        .listen((message) async {
      // The ChatMessage parts contain DataPart objects. We use the
      // uiInteractionParts extension to find and decode the one
      // that holds the action JSON.
      final UiInteractionPart? interaction =
          message.parts.uiInteractionParts.firstOrNull;
      if (interaction == null) return;

      // interaction.interaction is a JSON string like:
      // {"version":"v0.9","action":{"name":"select",...}}
      debugPrint('User action: ${interaction.interaction}');
      final Map<String, dynamic> parsed =
          jsonDecode(interaction.interaction) as Map<String, dynamic>;
      final Map<String, dynamic>? action =
          parsed['action'] as Map<String, dynamic>?;

      if (action == null) return;

      await _postAction(action);
    });
  }

  /// Parses a JSON array of A2UI messages and feeds each one to the
  /// SurfaceController. The controller processes them in order:
  /// createSurface first, then updateComponents, etc.
  void _handleMessages(List<dynamic> messages) {
    for (final msg in messages) {
      final A2uiMessage a2uiMsg =
          A2uiMessage.fromJson(msg as Map<String, dynamic>);
      _surfaceController.handleMessage(a2uiMsg);
    }
  }

  /// Fetches the initial UI from the server (POST /api/init).
  ///
  /// The server responds with a JSON array of A2UI messages that
  /// define the first screen (e.g. a location picker). These messages
  /// are fed to the SurfaceController which creates the surface and
  /// renders the components.
  Future<void> _fetchInitialUi() async {
    try {
      final response = await http.post(
        Uri.parse('${widget.serverUrl}/api/init'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> messages =
            jsonDecode(response.body) as List<dynamic>;
        _handleMessages(messages);
        setState(() => _loading = false);
      } else {
        setState(() {
          _loading = false;
          _error = 'Server returned ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not connect to server: $e';
      });
    }
  }

  /// Sends a user action to the server (POST /api/action) and
  /// processes the response.
  ///
  /// The server receives the action (e.g. which button was tapped
  /// and with what context), decides what UI to show next, and
  /// responds with a new array of A2UI messages. These are fed
  /// back to the SurfaceController, which updates the rendered
  /// surface in place.
  Future<void> _postAction(Map<String, dynamic> action) async {
    try {
      final response = await http.post(
        Uri.parse('${widget.serverUrl}/api/action'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(action),
      );

      if (response.statusCode == 200) {
        final List<dynamic> messages =
            jsonDecode(response.body) as List<dynamic>;
        _handleMessages(messages);
      }
    } catch (e) {
      debugPrint('Error posting action: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      // Error state with a retry button.
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
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _fetchInitialUi();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_surfaceIds.isEmpty) {
      return const Center(child: Text('No surfaces'));
    }

    // Render the first active surface. The Surface widget reads the
    // component tree from the SurfaceController via the SurfaceContext
    // and builds the corresponding Flutter widgets using the catalog.
    return SingleChildScrollView(
      child: Surface(
        key: ValueKey(_surfaceIds.first),
        surfaceContext:
            _surfaceController.contextFor(_surfaceIds.first),
      ),
    );
  }
}
