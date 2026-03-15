# Catalog Gallery

A Flutter app that demonstrates the [GenUI](https://github.com/flutter/genui) framework with custom widgets and a mock backend server.

## Prerequisites

- [FVM](https://fvm.app/) (Flutter Version Management)
- [Node.js](https://nodejs.org/) (for the backend server)

## Setup

```bash
fvm flutter pub get
cd backend && npm install
```

## Running

### 1. Start the backend server

```bash
cd backend
npm start
```

The server runs on `http://localhost:3001`.

### 2. Run the Flutter app

```bash
fvm flutter run
```

## Tabs

The app has multiple tabs:

- **Catalog** - Debug view of all registered catalog widgets (built-in + custom)
- **Assets** - Renders A2UI messages from bundled JSONL asset files
- **Server** - Communicates with the backend server via HTTP. Fetches UI on load, sends user actions back, and re-renders based on the server response
- **Samples** (desktop only) - Loads `.sample` files from the `samples/` directory. Pass `--samples=<path>` or run from the project root on macOS

### Server tab flow

1. App fetches initial UI from `POST /api/init` (location picker)
2. User taps a city chip
3. App sends the action to `POST /api/action`
4. Server responds with a weather card for that city
5. User taps "Pick another location" to go back

## Custom widgets

Two custom widgets are registered in `lib/custom_catalog.dart`:

- **LocationPicker** - Displays a title, subtitle, and selectable location chips. Dispatches a `select` event with the chosen value.
- **WeatherCard** - Displays weather info (city, temperature, condition, humidity) with a gradient background and condition icon.

## Backend API

| Endpoint | Method | Description |
|---|---|---|
| `/api/init` | POST | Returns initial A2UI messages (location picker) |
| `/api/action` | POST | Receives user action, returns updated A2UI messages |

The backend returns plain JSON arrays of A2UI v0.9 messages (no streaming).

## Asset file format

The file `assets/sao_paulo_options.jsonl` is a JSONL (JSON Lines) file — one A2UI message per line.

The A2UI v0.9 protocol requires messages to be sent in a specific order:

**Line 1 — `createSurface`**: Initializes a surface with an ID and a catalog reference. This must come before any component updates.

```json
{"version":"v0.9","createSurface":{"surfaceId":"main","catalogId":"https://a2ui.org/specification/v0_9/standard_catalog.json"}}
```

**Line 2 — `updateComponents`**: Defines the UI as a flat list of components that reference each other by ID. A root layout component (Column) arranges children, and each component specifies its type as a string (e.g. `"LocationPicker"`, `"WeatherCard"`).

```json
{"version":"v0.9","updateComponents":{"surfaceId":"main","components":[
  {"id":"root","component":"Column","children":["location_picker","weather_card"]},
  {"id":"location_picker","component":"LocationPicker","title":"Sao Paulo",...},
  {"id":"weather_card","component":"WeatherCard","city":"Sao Paulo","temperature":28,...}
]}}
```

Components are **flat, not nested**. A Column references its children by ID (`"children":["location_picker","weather_card"]`), and each child is a separate object in the same array. This allows the protocol to update individual components without resending the entire tree.

Custom components like `LocationPicker` and `WeatherCard` use their own property schemas (defined in `lib/custom_catalog.dart`), while built-in components like `Column`, `Text`, and `Button` follow the [standard A2UI catalog schema](https://github.com/flutter/genui/tree/main/packages/genui/lib/src/catalog/basic_catalog_widgets).

## Integrating with existing design systems (e.g. Widgetbook)

If your project already has a component library documented in [Widgetbook](https://www.widgetbook.io/), you can wrap those widgets as `CatalogItem` entries for the A2UI protocol. The mapping is:

| Widgetbook | genui CatalogItem |
|---|---|
| Dart knobs (String, enum, bool) | `json_schema_builder` schema (`S.string()`, `S.object()`) |
| Widget constructor | `widgetBuilder` callback |
| Use cases / stories | `exampleData` (JSON strings for the AI) |

Each existing widget gets a thin wrapper that defines its JSON schema and delegates rendering to the original widget. The schema tells the AI what props are available; the builder maps JSON data to your widget's constructor. Not every widget needs to be in the catalog — only the subset that makes sense for AI-generated UIs.

See [analysis.md](analysis.md) for a detailed breakdown of the A2UI protocol, message format, and round-trip flow.

## Notes

- On iOS simulator, if `localhost` doesn't connect, try changing the server URL to `http://127.0.0.1:3001` in `lib/main.dart`.
- The `genui` dependency uses a git ref to get the latest v0.9 protocol support (the pub.dev release only supports v0.8).
