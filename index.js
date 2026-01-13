const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { Pinecone } = require('@pinecone-database/pinecone');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// --- CONFIGURATION ---
const PORT = process.env.PORT || 3000;
const MONGO_URI = process.env.MONGO_URI;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const PINECONE_API_KEY = process.env.PINECONE_API_KEY;
const PINECONE_INDEX = 'lokseva-index'; // Must match your website setup

// --- 1. CONNECTIONS ---
// MongoDB
mongoose.connect(MONGO_URI)
  .then(() => console.log("✅ Connected to MongoDB"))
  .catch(err => console.error("❌ MongoDB Error:", err));

// Pinecone
const pinecone = new Pinecone({ apiKey: PINECONE_API_KEY });
const index = pinecone.index(PINECONE_INDEX);

// Gemini
const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" }); // Chat Model
const embeddingModel = genAI.getGenerativeModel({ model: "text-embedding-004" }); // Vector Model

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

// --- 3. HELPER FUNCTIONS ---

// Function to turn text into a Vector (List of 768 numbers)
async function getEmbedding(text) {
  const result = await embeddingModel.embedContent(text);
  return result.embedding.values;
}

// --- 4. API ENDPOINTS ---

// GET: Standard List
app.get('/api/agencies', async (req, res) => {
  const agencies = await Agency.find();
  res.json(agencies);
});

// POST: 🧠 SMART SEARCH (RAG)
app.post('/api/chat', async (req, res) => {
  try {
    const { message } = req.body;
    console.log(`User asked: ${message}`);

    // Step A: Convert User Query -> Vector
    const queryVector = await getEmbedding(message);

    // Step B: Search Pinecone for similar Vectors
    const searchResponse = await index.query({
      vector: queryVector,
      topK: 3, // Get top 3 most relevant agencies
      includeMetadata: true
    });

    // Step C: Construct Context from the Best Matches
    const matches = searchResponse.matches;
    if (matches.length === 0) {
      return res.json({ reply: "I couldn't find any relevant agencies." });
    }

    const contextText = matches.map(match => `
      Agency: ${match.metadata.name}
      Location: ${match.metadata.area}
      Services: ${match.metadata.services}
      Rating: ${match.metadata.rating}
    `).join('\n---\n');

    // Step D: Ask Gemini (RAG)
    const prompt = `
    You are LokSeva, a helpful assistant.
    Use the following verified agencies to answer the user's request.
    
    CONTEXT DATA:
    ${contextText}
    
    USER QUESTION: "${message}"
    
    ANSWER (Be brief and professional):
    `;

    const result = await model.generateContent(prompt);
    const response = await result.response;
    
    res.json({ reply: response.text() });

  } catch (error) {
    console.error("❌ AI Error:", error);
    res.status(500).json({ error: "Something went wrong" });
  }
});

// 🚀 SEEDING ENDPOINT (One-time use)
// Reads MongoDB -> Creates Vectors -> Saves to Pinecone
app.post('/api/seed-vectors', async (req, res) => {
  try {
    const agencies = await Agency.find();
    console.log(`Found ${agencies.length} agencies to process...`);

    const vectors = [];

    for (const agency of agencies) {
      // Create a "Description string" to embed
      const textToEmbed = `${agency.name} offers ${agency.services.join(', ')} in ${agency.location.area}. Rating: ${agency.rating}.`;
      
      const embedding = await getEmbedding(textToEmbed);

      vectors.push({
        id: agency._id.toString(), // MongoDB ID as Vector ID
        values: embedding,
        metadata: {
          name: agency.name,
          area: agency.location.area,
          services: agency.services.join(', '),
          rating: agency.rating
        }
      });
    }

    // Batch Upsert to Pinecone
    await index.upsert(vectors);
    
    res.json({ message: `✅ Successfully embedded and uploaded ${vectors.length} agencies to Pinecone!` });

  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => console.log(`🚀 RAG Server running on port ${PORT}`));
