const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// --- CONFIGURATION ---
const MONGO_URI = process.env.MONGO_URI;

// --- SCHEMA DEFINITION ---
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

// --- EXECUTE SEED ---
async function seedDatabase() {
  try {
    // 1. Read Data from JSON File
    const dataPath = path.join(__dirname, 'data', 'agencies.json');
    const rawData = fs.readFileSync(dataPath, 'utf-8');
    const agencies = JSON.parse(rawData);

    if (!agencies || agencies.length === 0) {
        console.log("❌ Error: data/agencies.json is empty or invalid.");
        process.exit(1);
    }

    // 2. Connect to DB
    await mongoose.connect(MONGO_URI);
    console.log("✅ Connected to MongoDB");

    // 3. Clear Old Data
    console.log("🧹 Clearing old agency data...");
    await Agency.deleteMany({});

    // 4. Insert New Data
    console.log(`🌱 Inserting ${agencies.length} agencies from file...`);
    await Agency.insertMany(agencies);

    console.log("🎉 SUCCESS! Database synced with data/agencies.json");
    process.exit();

  } catch (error) {
    console.error("❌ Seed Failed:", error);
    process.exit(1);
  }
}

seedDatabase();
