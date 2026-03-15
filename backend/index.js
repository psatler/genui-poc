const express = require("express");
const cors = require("cors");

const app = express();
app.use(cors());
app.use(express.json());

const PORT = 3001;

// ---------------------------------------------------------------------------
// A2UI message helpers
// ---------------------------------------------------------------------------

function createSurface(surfaceId) {
  return {
    version: "v0.9",
    createSurface: {
      surfaceId,
      catalogId:
        "https://a2ui.org/specification/v0_9/standard_catalog.json",
    },
  };
}

function updateComponents(surfaceId, components) {
  return {
    version: "v0.9",
    updateComponents: { surfaceId, components },
  };
}

function deleteSurface(surfaceId) {
  return {
    version: "v0.9",
    deleteSurface: { surfaceId },
  };
}

// ---------------------------------------------------------------------------
// Mock data
// ---------------------------------------------------------------------------

const cityWeather = {
  BrasilSaoPaulo: {
    city: "Sao Paulo (State)",
    temperature: 26,
    condition: "cloudy",
    humidity: 72,
  },
  BrasilSaoPauloCity: {
    city: "Sao Paulo City",
    temperature: 28,
    condition: "sunny",
    humidity: 65,
  },
  BrasilSaoPauloCampinas: {
    city: "Campinas",
    temperature: 30,
    condition: "sunny",
    humidity: 55,
  },
  BrasilSaoPauloSantos: {
    city: "Santos",
    temperature: 27,
    condition: "rainy",
    humidity: 88,
  },
};

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

// Initial UI — location picker
app.post("/api/init", (_req, res) => {
  console.log("[init] Sending location picker");

  const messages = [
    createSurface("main"),
    updateComponents("main", [
      {
        id: "root",
        component: "Column",
        children: ["location_picker"],
      },
      {
        id: "location_picker",
        component: "LocationPicker",
        title: "Sao Paulo",
        subtitle: "I found a few options. Please select one.",
        options: [
          { label: "Sao Paulo", value: "BrasilSaoPaulo" },
          { label: "Sao Paulo City", value: "BrasilSaoPauloCity" },
          { label: "Campinas", value: "BrasilSaoPauloCampinas" },
          { label: "Santos", value: "BrasilSaoPauloSantos" },
        ],
      },
    ]),
  ];

  res.json(messages);
});

// Handle user actions
app.post("/api/action", (req, res) => {
  const { name, sourceComponentId, context } = req.body;

  console.log(
    `[action] name=${name} source=${sourceComponentId}`,
    `context=${JSON.stringify(context)}`
  );

  // Location selected → show weather + back button
  if (name === "select" && context?.value) {
    const weather = cityWeather[context.value];

    if (!weather) {
      return res.json([
        updateComponents("main", [
          { id: "root", component: "Column", children: ["error_text"] },
          {
            id: "error_text",
            component: "Text",
            text: `Unknown location: ${context.value}`,
          },
        ]),
      ]);
    }

    console.log(`[action] Showing weather for ${weather.city}`);

    return res.json([
      updateComponents("main", [
        {
          id: "root",
          component: "Column",
          children: ["weather_card", "back_btn"],
        },
        {
          id: "weather_card",
          component: "WeatherCard",
          ...weather,
          unit: "C",
        },
        {
          id: "back_btn",
          component: "Button",
          child: "back_btn_text",
          action: { event: { name: "go_back" } },
        },
        {
          id: "back_btn_text",
          component: "Text",
          text: "← Pick another location",
        },
      ]),
    ]);
  }

  // Back button → show location picker again
  if (name === "go_back") {
    console.log("[action] Going back to location picker");

    return res.json([
      updateComponents("main", [
        {
          id: "root",
          component: "Column",
          children: ["location_picker"],
        },
        {
          id: "location_picker",
          component: "LocationPicker",
          title: "Sao Paulo",
          subtitle: "I found a few options. Please select one.",
          options: [
            { label: "Sao Paulo", value: "BrasilSaoPaulo" },
            { label: "Sao Paulo City", value: "BrasilSaoPauloCity" },
            { label: "Campinas", value: "BrasilSaoPauloCampinas" },
            { label: "Santos", value: "BrasilSaoPauloSantos" },
          ],
        },
      ]),
    ]);
  }

  // Fallback
  res.json([]);
});

app.listen(PORT, () => {
  console.log(`A2UI mock server running on http://localhost:${PORT}`);
});
