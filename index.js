const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { Pinecone } = require('@pinecone-database/pinecone');
require('dotenv').config();

// Initialize Express App
const app = express();
app.use(cors());
// Increase payload limit to 50MB (Safe for high-res phone cameras)
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// --- CONFIGURATION ---
const PORT = process.env.PORT || 3000;
const MONGO_URI = process.env.MONGO_URI;
const PINECONE_API_KEY = process.env.PINECONE_API_KEY;
const PINECONE_INDEX = 'lokseva-index';

// --- 🔑 API KEY ROTATION SYSTEM ---
// Load all available keys from .env to avoid Rate Limits (429 Errors)
const API_KEYS = [
    process.env.GEMINI_API_KEY,
    process.env.GEMINI_API_KEY_1,
    process.env.GEMINI_API_KEY_2,
    process.env.GEMINI_API_KEY_3
].filter(Boolean); // Remove undefined/null keys

// --- 1. DATABASE CONNECTIONS ---
mongoose.connect(MONGO_URI)
  .then(() => console.log("Connected to MongoDB"))
  .catch(err => console.error("MongoDB Error:", err));

const pinecone = new Pinecone({ apiKey: PINECONE_API_KEY });
const index = pinecone.index(PINECONE_INDEX);

if (API_KEYS.length === 0) {
    console.error("❌ CRITICAL: No Gemini API Keys found!");
    process.exit(1);
}

// Function to get a random model instance (Load Balancing)
function getGenModel(modelName = "gemini-2.5-flash") {
    const randomKey = API_KEYS[Math.floor(Math.random() * API_KEYS.length)];
    const genAI = new GoogleGenerativeAI(randomKey);
    return genAI.getGenerativeModel({ model: modelName });
}
// --- 2. DATA MODELS ---
const agencySchema = new mongoose.Schema({
  id: String,
  name: String,
  location: { city: String, area: String },
  services: [String],
  rating: Number,
  contact: String,
  policy: String
});
const Agency = mongoose.model('Agency', agencySchema);

const userSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true },
  name: String,
  profilePic: String,
  phone: String,
  age: Number,
  address: String,
  medicalHistory: String
});
const User = mongoose.model('User', userSchema);

const conversationSchema = new mongoose.Schema({
  user_email: { type: String, required: true },
  title: String,
  createdAt: { type: Date, default: Date.now },
  messages: [{
    sender: String,
    text: String,
    timestamp: { type: Date, default: Date.now }
  }]
});
const Conversation = mongoose.model('Conversation', conversationSchema);

// --- 3. HELPER FUNCTIONS ---
async function getEmbedding(text) {
  // Use rotated key for embeddings
  const model = getGenModel("text-embedding-004");
  const result = await model.embedContent(text);
  return result.embedding.values;
}
// --- 4. API ENDPOINTS ---

// GET: List all Agencies
app.get('/api/agencies', async (req, res) => {
  try {
    const agencies = await Agency.find();
    res.json(agencies);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch agencies" });
  }
});

// POST: User Profile
app.post('/api/user/profile', async (req, res) => {
  try {
    const { email, name, profilePic, phone, age, address, medicalHistory } = req.body;

    if (!email) return res.status(400).json({ error: "Email is required" });

    let user = await User.findOne({ email });

    if (user) {
      user.name = name || user.name;
      user.profilePic = profilePic || user.profilePic;
      user.phone = phone || user.phone;
      user.age = age || user.age;
      user.address = address || user.address;
      user.medicalHistory = medicalHistory || user.medicalHistory;
      await user.save();
    } else {
      user = new User({ email, name, profilePic, phone, age, address, medicalHistory });
      await user.save();
    }
    res.json({ message: "Profile saved successfully", user });
  } catch (error) {
    console.error("Profile Error:", error);
    res.status(500).json({ error: "Failed to save profile" });
  }
});

// GET: History (Lazy Loading)
app.get('/api/chat/history', async (req, res) => {
  try {
    const { user_email, page = 1, limit = 10 } = req.query;

    if (!user_email) return res.status(400).json({ error: "user_email is required" });

    const history = await Conversation.find({ user_email })
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit))
      .select('title createdAt messages');

    const formattedHistory = history.map(chat => ({
      conversationId: chat._id,
      title: chat.title || "New Chat",
      date: chat.createdAt ? chat.createdAt.toISOString() : new Date().toISOString(),
      lastMessage: chat.messages.length > 0 ? chat.messages[chat.messages.length - 1].text.substring(0, 50) + "..." : ""
    }));

    res.json({
      history: formattedHistory,
      hasMore: history.length === parseInt(limit)
    });
  } catch (error) {
    console.error("History Error:", error);
    res.status(500).json({ error: "Failed to fetch history" });
  }
});

// GET: Single Chat
app.get('/api/chat/:conversationId', async (req, res) => {
  try {
    const chat = await Conversation.findById(req.params.conversationId);
    if (!chat) return res.status(404).json({ error: "Chat not found" });
    res.json(chat);
  } catch (error) {
    res.status(500).json({ error: "Server Error" });
  }
});

// POST: Chat (RAG + Context + Structured JSON)
app.post('/api/chat', async (req, res) => {
  try {
    const { message, user_email, conversationId } = req.body;

    if (!user_email) return res.status(400).json({ error: "user_email is required" });

    // 1. Context
    let userContext = "User Profile: Anonymous.";
    const user = await User.findOne({ email: user_email });
    if (user) {
        userContext = `USER PROFILE: Name: ${user.name}, Age: ${user.age}, Medical History: ${user.medicalHistory}, Address: ${user.address}`;
    }

    // Context: Last 30 Messages (Raw)
    let chatHistory = "";
    if (conversationId) {
      const chat = await Conversation.findById(conversationId);
      if (chat && chat.messages) {
        const recentMsgs = chat.messages.slice(-30);
        chatHistory = recentMsgs.map(m => `${m.sender.toUpperCase()}: ${m.text}`).join('\n');
      }
    }

    // 2. Vector Search
    const queryVector = await getEmbedding(message);
    const searchResponse = await index.query({
      vector: queryVector,
      topK: 5,
      includeMetadata: true
    });
    const matches = searchResponse.matches;
    let agencyContext = matches.length > 0
      ? matches.map(m => `Agency: ${m.metadata.name}, Services: ${m.metadata.services}, Rating: ${m.metadata.rating}, Area: ${m.metadata.area}`).join('\n')
      : "No specific agencies found.";

    // 3. Generate (With Schema-Only Prompt)

    // 3. GENERATE (With Strict "Anti-Hallucination" Rules)
    const prompt = `
    SYSTEM: You are LokSeva, an AI Care Coordinator. Your goal is to match the user's specific medical needs with the Verified Agencies provided below.

    ${userContext}

    HISTORY:
    ${chatHistory}

    VERIFIED AGENCIES (Source of Truth):
    ${agencyContext}

    USER QUERY: "${message}"

    STRICT GOVERNANCE RULES:
    1. ZERO HALLUCINATION: You must ONLY recommend agencies listed in the "VERIFIED AGENCIES" block above. Do not invent names, ratings, or locations.
    2. FACTUALITY: If the 'VERIFIED AGENCIES' block says "No specific agencies found," you MUST state that you cannot find a match right now. Do not make one up.
    3. TONE: Be empathetic but professional. Acknowledge their condition (e.g., "Given your diabetes...") to show you are listening.

    TASK: Output a JSON object.
    - "reply": The chat message. Explain *why* you chose these agencies based on the user's profile.
    - "recommendations": The list of cards.

    KEEP THE ELEMENTS of the json AS BRIEF AS POSSIBLE BUT WITH FACTUAL DATA (if numbers are there go with them, or else brief and to the point sentences without missing anything important)

    OUTPUT FORMAT (Strict JSON):
    {
      "reply": "String",
      "recommendations": [
        {
          "name": "String (Exact name from Source)",
          "rating": Number (Exact rating from Source),
          "location": "String (Exact area)",
          "reason": "String (Why this fits the user's specific medical history)"
        }
      ]
    }
    `;

    const model = getGenModel(); // Get random key
    const result = await model.generateContent(prompt);

    // Clean and Parse
    let rawText = result.response.text().replace(/```json/g, '').replace(/```/g, '').trim();
    let parsedResponse;
    try {
        parsedResponse = JSON.parse(rawText);
    } catch (e) {
        parsedResponse = { reply: rawText, recommendations: [] };
    }

    // 4. Save History
    let conversation;
    let title = "New Chat";

    if (conversationId) {
      conversation = await Conversation.findById(conversationId);
      if (conversation) {
        conversation.messages.push({ sender: 'user', text: message });
        conversation.messages.push({ sender: 'bot', text: parsedResponse.reply });
        await conversation.save();
        title = conversation.title;
      }
    } else {
      const titleModel = getGenModel();
      const titlePrompt = `Generate a title for this chat. MAX 40 characters. NO formatting. NO newlines. Query: "${message}"`;
      const titleResult = await titleModel.generateContent(titlePrompt);
      title = titleResult.response.text().replace(/['"\n]/g, '').substring(0, 50).trim();

      conversation = new Conversation({
        user_email,
        title: title,
        messages: [ { sender: 'user', text: message }, { sender: 'bot', text: parsedResponse.reply } ]
      });
      await conversation.save();
    }

    res.json({
      reply: parsedResponse.reply,
      recommendations: parsedResponse.recommendations,
      conversationId: conversation._id,
      title: title
    });

  } catch (error) {
    console.error("AI Error:", error);
    res.status(500).json({ error: "Something went wrong" });
  }
});

// POST: 📷 AI HOME SAFETY AUDIT (Personalized)
app.post('/api/audit-image', async (req, res) => {
  try {
    const model = getGenModel();
    let { imageBase64, roomType, user_email } = req.body;

    if (!user_email) return res.status(400).json({ error: "user_email is required" });
    if (!imageBase64) return res.status(400).json({ error: "No image provided" });

    // 1. FETCH USER CONTEXT
    let userContext = "User is an elderly individual."; // Default
    const user = await User.findOne({ email: user_email });
    if (user) {
        userContext = `
        USER PROFILE:
        - Age: ${user.age}
        - Mobility/Health Issues: ${user.medicalHistory} (CRITICAL: Prioritize hazards related to this)
        `;
    }

    // 2. DEFINE EXACT STANDARDS (The "Cheat Sheet" - NBC 2016 Part 3, Annex B)
    const NBC_STANDARDS = `
    REFERENCE STANDARDS (National Building Code of India 2016 - Accessibility):

    1. BATHROOM & TOILETS (Critical Zone):
       - DOOR: Minimum 900mm clear opening; must open outwards or slide. Lock must be openable from outside in emergency.
       - WC SEAT: Top of seat must be 450mm - 480mm from floor.
       - GRAB BARS (WC):
         * Horizontal U-shape/L-shape bar: Mounted at 750mm - 850mm height.
         * Vertical bar: Length min 600mm, mounted 150mm from front of WC.
         * Diameter: 38mm - 50mm (circular profile) for secure grip.
         * Wall Clearance: 50mm clearance between bar and wall to prevent hand trapping.
       - SHOWER AREA:
         * Size: Min 1500mm x 1500mm for wheelchair turning.
         * Seat: Wall-mounted folding seat at 450mm height.
         * Controls: Lever type, placed at 800mm - 1000mm height.
       - ALARM: Emergency pull cord extending to within 300mm of floor.

    2. RAMPS & STAIRS (Mobility Zone):
       - RAMP GRADIENT: Max 1:12 (1:15 preferred). Max rise per run: 760mm.
       - RAMP WIDTH: Min 1200mm clear width.
       - LANDING: Min 1500mm x 1500mm landing at top and bottom of ramps.
       - HANDRAILS:
         * Required on BOTH sides.
         * Heights: Double rail system at 760mm and 900mm from floor.
         * Extensions: Must extend 300mm horizontally beyond top/bottom step.
         * Contrast: Handrails must visually contrast with the wall background.
       - STEPS: Riser max 150mm; Tread min 300mm. Open risers (gaps) are PROHIBITED.
       - NOSING: Step edges must have 50mm - 75mm wide contrasting color strip.

    3. CIRCULATION & DOORS (Access Zone):
       - CORRIDORS: Min clear width 1200mm.
       - TURNING RADIUS: 1500mm diameter clear space required for 180-degree wheelchair turn.
       - DOOR HARDWARE: Lever handles (D-shape) required. Round knobs are a HAZARD.
       - OPERATING FORCE: Door opening force max 22N.
       - THRESHOLDS: Max 12mm height, beveled/chamfered edges. Raised thresholds >15mm are tripping hazards.

    4. ELECTRICAL & CONTROLS:
       - SWITCH HEIGHT: All light switches, sockets, and AC controls between 800mm and 1100mm.
       - DISTANCE FROM CORNER: Switches min 400mm from room corners.

    5. FLOORING & SURFACES:
       - FRICTION: Slip Resistance Rating R10 or higher (COF > 0.6).
       - TEXTURE: Matte finish required. Glazed/Polished tiles are a MAJOR HAZARD.
       - CARPETS: Pile height max 13mm; edges must be fastened to floor.
    `;

    // 2. CLEAN IMAGE DATA
    const base64Data = imageBase64.includes(",") ? imageBase64.split(",")[1] : imageBase64;

    console.log(`📷 Audit Request from ${user_email} | Context: ${user.medicalHistory || "None"}`);

    // 3. GENERATE PERSONALIZED REPORT
    const prompt = `
    SYSTEM: You are an expert Home Safety Auditor specializing in Geriatric Care and NBC 2016 Standards, which are provided.

    ${NBC_STANDARDS}

    USER CONTEXT: ${userContext}

    TASK: Analyze this image of a ${roomType || "room"} specifically for THIS user.

    STRICT ANALYSIS ZONES:
    1. FLOORING: Look for trip hazards (rugs, cords) or slip risks (wet tiles) relevant to their mobility.
    2. SUPPORT: Check for grab bars/handrails. Are they missing where this specific user needs them?
    3. LIGHTING: Is it bright enough for someone with potential vision issues?
    4. ACCESSIBILITY: Is the pathway wide enough (>900mm) for a walker/wheelchair if the user needs one?

    NOTE: DO NOT HALLUCINATE. You can just say "All is well" for the recommendations and hazards if they do not have any issues
    according to the NBC 2016 Standards.

    KEEP ELEMENTS of the json as brief as possible with FACTUAL DATA (if numbers are there do include them else give brief and to the point reasoning without missing anything important)

    OUTPUT FORMAT (Strict JSON):
    {
      "safety_score": Integer (1-10, where 10 is safest. Must be a raw Integer, not a String),
      "hazards": ["String: Specific hazard "],
      "recommendations": ["String: Specific fix "]
    }
    `;

    const result = await model.generateContent([
      prompt,
      { inlineData: { data: base64Data, mimeType: "image/jpeg" } }
    ]);

    let cleanText = result.response.text().replace(/```json/g, '').replace(/```/g, '').trim();
    res.json({ audit_report: cleanText });

  } catch (error) {
    console.error("Audit Error:", error);
    res.status(500).json({ error: "Vision Analysis Failed: " + error.message });
  }
});

// POST: Seed Database
app.post('/api/seed-vectors', async (req, res) => {
  try {
    const agencies = await Agency.find();
    console.log(`Found ${agencies.length} agencies to process...`);
    const vectors = [];

    for (const agency of agencies) {
      const textToEmbed = `${agency.name} offers ${agency.services.join(', ')} in ${agency.location.area}. Rating: ${agency.rating}.`;
      const embedding = await getEmbedding(textToEmbed);

      vectors.push({
        id: agency._id.toString(),
        values: embedding,
        metadata: {
          name: agency.name,
          area: agency.location.area,
          services: agency.services.join(', '),
          rating: agency.rating
        }
      });
    }

    if (vectors.length > 0) {
        await index.upsert(vectors);
    }

    res.json({ message: `Successfully embedded ${vectors.length} agencies!` });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => console.log(`LokSeva Backend V2.3 Running on Port ${PORT}`));
