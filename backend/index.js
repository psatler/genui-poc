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
// SSE helpers
// ---------------------------------------------------------------------------

function sseHeaders(res) {
  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
  });
}

function sendSse(res, message) {
  res.write(`data: ${JSON.stringify(message)}\n\n`);
}

function endSse(res) {
  res.write("event: done\ndata: {}\n\n");
  res.end();
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
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

const cityRestaurants = {
  BrasilSaoPaulo: [
    { name: "A Casa do Porco", cuisine: "Brazilian BBQ", rating: "4.8" },
    { name: "Maní", cuisine: "Contemporary", rating: "4.7" },
    { name: "Mocotó", cuisine: "Northeastern", rating: "4.6" },
  ],
  BrasilSaoPauloCity: [
    { name: "D.O.M.", cuisine: "Fine Dining", rating: "4.9" },
    { name: "Beco do Batman Café", cuisine: "Café", rating: "4.5" },
    { name: "Figueira Rubaiyat", cuisine: "Steakhouse", rating: "4.7" },
  ],
  BrasilSaoPauloCampinas: [
    { name: "Coco Bambu", cuisine: "Seafood", rating: "4.6" },
    { name: "Pobre Juan", cuisine: "Argentinian", rating: "4.5" },
    { name: "Barão da Picanha", cuisine: "Brazilian", rating: "4.4" },
  ],
  BrasilSaoPauloSantos: [
    { name: "Pier One", cuisine: "Seafood", rating: "4.7" },
    { name: "Tasca do Porto", cuisine: "Portuguese", rating: "4.6" },
    { name: "Ponto do Açaí", cuisine: "Açaí & Juices", rating: "4.3" },
  ],
};

// ---------------------------------------------------------------------------
// Shared response builders
// ---------------------------------------------------------------------------

function locationPickerComponents() {
  return [
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
  ];
}

function weatherComponents(weather, cityKey) {
  return [
    {
      id: "root",
      component: "Column",
      children: ["weather_card", "restaurant_prompt"],
    },
    {
      id: "weather_card",
      component: "WeatherCard",
      ...weather,
      unit: "C",
    },
    {
      id: "restaurant_prompt",
      component: "Column",
      children: ["restaurant_text", "restaurant_row"],
    },
    {
      id: "restaurant_text",
      component: "Text",
      text: `Want restaurant recommendations in ${weather.city}?`,
    },
    {
      id: "restaurant_row",
      component: "Row",
      children: ["yes_btn", "no_btn"],
    },
    {
      id: "yes_btn",
      component: "Button",
      child: "yes_text",
      variant: "primary",
      action: {
        event: {
          name: "show_restaurants",
          context: { city: { path: `/city` } },
        },
      },
    },
    { id: "yes_text", component: "Text", text: "Yes, please!" },
    {
      id: "no_btn",
      component: "Button",
      child: "no_text",
      action: { event: { name: "go_back" } },
    },
    { id: "no_text", component: "Text", text: "No, go back" },
  ];
}

function restaurantComponents(weather, restaurants) {
  const children = ["weather_card", "restaurants_title"];
  const components = [
    {
      id: "weather_card",
      component: "WeatherCard",
      ...weather,
      unit: "C",
    },
    {
      id: "restaurants_title",
      component: "Text",
      text: `Top restaurants in ${weather.city}:`,
      variant: "h4",
    },
  ];

  restaurants.forEach((r, i) => {
    const cardId = `restaurant_${i}`;
    const colId = `restaurant_col_${i}`;
    const nameId = `restaurant_name_${i}`;
    const detailId = `restaurant_detail_${i}`;

    children.push(cardId);
    components.push(
      {
        id: cardId,
        component: "Card",
        child: colId,
      },
      {
        id: colId,
        component: "Column",
        children: [nameId, detailId],
      },
      {
        id: nameId,
        component: "Text",
        text: r.name,
        variant: "h5",
      },
      {
        id: detailId,
        component: "Text",
        text: `${r.cuisine} · ⭐ ${r.rating}`,
      }
    );
  });

  children.push("back_btn");
  components.push(
    {
      id: "back_btn",
      component: "Button",
      child: "back_text",
      action: { event: { name: "go_back" } },
    },
    { id: "back_text", component: "Text", text: "← Pick another location" }
  );

  return [
    { id: "root", component: "Column", children },
    ...components,
  ];
}

function handleAction(action) {
  const { name, context } = action;

  // Location selected → show weather + restaurant prompt
  if (name === "select" && context?.value) {
    const weather = cityWeather[context.value];
    if (!weather) {
      return [
        updateComponents("main", [
          { id: "root", component: "Column", children: ["error_text"] },
          {
            id: "error_text",
            component: "Text",
            text: `Unknown location: ${context.value}`,
          },
        ]),
      ];
    }
    return [updateComponents("main", weatherComponents(weather, context.value))];
  }

  // Show restaurants
  if (name === "show_restaurants" && context?.city) {
    const weather = cityWeather[context.city];
    const restaurants = cityRestaurants[context.city] || [];
    if (weather) {
      return [
        updateComponents("main", restaurantComponents(weather, restaurants)),
      ];
    }
  }

  // Back to location picker
  if (name === "go_back") {
    return [updateComponents("main", locationPickerComponents())];
  }

  return [];
}

// ---------------------------------------------------------------------------
// Plain HTTP routes
// ---------------------------------------------------------------------------

app.post("/api/init", (_req, res) => {
  console.log("[http] init");
  res.json([createSurface("main"), updateComponents("main", locationPickerComponents())]);
});

app.post("/api/action", (req, res) => {
  console.log("[http] action:", JSON.stringify(req.body));
  res.json(handleAction(req.body));
});

// ---------------------------------------------------------------------------
// SSE routes — same data, streamed with delays
// ---------------------------------------------------------------------------

app.get("/api/sse/init", async (req, res) => {
  console.log("[sse] init");
  sseHeaders(res);

  // Step 1: Create the surface immediately.
  sendSse(res, createSurface("main"));
  await delay(300);

  // Step 2: Show a "thinking" message.
  sendSse(
    res,
    updateComponents("main", [
      { id: "root", component: "Column", children: ["thinking"] },
      {
        id: "thinking",
        component: "Text",
        text: "Looking up travel options for Brazil...",
        variant: "body",
      },
    ])
  );
  await delay(1200);

  // Step 3: Replace with the location picker.
  sendSse(res, updateComponents("main", locationPickerComponents()));
  await delay(200);

  endSse(res);
});

app.post("/api/sse/action", async (req, res) => {
  const action = req.body;
  console.log("[sse] action:", JSON.stringify(action));
  sseHeaders(res);

  const { name, context } = action;

  // --- Location selected: show thinking → weather → restaurant prompt ---
  if (name === "select" && context?.value) {
    const weather = cityWeather[context.value];

    if (!weather) {
      sendSse(
        res,
        updateComponents("main", [
          { id: "root", component: "Column", children: ["error_text"] },
          {
            id: "error_text",
            component: "Text",
            text: `Unknown location: ${context.value}`,
          },
        ])
      );
      endSse(res);
      return;
    }

    // Thinking...
    sendSse(
      res,
      updateComponents("main", [
        { id: "root", component: "Column", children: ["thinking"] },
        {
          id: "thinking",
          component: "Text",
          text: `Checking weather for ${weather.city}...`,
        },
      ])
    );
    await delay(800);

    // Show weather card (without restaurant prompt yet).
    sendSse(
      res,
      updateComponents("main", [
        { id: "root", component: "Column", children: ["weather_card"] },
        {
          id: "weather_card",
          component: "WeatherCard",
          ...weather,
          unit: "C",
        },
      ])
    );
    await delay(600);

    // Add the restaurant prompt below the weather card.
    sendSse(
      res,
      updateComponents("main", weatherComponents(weather, context.value))
    );
    await delay(200);

    endSse(res);
    return;
  }

  // --- Show restaurants: thinking → cards appear one by one ---
  if (name === "show_restaurants" && context?.city) {
    const weather = cityWeather[context.city];
    const restaurants = cityRestaurants[context.city] || [];

    if (weather && restaurants.length > 0) {
      // Thinking...
      sendSse(
        res,
        updateComponents("main", [
          {
            id: "root",
            component: "Column",
            children: ["weather_card", "searching"],
          },
          {
            id: "weather_card",
            component: "WeatherCard",
            ...weather,
            unit: "C",
          },
          {
            id: "searching",
            component: "Text",
            text: `Searching for restaurants in ${weather.city}...`,
          },
        ])
      );
      await delay(1000);

      // Build restaurant cards incrementally.
      const allChildren = ["weather_card", "restaurants_title"];
      const allComponents = [
        {
          id: "weather_card",
          component: "WeatherCard",
          ...weather,
          unit: "C",
        },
        {
          id: "restaurants_title",
          component: "Text",
          text: `Top restaurants in ${weather.city}:`,
          variant: "h4",
        },
      ];

      for (let i = 0; i < restaurants.length; i++) {
        const r = restaurants[i];
        const cardId = `restaurant_${i}`;
        const colId = `restaurant_col_${i}`;
        const nameId = `restaurant_name_${i}`;
        const detailId = `restaurant_detail_${i}`;

        allChildren.push(cardId);
        allComponents.push(
          { id: cardId, component: "Card", child: colId },
          {
            id: colId,
            component: "Column",
            children: [nameId, detailId],
          },
          { id: nameId, component: "Text", text: r.name, variant: "h5" },
          {
            id: detailId,
            component: "Text",
            text: `${r.cuisine} · ⭐ ${r.rating}`,
          }
        );

        // Send partial update — one more restaurant card each time.
        sendSse(
          res,
          updateComponents("main", [
            { id: "root", component: "Column", children: [...allChildren] },
            ...allComponents,
          ])
        );
        await delay(500);
      }

      // Add back button.
      allChildren.push("back_btn");
      allComponents.push(
        {
          id: "back_btn",
          component: "Button",
          child: "back_text",
          action: { event: { name: "go_back" } },
        },
        {
          id: "back_text",
          component: "Text",
          text: "← Pick another location",
        }
      );

      sendSse(
        res,
        updateComponents("main", [
          { id: "root", component: "Column", children: [...allChildren] },
          ...allComponents,
        ])
      );
      await delay(200);

      endSse(res);
      return;
    }
  }

  // --- Go back ---
  if (name === "go_back") {
    sendSse(
      res,
      updateComponents("main", [
        { id: "root", component: "Column", children: ["thinking"] },
        { id: "thinking", component: "Text", text: "Going back..." },
      ])
    );
    await delay(400);

    sendSse(res, updateComponents("main", locationPickerComponents()));
    await delay(200);

    endSse(res);
    return;
  }

  endSse(res);
});

// ---------------------------------------------------------------------------

app.listen(PORT, () => {
  console.log(`A2UI mock server running on http://localhost:${PORT}`);
});
