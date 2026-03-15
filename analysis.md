# GenUI A2UI Protocol Analysis

## Message Format

Every message requires `"version": "v0.9"` and exactly one action property.

### Message Types

#### 1. CreateSurface
```json
{"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"https://a2ui.org/specification/v0_9/standard_catalog.json"}}
```

#### 2. UpdateComponents
```json
{"version":"v0.9","updateComponents":{"surfaceId":"main","components":[...]}}
```

#### 3. UpdateDataModel
```json
{"version":"v0.9","updateDataModel":{"surfaceId":"main","path":"/user/name","value":"John Doe"}}
```

#### 4. DeleteSurface
```json
{"version":"v0.9","deleteSurface":{"surfaceId":"main"}}
```

## Component Structure

Components are **flat** — they reference each other by ID, not by nesting.

```json
{"id":"root","component":"Column","children":["title","subtitle"]}
{"id":"title","component":"Text","text":"Hello","variant":"h3"}
{"id":"subtitle","component":"Text","text":"World","variant":"body"}
```

Key rules:
- `component` is a string (e.g. `"Button"`, `"Text"`, `"Column"`)
- `child` (string) for single-child components (Button, Card)
- `children` (array of strings) for multi-child components (Column, Row, List)
- Buttons need a child Text component for their label
- A root layout component (Column/Row) is needed to arrange children
- `action` object for interactivity (e.g. `{"event":{"name":"select","data":{...}}}`)

## Custom Backend Mapping

Given a backend that returns:
```json
{"surfaceUpdate":{"main":[{"id":"text_1","component":{"Text":{"content":"Hello"}}}]}}
```

This needs to be translated to A2UI protocol:

1. `component` must be a string, not an object
2. Component-specific props go at the top level (e.g. `"text"` not `"content"`)
3. A `createSurface` message must be sent before `updateComponents`
4. Components must be flat with ID-based references

## Full Round-Trip Flow

```
1. Server sends A2UI messages → handleMessage() renders the UI
         ↓
2. User taps button → onSubmit stream emits the action
         ↓
3. App sends action payload to server
         ↓
4. Server responds with new A2UI messages → feed back to handleMessage()
```

### Step 1: Server → Client (Render UI)

Server sends JSONL messages (one per line). The app parses each line and feeds it to `SurfaceController.handleMessage()`:

```dart
for (final line in lines) {
  final message = A2uiMessage.fromJson(jsonDecode(line));
  surfaceController.handleMessage(message);
}
```

### Step 2: User Interaction → Action Event

When the user taps a button, the `SurfaceController.onSubmit` stream emits a `ChatMessage` containing a `UiInteractionPart` with the action JSON:

```json
{
  "version": "v0.9",
  "action": {
    "name": "select",
    "surfaceId": "main",
    "sourceComponentId": "btn_brasil_sao_paulo",
    "timestamp": "2026-03-14T12:00:00Z",
    "context": {"value": "BrasilSaoPaulo"}
  }
}
```

### Step 3: Client → Server (Send Action)

Listen to `onSubmit` and forward the payload to the server:

```dart
surfaceController.onSubmit.listen((message) {
  final actionJson = jsonEncode(message.parts.last);
  // POST to your backend
  http.post(serverUrl, body: actionJson);
});
```

### Step 4: Server → Client (Update UI)

The server processes the action and responds with new A2UI messages (e.g., update components, create new surface, delete surface). Feed them back to `handleMessage()` to re-render.

## JSONL Format

JSONL (JSON Lines) = one JSON object per line. The genui protocol uses this to stream messages incrementally. Each line is a complete `A2uiMessage`.

```
{"version":"v0.9","createSurface":{...}}
{"version":"v0.9","updateComponents":{...}}
{"version":"v0.9","updateDataModel":{...}}
```

## Transport Options

A2UI is transport-agnostic. The genui Flutter package supports:

- **SSE (Server-Sent Events)** — via `genui_a2a` package, most mature option for streaming
- **HTTP** — simple request/response, works for non-streaming backends
- **A2A protocol** — Agent-to-Agent, for multi-agent setups

A reference Python FastAPI server exists in this repo at `examples/verdure/server/`.
