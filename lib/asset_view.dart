// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genui/genui.dart';

class AssetView extends StatefulWidget {
  const AssetView({
    super.key,
    required this.catalog,
    required this.serverUrl,
  });

  final Catalog catalog;
  final String serverUrl;

  @override
  State<AssetView> createState() => _AssetViewState();
}

class _AssetViewState extends State<AssetView> {
  late SurfaceController _surfaceController;
  late Dio _dio;
  final List<String> _surfaceIds = [];
  int _currentSurfaceIndex = 0;
  StreamSubscription<SurfaceUpdate>? _surfaceSubscription;
  StreamSubscription<ChatMessage>? _actionSubscription;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(baseUrl: widget.serverUrl));
    _surfaceController = SurfaceController(catalogs: [widget.catalog]);
    _setupSurfaceListener();
    _setupActionListener();
    _loadAsset();
  }

  @override
  void dispose() {
    _surfaceSubscription?.cancel();
    _actionSubscription?.cancel();
    _surfaceController.dispose();
    _dio.close();
    super.dispose();
  }

  void _setupSurfaceListener() {
    _surfaceSubscription = _surfaceController.surfaceUpdates.listen((update) {
      if (update is SurfaceAdded) {
        if (!_surfaceIds.contains(update.surfaceId)) {
          setState(() {
            _surfaceIds.add(update.surfaceId);
            if (_surfaceIds.length == 1) {
              _currentSurfaceIndex = 0;
            }
          });
        }
      } else if (update is SurfaceRemoved) {
        if (_surfaceIds.contains(update.surfaceId)) {
          setState(() {
            final int removeIndex = _surfaceIds.indexOf(update.surfaceId);
            _surfaceIds.removeAt(removeIndex);
            if (_surfaceIds.isEmpty) {
              _currentSurfaceIndex = 0;
            } else if (_currentSurfaceIndex >= removeIndex &&
                _currentSurfaceIndex > 0) {
              _currentSurfaceIndex--;
            }
          });
        }
      }
    });
  }

  void _setupActionListener() {
    _actionSubscription = _surfaceController.onSubmit
        .listen((message) async {
      final UiInteractionPart? interaction =
          message.parts.uiInteractionParts.firstOrNull;
      if (interaction == null) return;

      debugPrint('User action: ${interaction.interaction}');

      final Map<String, dynamic> parsed =
          jsonDecode(interaction.interaction) as Map<String, dynamic>;
      final Map<String, dynamic>? action =
          parsed['action'] as Map<String, dynamic>?;
      if (action == null) return;

      await _postAction(action);
    });
  }

  Future<void> _postAction(Map<String, dynamic> action) async {
    try {
      final response = await _dio.post<List<dynamic>>(
        '/api/action',
        data: action,
      );
      if (response.data != null) {
        for (final msg in response.data!) {
          _surfaceController.handleMessage(
            A2uiMessage.fromJson(msg as Map<String, dynamic>),
          );
        }
      }
    } catch (e) {
      debugPrint('Error posting action: $e');
    }
  }

  Future<void> _loadAsset() async {
    try {
      final String content =
          await rootBundle.loadString('assets/sao_paulo_options.jsonl');
      final List<String> lines = const LineSplitter()
          .convert(content)
          .where((l) => l.trim().isNotEmpty)
          .toList();

      for (final line in lines) {
        final message =
            A2uiMessage.fromJson(jsonDecode(line) as Map<String, dynamic>);
        _surfaceController.handleMessage(message);
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_surfaceIds.isEmpty) {
      return const Center(child: Text('No surfaces'));
    }
    return SingleChildScrollView(
      child: Surface(
        key: ValueKey(_surfaceIds[_currentSurfaceIndex]),
        surfaceContext:
            _surfaceController.contextFor(_surfaceIds[_currentSurfaceIndex]),
      ),
    );
  }
}
