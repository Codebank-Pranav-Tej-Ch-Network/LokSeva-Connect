# LokSeva Connect API Documentation (V2.3)

**Base URL:** `https://lokseva-connect.onrender.com`
**Status:** Live & Auto-Scaling
**Auth Strategy:** Trust-based. Authenticate via Firebase on Flutter, then pass the `email` field in every request body to link data.

---
### 1) User Profile (Create / Update)
**Endpoint:** `POST /api/user/profile`

**Description:** Saves or updates the user's personal details. Call this immediately after Google Sign-In or when the user edits their profile.
**Why:** The AI uses `age` and `medicalHistory` to personalize safety audits and agency recommendations.

**Request Body (JSON):**
```json
{
  "email": "user@example.com",          // STRING (Required - Unique ID)
  "name": "John Doe",                   // STRING
  "profilePic": "https://lh3...",       // STRING (URL)
  "age": 75,                            // NUMBER
  "phone": "9988776655",                // STRING
  "address": "123, Gandhi Road, Tirupati", // STRING
  "medicalHistory": "Wheelchair user, Diabetic, Post-Stroke" // STRING (Crucial for AI context)
}
```
**Response (200 OK)**
```JSON
{
  "message": "Profile saved successfully",
  "user": {
    "_id": "65b...",
    "email": "user@example.com",
    "name": "John Doe",
    "age": 75,
    "medicalHistory": "Wheelchair user, Diabetic, Post-Stroke"
  }
}
```

### 2) AI Chat (Smart Search + History)
**Endpoint:** `POST /api/chat`

**Description:** The main RAG interface. It searches for relevant agencies and personalizes the answer based on the user's stored profile. It supports conversational memory (last 30 messages).

**Request Body (JSON):**
```json
{
  "user_email": "user@example.com",     // STRING (Required for Context)
  "message": "I need a nurse for insulin injections.", // STRING
  "conversationId": "65b7..."           // STRING (Optional. If provided, continues that chat)
}
```

**Response (200 OK)**
Returns structured data for Chat Bubbles (reply) and UI Cards (recommendations).
```json 
{
  "reply": "Based on your diabetes needs, I recommend...", // STRING (The AI text response)
  "conversationId": "65b7...",  // STRING (Save this to continue conversation)
  "title": "Insulin Nurse Help", // STRING (Auto-generated title)
  "recommendations": [           // ARRAY (Use this to build Flashcards)
    {
      "name": "Agency Name",
      "rating": 5.0,
      "location": "KT Road",
      "reason": "Offers specialized home nursing for diabetes."
    }
  ]
}
```

### 3) Chat History (Sidebar)
**Endpoint:** `GET /api/chat/history`

**Description:** Fetches a list of past conversations for the sidebar. Supports pagination.

**Query Parameters:**
* `user_email`: (Required) e.g., `user@example.com`
* `page`: (Optional) Page number (default: 1)
* `limit`: (Optional) Items per page (default: 10)

**Response (200 OK):**
```json
{
  "history": [
    {
      "conversationId": "65b7...",
      "title": "Insulin Nurse Help",
      "date": "2026-01-26T10:00:00.000Z",
      "lastMessage": "I need a nurse..."
    }
  ],
  "hasMore": false // BOOLEAN (True if more pages exist)
}
```

### 4) Home Safety Audit (Vision AI)
**Endpoint:** `POST /api/audit-image`

**Description:** Upload a photo of a room. The AI analyzes it against **NBC 2016 Accessibility Standards** (e.g., 900mm doors, R10 flooring) and the user's specific mobility profile.

**Request Body (JSON):**
```json
{
  "user_email": "user@example.com",     // STRING (Required for personalized risk assessment)
  "roomType": "Bathroom",               // STRING (e.g., "Bedroom", "Stairs")
  "imageBase64": "..."                  // STRING (Base64 encoded image string)
}
```

**Response (200 OK)**
Returns a JSON object containing the audit results.

```json 
{
  "audit_report": "{\"safety_score\": 2, \"hazards\": [\"Trip hazard: Loose rugs\"], \"recommendations\": [\"Remove rugs immediately\"]}"
}
```

Note: The `audit_report` value is a stringified JSON. You must parse it in your frontend code: `jsonDecode(response['audit_report'])`.

### 5) Get All Agencies (Directory)
**Endpoint:** `GET /api/agencies`

**Description:** Returns the raw list of all registered agencies. Useful for a "Browse" screen or map view.

**Response (200 OK):**
```json
[
  {
    "id": "care_cure_home",
    "name": "Care & Cure Happy Home",
    "location": { "city": "Tirupati", "area": "Agarala" },
    "services": ["elderly_care", "residential_home"],
    "rating": 5.0,
    "contact": "+91 91607 75083",
    "policy": "Good residential care..."
  },
  ...
]
```

### 6) Seed AI Knowledge (Admin)
**Endpoint**: `POST /api/seed-vectors`
**Description**: Forces the AI to re-learn the agency data from the database. Call this once after manually updating the database or running `seed.js`.
**Request Body**: None (Empty json `{}`)

**Response (200 OK)**
```JSON 
{
  "message": "Successfully embedded 13 agencies!"
}
```
