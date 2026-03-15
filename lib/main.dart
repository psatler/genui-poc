// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:args/args.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import 'asset_view.dart';
import 'custom_catalog.dart';
import 'samples_view.dart';
import 'server_view.dart';

void main(List<String> args) {
  final parser = ArgParser()
    ..addOption('samples', abbr: 's', help: 'Path to the samples directory');
  final ArgResults results = parser.parse(args);

  const FileSystem fs = LocalFileSystem();
  Directory? samplesDir;
  if (results.wasParsed('samples')) {
    samplesDir = fs.directory(results['samples'] as String);
  } else {
    final Directory current = fs.currentDirectory;
    final Directory defaultSamples = fs
        .directory(current.path)
        .childDirectory('samples');
    if (defaultSamples.existsSync()) {
      samplesDir = defaultSamples;
    }
  }

  runApp(CatalogGalleryApp(samplesDir: samplesDir, fs: fs));
}

class CatalogGalleryApp extends StatefulWidget {
  final Directory? samplesDir;
  final FileSystem fs;

  const CatalogGalleryApp({
    super.key,
    this.samplesDir,
    this.fs = const LocalFileSystem(),
    this.splashFactory,
  });

  final InteractiveInkFeatureFactory? splashFactory;

  @override
  State<CatalogGalleryApp> createState() => _CatalogGalleryAppState();
}

// Android emulator uses 10.0.2.2 to reach the host machine's localhost.
String get _serverUrl {
  if (!kIsWeb && Platform.isAndroid) {
    return 'http://10.0.2.2:3001';
  }
  return 'http://localhost:3001';
}

class _CatalogGalleryAppState extends State<CatalogGalleryApp> {
  final Catalog catalog = BasicCatalogItems.asCatalog().copyWith(
    newItems: [locationPicker, weatherCard],
  );

  @override
  Widget build(BuildContext context) {
    final bool showSamples =
        widget.samplesDir != null && widget.samplesDir!.existsSync();

    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        splashFactory: widget.splashFactory,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        splashFactory: widget.splashFactory,
      ),
      home: Builder(
        builder: (context) {
          final int tabCount = 3 + (showSamples ? 1 : 0);
          return DefaultTabController(
            length: tabCount,
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                title: Text(
                  'Catalog Gallery',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
                bottom: TabBar(
                  labelColor:
                      Theme.of(context).colorScheme.onSecondary,
                  unselectedLabelColor: Theme.of(
                    context,
                  ).colorScheme.onSecondary.withValues(alpha: 0.5),
                  tabs: [
                    const Tab(text: 'Catalog'),
                    const Tab(text: 'Assets'),
                    const Tab(text: 'Server'),
                    if (showSamples) const Tab(text: 'Samples'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  DebugCatalogView(
                    catalog: catalog,
                    onSubmit: (message) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'User action: '
                            '${jsonEncode(message.parts.last)}',
                          ),
                        ),
                      );
                    },
                  ),
                  AssetView(
                    catalog: catalog,
                    serverUrl: _serverUrl,
                  ),
                  ServerView(
                    catalog: catalog,
                    serverUrl: _serverUrl,
                  ),
                  if (showSamples)
                    SamplesView(
                      samplesDir: widget.samplesDir!,
                      catalog: catalog,
                      fs: widget.fs,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
