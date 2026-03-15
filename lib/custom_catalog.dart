import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

// ---------------------------------------------------------------------------
// LocationPicker
// ---------------------------------------------------------------------------

final _locationPickerSchema = S.object(
  description:
      'A location picker that displays a prompt and a list of selectable '
      'location options. Dispatches a "select" event with the chosen value.',
  properties: {
    'title': S.string(description: 'Heading text shown above the options.'),
    'subtitle': S.string(
      description: 'Optional secondary text below the title.',
    ),
    'options': S.list(
      description: 'List of location options.',
      items: S.object(
        properties: {
          'label': S.string(description: 'Display label for the option.'),
          'value': S.string(description: 'Value sent back on selection.'),
        },
        required: ['label', 'value'],
      ),
    ),
  },
  required: ['title', 'options'],
);

final locationPicker = CatalogItem(
  name: 'LocationPicker',
  dataSchema: _locationPickerSchema,
  widgetBuilder: (CatalogItemContext itemContext) {
    final JsonMap json = itemContext.data as JsonMap;
    final String title = json['title'] as String;
    final String? subtitle = json['subtitle'] as String?;
    final List<JsonMap> options =
        (json['options'] as List).cast<JsonMap>();
    final ThemeData theme = Theme.of(itemContext.buildContext);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  ActionChip(
                    avatar: const Icon(Icons.place, size: 18),
                    label: Text(option['label'] as String),
                    onPressed: () {
                      itemContext.dispatchEvent(
                        UserActionEvent(
                          name: 'select',
                          sourceComponentId: itemContext.id,
                          context: {'value': option['value'] as String},
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);

// ---------------------------------------------------------------------------
// WeatherCard
// ---------------------------------------------------------------------------

final _weatherCardSchema = S.object(
  description:
      'A weather card that displays current weather information for a city, '
      'including temperature, condition, and an icon.',
  properties: {
    'city': S.string(description: 'City name.'),
    'temperature': S.number(description: 'Temperature value.'),
    'unit': S.string(
      description: 'Temperature unit.',
      enumValues: ['C', 'F'],
    ),
    'condition': S.string(
      description: 'Weather condition.',
      enumValues: [
        'sunny',
        'cloudy',
        'rainy',
        'snowy',
        'stormy',
        'windy',
        'foggy',
      ],
    ),
    'humidity': S.integer(description: 'Humidity percentage (0-100).'),
  },
  required: ['city', 'temperature', 'condition'],
);

IconData _weatherIcon(String condition) {
  return switch (condition) {
    'sunny' => Icons.wb_sunny,
    'cloudy' => Icons.cloud,
    'rainy' => Icons.grain,
    'snowy' => Icons.ac_unit,
    'stormy' => Icons.flash_on,
    'windy' => Icons.air,
    'foggy' => Icons.foggy,
    _ => Icons.thermostat,
  };
}

Color _weatherColor(String condition) {
  return switch (condition) {
    'sunny' => Colors.orange,
    'cloudy' => Colors.blueGrey,
    'rainy' => Colors.indigo,
    'snowy' => Colors.lightBlue,
    'stormy' => Colors.deepPurple,
    'windy' => Colors.teal,
    'foggy' => Colors.grey,
    _ => Colors.blue,
  };
}

final weatherCard = CatalogItem(
  name: 'WeatherCard',
  dataSchema: _weatherCardSchema,
  widgetBuilder: (CatalogItemContext itemContext) {
    final JsonMap json = itemContext.data as JsonMap;
    final String city = json['city'] as String;
    final num temperature = json['temperature'] as num;
    final String unit = json['unit'] as String? ?? 'C';
    final String condition = json['condition'] as String;
    final int? humidity = json['humidity'] as int?;
    final ThemeData theme = Theme.of(itemContext.buildContext);
    final Color color = _weatherColor(condition);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(_weatherIcon(condition), size: 40, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(city, style: theme.textTheme.titleLarge),
                      Text(
                        condition[0].toUpperCase() + condition.substring(1),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${temperature.toStringAsFixed(0)}°$unit',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            if (humidity != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.water_drop,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Humidity: $humidity%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  },
);
