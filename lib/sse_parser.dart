import 'dart:async';
import 'dart:convert';

import 'package:genui/genui.dart';

/// Parses a Server-Sent Events (SSE) byte stream into A2UI messages.
///
/// SSE format:
/// ```
/// data: {"version":"v0.9","createSurface":{...}}
///
/// data: {"version":"v0.9","updateComponents":{...}}
///
/// event: done
/// data: {}
/// ```
///
/// Each event is separated by a blank line (`\n\n`). We extract
/// the `data:` field from each event, decode the JSON, and convert
/// it to an [A2uiMessage].
///
/// The stream completes when a `done` event is received or when
/// the underlying byte stream closes.
Stream<A2uiMessage> parseSseStream(Stream<List<int>> byteStream) {
  // Buffer for partial chunks — SSE events may be split across
  // TCP packets, so we accumulate text until we find `\n\n`.
  final controller = StreamController<A2uiMessage>();
  final buffer = StringBuffer();

  // Decode bytes to strings manually since utf8.decoder's type
  // doesn't align with dio's Stream<Uint8List> at runtime.
  final subscription = byteStream
      .map((bytes) => utf8.decode(bytes))
      .listen(
    (chunk) {
      buffer.write(chunk);

      // Process all complete events in the buffer.
      // Each SSE event ends with a double newline.
      final String text = buffer.toString();
      final List<String> parts = text.split('\n\n');

      // The last element is either empty (if text ended with \n\n)
      // or an incomplete event still being buffered.
      buffer.clear();
      buffer.write(parts.last);

      // Process all complete events (everything except the last part).
      for (int i = 0; i < parts.length - 1; i++) {
        final String event = parts[i].trim();
        if (event.isEmpty) continue;

        // Check for "done" event — signals end of stream.
        if (event.contains('event: done')) {
          controller.close();
          return;
        }

        // Extract `data:` lines and concatenate them.
        final String data = event
            .split('\n')
            .where((line) => line.startsWith('data: '))
            .map((line) => line.substring(6))
            .join();

        if (data.isEmpty) continue;

        try {
          final message = A2uiMessage.fromJson(
            jsonDecode(data) as Map<String, dynamic>,
          );
          controller.add(message);
        } catch (e) {
          controller.addError('Failed to parse SSE data: $e');
        }
      }
    },
    onDone: () {
      if (!controller.isClosed) controller.close();
    },
    onError: (Object e) {
      controller.addError(e);
    },
  );

  controller.onCancel = () => subscription.cancel();

  return controller.stream;
}
