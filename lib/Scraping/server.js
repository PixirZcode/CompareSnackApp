const express = require('express');
const axios = require('axios');
const cors = require('cors');
const redis = require('redis');

const app = express();
const PORT = 3000;

app.use(cors());
const client = redis.createClient({ host: 'localhost', port: 6379 });
client.on('error', (err) => console.log('Redis Client Error', err));
client.connect();

const getCache = async (key) => {
  const data = await client.get(key);
  return data ? JSON.parse(data) : null;
};

const setCache = async (key, data) => {
  await client.set(key, JSON.stringify(data), { EX: 3600 });
};

// API Endpoints
const LOTUS_API = 'https://api-o2o.lotuss.com/lotuss-mobile-bff/product/v4/products?category_id=86707';
const BIGC_API = 'https://openapi.bigc.co.th/composite/v3/products/es/categories';

// Fetch products from Lotus API
const fetchLotusProducts = async () => {
  const response = await axios.get(LOTUS_API);
  return response.data.products.map(product => ({
    title: product.name,
    url: `https://www.lotuss.com/th/product/${product.sku}`,
    image: product.image,
    price: product.price || 'Not Available',
    category: 'Lotus',
  }));
};

// Fetch products from BigC API
const fetchBigCProducts = async () => {
  const response = await axios.get(BIGC_API);
  return response.data.products.map(product => ({
    title: product.name,
    url: `https://www.bigc.co.th/product/${product.sku}`,
    image: product.image,
    price: product.price || 'Not Available',
    category: 'Big C',
  }));
};

// API Endpoint for product scraping
app.get('/scrap', async (req, res) => {
  const site = req.query.site;
  if (!site || !['lotus', 'bigc'].includes(site)) {
    return res.status(400).send('Invalid site parameter. Use ?site=lotus or ?site=bigc');
  }

  const cacheKey = `product:${site}`;
  try {
    let cachedData = await getCache(cacheKey);
    if (cachedData) {
      return res.json(cachedData);
    }

    let products = site === 'lotus' ? await fetchLotusProducts() : await fetchBigCProducts();
    await setCache(cacheKey, products);
    res.json(products);
  } catch (error) {
    console.error('Error fetching product data:', error);
    res.status(500).send('Error fetching product data');
  }
});

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
