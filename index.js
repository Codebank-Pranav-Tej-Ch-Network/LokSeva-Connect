const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { Pinecone } = require('@pinecone-database/pinecone');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' })); // Support for Profile Pics & Audit Images

// --- CONFIGURATION ---
const PORT = process.env.PORT || 3000;
const MONGO_URI = process.env.MONGO_URI;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const PINECONE_API_KEY = process.env.PINECONE_API_KEY;
const PINECONE_INDEX = 'lokseva-index';

// --- 1. CONNECTIONS ---
mongoose.connect(MONGO_URI)
  .then(() => console.log("✅ Connected to MongoDB"))
  .catch(err => console.error("❌ MongoDB Error:", err));

const pinecone = new Pinecone({ apiKey: PINECONE_API_KEY });
const index = pinecone.index(PINECONE_INDEX);

const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
// Gemini 2.5 Flash for everything (Chat + Vision)
const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" }); 
const embeddingModel = genAI.getGenerativeModel({ model: "text-embedding-004" });

// --- 2. DATA MODELS ---

// Agency Model (The Services)
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

// User Model (The Profiles) - NEW 👤
const userSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true }, // The Link to Firebase
  name: String,
  profilePic: String, // Stores the URL from Google/Firebase
  phone: String,
  age: Number,
  address: String,
  medicalHistory: String // e.g. "Diabetic, Wheelchair user"
});
const User = mongoose.model('User', userSchema);

// --- 3. HELPER FUNCTIONS ---
async function getEmbedding(text) {
  const result = await embeddingModel.embedContent(text);
  return result.embedding.values;
}

// --- 4. API ENDPOINTS ---

// GET: List Agencies
app.get('/api/agencies', async (req, res) => {
  const agencies = await Agency.find();
  res.json(agencies);
});

// POST: 👤 Create or Update User Profile
app.post('/api/user/profile', async (req, res) => {
  try {
    const { email, name, profilePic, phone, age, address, medicalHistory } = req.body;

    if (!email) return res.status(400).json({ error: "Email is required" });

    // Try to find existing user
    let user = await User.findOne({ email });

    if (user) {
      // Update fields if provided
      user.name = name || user.name;
      user.profilePic = profilePic || user.profilePic;
      user.phone = phone || user.phone;
      user.age = age || user.age;
      user.address = address || user.address;
      user.medicalHistory = medicalHistory || user.medicalHistory;
      await user.save();
      console.log(`👤 Profile updated for: ${email}`);
    } else {
      // Create new user
      user = new User({ email, name, profilePic, phone, age, address, medicalHistory });
      await user.save();
      console.log(`🆕 New User registered: ${email}`);
    }

    res.json({ message: "Profile saved successfully", user });

  } catch (error) {
    console.error("❌ Profile Error:", error);
    res.status(500).json({ error: "Failed to save profile" });
  }
});

// POST: 🧠 SMART SEARCH (RAG) + USER CONTEXT
app.post('/api/chat', async (req, res) => {
  try {
    const { message, user_email } = req.body; 
    console.log(`👤 User: ${user_email || 'Guest'} | ❓ Asked: ${message}`);

    // 1. FETCH USER CONTEXT (The "Memory")
    let userContext = "User Profile: Anonymous Guest.";
    if (user_email) {
        const user = await User.findOne({ email: user_email });
        if (user) {
            userContext = `
            USER PROFILE:
            - Name: ${user.name}
            - Age: ${user.age}
            - Medical History: ${user.medicalHistory}
            - Home Address: ${user.address}
            (Prioritize agencies near this address and suitable for this medical history).
            `;
        }
    }

    // 2. VECTOR SEARCH (The "Eyes")
    const queryVector = await getEmbedding(message);
    const searchResponse = await index.query({
      vector: queryVector,
      topK: 3,
      includeMetadata: true
    });

    const matches = searchResponse.matches;
    let agencyContext = "";
    if (matches.length > 0) {
        agencyContext = matches.map(match => `
        Agency: ${match.metadata.name}
        Location: ${match.metadata.area}
        Services: ${match.metadata.services}
        Rating: ${match.metadata.rating}
        `).join('\n---\n');
    } else {
        agencyContext = "No specific agencies found for this query.";
    }

    // 3. GENERATE ANSWER (The "Brain")
    const prompt = `
    You are LokSeva, an expert care assistant.
    
    ${userContext}

    AVAILABLE AGENCIES:
    ${agencyContext}

    USER QUERY: "${message}"

    TASK: Recommend the best agency based on the user's specific health needs and location. 
    If no agency fits perfectly, suggest general safety advice.
    `;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    
    res.json({ reply: response.text() });

  } catch (error) {
    console.error("❌ AI Error:", error);
    res.status(500).json({ error: "Something went wrong" });
  }
});

// POST: 📷 AI HOME SAFETY AUDIT (VISION)
app.post('/api/audit-image', async (req, res) => {
  try {
    const { imageBase64, roomType, user_email } = req.body; 
    console.log(`👤 User: ${user_email || 'Guest'} | 📷 Uploaded ${roomType} scan`);

    if (!imageBase64) return res.status(400).json({ error: "No image provided" });

    // Use Gemini 2.5 Flash for Vision
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" }); 

    const prompt = `
    SYSTEM: You are an expert Civil Engineer specializing in "Universal Accessibility" and the "National Building Code of India 2016".
    
    TASK: Analyze this image of a ${roomType || "room"}.
    Identify safety hazards for Elderly users or Post-Operative patients.
    
    CHECKLIST TO VERIFY:
    1. Flooring: Is it slippery? (Fall Risk)
    2. Handrails: Are there grab bars? (Support)
    3. Lighting: Is it bright enough?
    4. Door Width: Does it look wide enough for a wheelchair?
    5. Clutter: Are there tripping hazards?
    
    OUTPUT FORMAT (JSON String only):
    {
      "safety_score": (1-10),
      "hazards": ["List of specific risks found"],
      "recommendations": ["List of fixes based on Indian Standards"]
    }
    `;

    const result = await model.generateContent([
      prompt,
      { inlineData: { data: imageBase64, mimeType: "image/jpeg" } }
    ]);

    res.json({ audit_report: result.response.text() });

  } catch (error) {
    console.error("❌ Audit Error:", error);
    res.status(500).json({ error: "Vision Analysis Failed" });
  }
});

// POST: Seed Database (Run once to update Pinecone)
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
    await index.upsert(vectors);
    res.json({ message: `✅ Successfully embedded ${vectors.length} agencies!` });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => console.log(`🚀 RAG Server running on port ${PORT}`));
