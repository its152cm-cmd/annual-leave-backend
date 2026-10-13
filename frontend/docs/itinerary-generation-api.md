# Itinerary generation API

The Flutter app sends a trip and the user's travel preferences to the Python
backend when **Generate my itinerary** is pressed. The backend owns AI/model
access; do not put model credentials in the Flutter app.

## Request

`POST /api/itinerary/generate`

```json
{
  "trip": {
    "id": "TRIP_123",
    "destination": "Kyoto, Japan",
    "date_range": "12 October 2026",
    "duration": "1 day",
    "budget": "RM 3,000 budget",
    "image_url": "https://example.com/kyoto.jpg",
    "status": "draft",
    "traveller_count": 4,
    "planned_budget": 3000,
    "origin_city": "Kuala Lumpur",
    "estimated_budget": null,
    "budget_breakdown": null
  },
  "preferences": {
    "transcript": "A relaxed cultural trip with local coffee shops.",
    "pace": "Balanced",
    "accessibility": "Standard",
    "restroom_priority": "Medium",
    "start_time": "08:00 AM",
    "end_time": "09:00 PM"
  }
}
```

The response should be JSON and use the same trip ID. Include an overview and
scheduled details for every day so both the overview cards and daily timeline
are populated.

## Successful response

```json
{
  "itinerary": {
    "id": "TRIP_123",
    "title": "Kyoto Itinerary",
    "destination": "Kyoto, Japan",
    "date_range": "12 October 2026",
    "duration_days": 1,
    "categories": ["Flights", "Hotels", "Attractions", "Food"],
    "origin_code": "KUL",
    "destination_code": "KIX",
    "origin_city": "Kuala Lumpur",
    "destination_city": "Kyoto",
    "days": [
      {
        "day_number": 1,
        "date_string": "Mon, 12 Oct",
        "location": "Kyoto, Japan",
        "stops": [
          {"id": "stop-1", "name": "Nishiki Market"}
        ]
      }
    ]
  },
  "day_details": {
    "1": [
      {
        "id": "activity-1",
        "time_start": "10:00 AM",
        "time_end": "12:00 PM",
        "title": "Explore Nishiki Market",
        "subtitle": "Sample local food and browse specialty shops.",
        "duration": "2 hrs",
        "mode": "Walk",
        "type": "attraction",
        "booking_url": ""
      }
    ]
  },
  "estimated_budget": 2480,
  "budget_breakdown": {
    "Transport": 640,
    "Accommodation": 560,
    "Food": 420,
    "Activities": 360,
    "Other expenses": 500
  }
}
```

`day_details` keys are 1-based day numbers and every returned day must have at
least one overview stop and one scheduled activity. The budget fields are
optional; when supplied, the app passes them to its existing financial-summary
screen.

The frontend base URL defaults to `http://localhost:8000` and can be changed at
build/run time with `--dart-define=API_BASE_URL=https://your-backend.example`.
The backend must allow the app's web origin when running in Chrome. Non-2xx,
invalid JSON, and malformed itinerary responses are shown as generation
errors; the app does not substitute a static itinerary.
