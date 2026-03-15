import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import 'server_view_mixin.dart';

/// A view that renders A2UI surfaces fetched via plain HTTP.
///
/// On initialization, it POSTs to /api/init to get the initial UI.
/// When the user interacts with a component, the action is POSTed
/// to /api/action and the server's response replaces the current UI.
///
/// All surface management logic is in [ServerViewMixin].
class ServerView extends StatefulWidget {
  const ServerView({
    super.key,
    required this.catalog,
    required this.serverUrl,
  });

  final Catalog catalog;
  final String serverUrl;

  @override
  State<ServerView> createState() => _ServerViewState();
}

class _ServerViewState extends State<ServerView> with ServerViewMixin {
  @override
  Catalog get catalog => widget.catalog;

  @override
  String get serverUrl => widget.serverUrl;

  @override
  void initState() {
    super.initState();
    initServerView();
    _fetchInitialUi();
  }

  @override
  void dispose() {
    disposeServerView();
    super.dispose();
  }

  /// Fetches the initial UI from the server (POST /api/init).
  ///
  /// The server responds with a JSON array of A2UI messages that
  /// define the first screen. These are fed to the SurfaceController.
  Future<void> _fetchInitialUi() async {
    try {
      final response = await dio.post<List<dynamic>>('/api/init');
      if (response.data != null) {
        handleMessages(response.data!);
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() {
        loading = false;
        error = 'Could not connect to server: $e';
      });
    }
  }

  /// Forwards user actions to POST /api/action.
  @override
  Future<void> onAction(Map<String, dynamic> action) async {
    await postActionHttp('/api/action', action);
  }

  @override
  Widget build(BuildContext context) {
    return buildSurfaceOrState(
      context,
      onRetry: () {
        setState(() {
          loading = true;
          error = null;
        });
        _fetchInitialUi();
      },
    );
  }
}
