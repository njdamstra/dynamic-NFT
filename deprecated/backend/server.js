// this will fetch NFT floor prices from the OpenSea API
require("dotenv").config();
const express = require("express");
const axios = require("axios");

const app = express();
app.use(express.json());

// Endpoint to fetch the floor price from OpenSea
app.post("/getFloorPrice", async (req, res) => {
    const { collectionSlug } = req.body;

    if (!collectionSlug) {
        return res.status(400).json({ error: "Collection slug is required" });
    }

    try {
        const url = `https://api.opensea.io/api/v1/collection/${collectionSlug}`;
        const response = await axios.get(url, {
            headers: { "Accept": "application/json" },
        });
        console.log("API Response:", response.data);

        const collection = response.data.collection;
        if (!collection || !collection.stats || collection.stats.floor_price === undefined) {
            return res.status(404).json({ error: "Floor price not found" });
        }


        const floorPrice = collection.stats.floor_price;
        res.json({ floorPrice });
    } catch (error) {
        console.error("Error fetching floor price:", error.message);
        res.status(500).json({ error: "Failed to fetch floor price" });
    }
});

// Start the server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});
