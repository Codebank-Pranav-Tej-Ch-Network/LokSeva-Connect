const express = require('express');
const cors = require('cors');
const { GoogleGenerativeAI } = require("@google/generative-ai");
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// --- INITIALIZATION ---
// 1. Load Local Data (Bypassing Firestore)
const agenciesPath = path.join(__dirname, 'data', 'agencies.json');
let agenciesData = [];
try {
    const rawData = fs.readFileSync(agenciesPath);
    agenciesData = JSON.parse(rawData);
    console.log(`✅ Loaded ${agenciesData.length} agencies from local file.`);
} catch (err) {
    console.error("❌ Error loading agencies.json:", err.message);
}

// 2. Initialize Gemini AI
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// --- API ENDPOINTS ---

// Endpoint 1: The AI Concierge
app.post('/api/chat', async (req, res) => {
    try {
        const { message } = req.body;
        console.log("\n💬 User Query:", message);

        // STEP 1: Format the Context from Local Data
        const agencyContext = agenciesData.map(a => `
        - Name: ${a.name}
        - Area: ${a.location.area}
        - Services: ${a.services.join(', ')}
        - Rating: ${a.rating}/5
        - Phone: ${a.contact}
        - Note: ${a.policy}
        `).join('\n');

        // STEP 2: The Prompt
        const prompt = `
        SYSTEM: You are LokSeva, an intelligent care assistant for Tirupati.
        YOUR GOAL: Help the user find a care agency from the list below.
        
        AVAILABLE AGENCIES:
        ${agencyContext}
        
        USER QUERY: "${message}"
        
        INSTRUCTIONS:
        - Only recommend agencies from the list.
        - If they ask for a specific location (e.g., Reddy Colony), find the closest match.
        - Provide the Agency Name and Phone Number clearly.
        `;

        // STEP 3: Call Gemini
        const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
        const result = await model.generateContent(prompt);
        const responseText = result.response.text();

        console.log("🤖 AI Reply:", responseText);
        res.json({ reply: responseText });

    } catch (error) {
        console.error("AI Error:", error);
        res.status(500).json({ error: "AI Service Unavailable" });
    }
});

// Endpoint 2: Get All Agencies (For the App's List View)
app.get('/api/agencies', (req, res) => {
    res.json(agenciesData);
});

// Start Server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 LokSeva Server running on port ${PORT}`);
    console.log(`📂 Serving Data Mode: LOCAL FILE (No Database Required)`);
});
