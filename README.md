<div align="center">

# 🏥 LokSeva Connect
**AI-Driven Geriatric Care Aggregator & IoT-Enabled Home Safety Ecosystem**

[![Status](https://img.shields.io/badge/Status-Live%20V2.4-success?style=for-the-badge)](https://lokseva-connect.onrender.com)
[![Platform](https://img.shields.io/badge/Platform-Flutter%20%7C%20Node.js-blue?style=for-the-badge)](#)
[![AI](https://img.shields.io/badge/AI_Engine-Gemini%202.5%20Flash-orange?style=for-the-badge)](#)
[![Database](https://img.shields.io/badge/Database-MongoDB%20%7C%20Pinecone-brightgreen?style=for-the-badge)](#)

*Empowering the elderly with precise medical matching and intelligent home safety engineering.*

---
</div>

## 📖 Project Overview
**LokSeva Connect** is a comprehensive Cyber-Physical System designed to bridge the massive gap between elderly/post-operative patients and verified local care agencies. Moving beyond simple directories, it leverages **Retrieval-Augmented Generation (RAG)** to provide medically contextualized care matching, and **Multimodal Vision AI** to perform instant civil engineering safety audits of living spaces based on National Building Code (NBC) 2016 standards. 

## 🎯 Motivation
1. **The Care Discovery Gap:** Families in Tier-2 cities often struggle to find *specific* care. A general nurse is easy to find, but locating one specifically trained for insulin administration or stroke rehabilitation is a game of trial and error.
2. **The Aging-in-Place Crisis:** Over 30-50% of hospital readmissions for the elderly are due to preventable falls at home. Most Indian homes are engineered for able-bodied adults, leaving families completely unaware of hidden architectural hazards.

## 🚧 Existing Solutions vs. Why They Fail

| Solution | The Flaw |
| :--- | :--- |
| **Google Maps / JustDial** | **Zero Medical Context:** They list "Nurses" but do not cross-reference the provider's specific medical capabilities with the patient's exact condition. |
| **Offline Brokers** | **Information Asymmetry:** Highly unorganized, heavily reliant on handwritten records, and lacks transparency in pricing or verified service quality. |
| **Civil Engineering Audits** | **Inaccessible:** Hiring a professional to audit a bathroom for wheelchair accessibility is expensive, slow, and overkill for most middle-class families. |

## ✨ Our Solution: LokSeva Connect
We eliminate the guesswork through a dual-AI approach:
* 🧠 **Smart Care Matching:** An AI concierge that reads a patient's medical profile (e.g., "Wheelchair user, Diabetic") and queries a vectorized database of ground-truth local agencies to find exact matches.
* 📷 **AI Safety Engineer:** A computer vision module that analyzes user-uploaded photos of their rooms, strictly enforcing NBC 2016 Accessibility parameters (e.g., ensuring 900mm door clearances and R10 slip-resistant flooring).

## 📈 Expected Improvements
> 💡 **Measurable Impact:** > * **Time-to-Care:** Reduced from days of calling agencies to **under 10 seconds** via intelligent querying.
> * **Fall Prevention:** Democratized safety engineering allows families to fix trip hazards *before* a hospital visit is required.
> * **Data Integrity:** Organizing the unorganized sector into a clean, queryable JSON/Vector ecosystem.

---

## 🛠️ Technical Implementation & Architecture

LokSeva Connect operates on a Context-Aware RAG Architecture:
1. **Frontend (Flutter):** Handles Firebase Authentication, camera access, and renders dynamic UI elements (Flashcards for agencies, color-coded checklists for safety reports).
2. **Backend (Node.js/Express):** Hosted on Render. Manages deep memory (last 30 messages), API key rotation for load balancing, and strict prompt governance to completely eliminate AI hallucinations.
3. **Database Layer:** * **MongoDB Atlas:** Stores immutable user medical profiles and chat histories.
   * **Pinecone:** Stores embedded vector representations of agency services for semantic search.
4. **AI Engine (Gemini 2.5 Flash):** Processes both natural language queries and complex pixel-by-pixel image audits.

---

## 🚀 Core Feature List
* 🔐 **Trust-Based Auth Integration:** Seamless profile linking via Firebase.
* 💬 **Contextual Medical Chatbot:** Deep-memory RAG system that understands follow-up questions.
* 🕵️ **Anti-Hallucination Governance:** AI is strictly restricted to recommending only ground-truth agencies verified by our field data.
* 📏 **NBC-Compliant Vision Audits:** Generates structured JSON reports detailing safety scores, specific hazards, and engineering recommendations based on visual data.

---

## 🌐 API Documentation (V2.4)

> **Base URL:** `https://lokseva-connect.onrender.com` <br>
> **Auth Strategy:** Authenticate via Firebase on the client, pass the `email` field in the request body to link sessions.

<details>
<summary><b>1️⃣ User Profile (Create / Update)</b></summary>

**Endpoint:** `POST /api/user/profile`
**Description:** Saves or updates the user's personal details. The AI uses `age` and `medicalHistory` to personalize safety audits and agency recommendations.

**Request Body:**
```json
{
  "email": "user@example.com",          // STRING (Required)
  "name": "John Doe",                   // STRING
  "profilePic": "https://lh3...",       // STRING (URL)
  "age": 75,                            // NUMBER
  "phone": "9988776655",                // STRING
  "address": "123, Gandhi Road",        // STRING
  "medicalHistory": "Wheelchair user, Diabetic, Post-Stroke" // STRING
}
```

**Response (200 OK):**
```json
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
</details>

<details>
<summary><b>2️⃣ AI Chat (Smart Search + History)</b></summary>

**Endpoint:** `POST /api/chat`
**Description:** The main RAG interface. Searches for agencies and personalizes answers based on the user profile.

**Request Body:**
```json
{
  "user_email": "user@example.com",     // STRING (Required)
  "message": "I need a nurse for insulin injections.", // STRING
  "conversationId": "65b7..."           // STRING (Optional, for continuity)
}
```

**Response (200 OK):**
```json 
{
  "reply": "Based on your diabetes needs, I recommend...", 
  "conversationId": "65b7...",  
  "title": "Insulin Nurse Help", 
  "recommendations": [           
    {
      "name": "Agency Name",
      "rating": 5.0,
      "location": "KT Road",
      "reason": "Offers specialized home nursing for diabetes."
    }
  ]
}
```
</details>

<details>
<summary><b>3️⃣ Chat History (Sidebar)</b></summary>

**Endpoint:** `GET /api/chat/history`
**Description:** Fetches a paginated list of past conversations.

**Query Parameters:**
* `user_email`: (Required) 
* `page`: (Optional) Default 1
* `limit`: (Optional) Default 10

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
  "hasMore": false 
}
```
</details>

<details>
<summary><b>4️⃣ Home Safety Audit (Vision AI)</b></summary>

**Endpoint:** `POST /api/audit-image`
**Description:** Upload a photo for NBC 2016 Accessibility analysis.

**Request Body:**
```json
{
  "user_email": "user@example.com",     // STRING (Required)
  "roomType": "Bathroom",               // STRING 
  "imageBase64": "..."                  // STRING (Base64 encoded string)
}
```

**Response (200 OK):**
*Note: `audit_report` is stringified JSON. Client must parse it.*
```json 
{
  "audit_report": "{\"safety_score\": 2, \"hazards\": [\"Trip hazard: Loose rugs\"], \"recommendations\": [\"Remove rugs immediately\"]}"
}
```
</details>

<details>
<summary><b>5️⃣ Get All Agencies (Directory)</b></summary>

**Endpoint:** `GET /api/agencies`
**Description:** Returns the raw list of all verified agencies for map or browse views.

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
  }
]
```
</details>

---

## 📊 Results & Current Status
The platform is currently in **Phase 1 Deployment (V2.4)**. 
* **Data Validated:** Successfully digitized and vectorized ground-truth data from 13+ agencies in the Tirupati region.
* **API Stability:** Deployed with dynamic key rotation, completely resolving rate-limit bottlenecks and 500 errors.
* **Vision Accuracy:** The auditor successfully flags critical architectural flaws (e.g., identifying bathtub barriers for wheelchair users and missing pull-cord alarms) using strictly typed JSON outputs for seamless frontend integration.

## 👥 Team & Contributions

LokSeva Connect was developed collaboratively to solve real-world geriatric care challenges.

| Team Member | Roll Number | Role | Core Contributions |
| :--- | :--- | :--- | :--- |
| **Pranav** | **CS24B057** | Backend & AI Architect | Engineered the Node.js API and MongoDB architecture. Integrated Gemini 2.5 Flash for RAG and Vision Audits, configured the Pinecone Vector Database, and implemented the dynamic API Key rotation and anti-hallucination governance. |
| **Mritunjay** | **CS24B054** | Frontend Developer | Developed the cross-platform Flutter mobile application. Integrated Firebase Authentication, designed the responsive Flashcard UI for agency matching, and built the camera upload module for the Home Safety Auditor. |
| **Manoj** | **CE24B020** | Field Researcher & Data Lead | Spearheaded ground-truth data acquisition. Conducted physical surveys of local care agencies in the Tirupati region, verified their medical capabilities, and structured the raw field data into JSON for the AI vector search. |

---
<div align="center">
  <i>Built with ❤️ for the elderly community.</i>
</div>
