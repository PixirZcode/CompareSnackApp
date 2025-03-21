const express = require('express');
const puppeteer = require('puppeteer');
const axios = require('axios');
const cors = require('cors');
const admin = require('firebase-admin');

const app = express();
const PORT = 3000;

app.use(cors());  // เริ่มใช้ cors เพื่อที่จะดึงข้อมูลจากที่ต่างๆ

// redis สำหรับเก็บ cache
const redis = require('redis');
const client = redis.createClient({ host: 'localhost', port: 6379 });  // เชื่อมต่อกับเซิร์ฟเวอร์ Redis ตัวเอง
client.on('พบข้อผิดพลาด', (err) => console.log('Redis Client ผิดพลาด', err));

client.connect();

const getCache = async (key) => {
  const data = await client.get(key);
  return data ? JSON.parse(data) : null;
};

const setCache = async (key, data) => {
  await client.set(key, JSON.stringify(data), { EX: 18000 });  // ตั้งแคชไว้ 1 ชั่วโมง = 3600
};

/* API ของ ScraperAPI
/ acc demoprojectx3 e421828fbedffc3475a3793dcc285324 */
const SCRAPER_API_KEY = '428893d6207e2045bf147fac47d4ab59';


// path สำหรับไว้เช็คสถานะ server
app.get('/', (req, res) => {
  res.send('Server is running. Use /scrap?site=(bigc or lotus) to fetch data.');

});

// ดึงหมวดหมู่จาก BigC API
async function scrapCategories() {
  try {
    const { data } = await axios.post(
      "https://openapi.bigc.co.th/composite/v3/products/es/categories",
      {
        slug: "snack",
        lang: "th",
      }
    );
    return data.data.products_summary.filters.category_child;
  } catch (error) {
    console.error("[Error] ScrapCategories BigC:", error);
    throw error;
  }
}

// เริ่มต้น Firebase Admin SDK ด้วย service account
admin.initializeApp({
  credential: admin.credential.cert('D:/project/lib/Scraping/serviceAccountKey.json')
});

// ดึงค่าจาก Firestore
const fetchConfigValue = async () => {
  const docRef = admin.firestore().doc('/configurations/CEIUs5vEhBItAv679IEX');
  const doc = await docRef.get();

  if (!doc.exists) {
    throw new Error('No such document');
  } else {
    const data = doc.data();

    // ใช้ชื่อฟิลด์ที่มีเครื่องหมาย "" ล้อมรอบ
    const value = data['"value"']; // เข้าถึงฟิลด์ value ด้วยเครื่องหมาย ""

    if (!value) {
      throw new Error('Value field is missing or undefined in Firestore document');
    }
    return value;
  }
};

// ดึงสินค้าจาก BigC API ตามหมวดหมู่
async function fetchBigcData(slug) {
  try {

 // ดึงค่า value จาก Firestore
     const valueUrl = await fetchConfigValue();

    const response = await axios.get(
      `${valueUrl}/${slug}.json?slug=${slug}`
    );
    const productData = response.data.pageProps.productCategory.products_summary.products;

    return productData.map(product => {
      // Extract weight (กรัม, ก.) and pack size (แพ็ค, x, X)
      const weightMatch = product.name.match(/(\d+)\s?(กรัม|ก\.)/);
      const packMatch = product.name.match(/(?:แพ็ค|x|X)\s*(\d+)/);

      let totalWeight = 0;

      if (weightMatch) {
        const weight = parseInt(weightMatch[1], 10);  // สกัดน้ำหนักจากชื่อสินค้ากรัมหรือก

        if (packMatch) {
          const packSize = parseInt(packMatch[1], 10);  // จำนวนขนาดแพ็ค
          totalWeight = weight * packSize;  // นำกรัม*จำนวนแพ็คจากชื่อ เช่น A 3ก. แพ็ค 3 = 3x3 = 9
        } else {
          totalWeight = weight;  // เก็บแค่กรัมกรณีชื่อสินค้าไม่มีการระบุจำนวนแพ็ค
        }
      }

      return {
        title: product.name,
        url: `https://www.bigc.co.th/product/${product.slug}.${product.product_id}`,
        image: product.thumbnail_image,
        price: product.final_price_incl_tax,
        unit: product.unit,
        stockStatus: product.stock,
        value: (totalWeight / product.final_price_incl_tax).toFixed(2),
        shop: 'BigC',
      };
    });
  } catch (error) {
    console.error("[Error] fetchBigcData:", error);
    throw error;
  }
}

// ดึงข้อมูลจาก API ของ Lotus
const fetchLotusData = async () => {
  const url = `https://api-o2o.lotuss.com/lotuss-mobile-bff/product/v4/products?category_id=86707`;
  try {
    const response = await axios.get(url);
    return response.data.data.products.map(product => {
      // ตรวจสอบว่าในชื่อสินค้ามีคำว่า "แพ็ค" หรือไม่
      const unitFromName = /แพ็ค|[Xx]\s?\d+/.test(product.name) ? "แพ็ค" : product.unitOfQuantity;

      // สกัดน้ำหนักจากชื่อสินค้า (กรัม, ก.)
      const weightMatch = product.name.match(/(\d+)\s?(กรัม|ก\.)?/);  // เพิ่ม ? เพื่อรองรับกรณีไม่มีช่องว่าง
      const packMatch = product.name.match(/(?:แพ็ค|x|X)\s*(\d+)/);
      const packMatchNoSpace = product.name.match(/(\d+)\s?ก\s?[Xx]\s*(\d+)/);  // จับกรณี "48กX6"

      let totalWeight = 0;

      if (packMatchNoSpace) {
        // สำหรับชื่อที่มีรูปแบบ "48กX6" ให้คำนวณน้ำหนักโดยตรง
        const weight = parseInt(packMatchNoSpace[1], 10);  // นำ 48 กรัม
        const packSize = parseInt(packMatchNoSpace[2], 10);  // นำ 6 แพ็ค
        totalWeight = weight * packSize;  // คำนวณน้ำหนักรวม
      } else if (weightMatch) {
        const weight = parseInt(weightMatch[1], 10);  // สกัดน้ำหนักจากชื่อสินค้ากรัมหรือก

        if (packMatch) {
          const packSize = parseInt(packMatch[1], 10);  // จำนวนขนาดแพ็ค
          totalWeight = weight * packSize;  // นำกรัม*จำนวนแพ็คจากชื่อ เช่น A 15กรัม แพ็ค 12 = 15x12 = 180
        } else {
          totalWeight = weight;  // เก็บแค่กรัมกรณีชื่อสินค้าไม่มีการระบุจำนวนแพ็ค
        }
      } else if (product.weight) {
        // ถ้าไม่พบข้อมูลน้ำหนักในชื่อสินค้า ให้ใช้ product.weight จาก API
        totalWeight = product.weight;
      }

      // คำนวณความคุ้มค่า (value) ด้วยน้ำหนักรวมและราคาสินค้า
      const value = totalWeight && product.finalPricePerUOW ? (totalWeight / product.finalPricePerUOW).toFixed(2) : 'N/A';

      return {
        title: product.name,
        url: `https://www.lotuss.com/th/product/${product.urlKey}`,
        image: product.thumbnail.url,
        price: product.finalPricePerUOW,
        unit: unitFromName,  // ชิ้น/แพ็ค
        stockStatus: product.stockStatus, // สถานะสินค้า
        value: value, // ความคุ้มค่า
        shop: 'Lotus',
      };
    });
  } catch (error) {
    console.error('[Error] fetchLotusData:', error);
    throw error;
  }
};


app.get('/scrap', async (req, res) => {
  const site = req.query.site || 'Unknow';  // ร้องขอชื่อ website

 const cacheKey = `product:${site}`;

  try {
    // ตรวจสอบแคช Redis
    let cachedData = await getCache(cacheKey);
    const categories = await scrapCategories();

    if (cachedData) {
      return res.json(cachedData);  // ส่งคืนข้อมูลหากมีข้อมูลในแคชแล้ว
    }

    // ไม่มีข้อมูลสิ่งๆนั้นในแคชให้ทำการ Scrap
    let products = [];
    if (site === 'lotus') {
      products = await fetchLotusData();
    } else if(site ==='bigc'){
      for (const category of categories) {
            const pd = await fetchBigcData(category.slug);
            products = products.concat(pd);  // รวมสินค้าจากทุกหมวดหมู่เข้าไปในลิสต์
          }
    }

    if (products.length === 0) {
      return res.status(404).send('ไม่พบข้อมูลสินค้าสำหรับคำค้นหาที่ระบุ');
    }

    // Cache the scraped data
    await setCache(cacheKey, products);

    res.json(products);
  } catch (error) {
    console.error('ข้อผิดพลาดระหว่างการ Scrap ข้อมูล:', error);
    res.status(500).send('เกิดข้อผิดพลาดขณะทำการ Scrap ข้อมูล');
  }
});

const scrapLotusPromotions = async (page, url) => {
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('.card');

  return await page.evaluate(() => {
    const items = [];
    document.querySelectorAll('.card').forEach(item => {
      const title = item.querySelector('.card-title')?.innerText || 'No Title Available';
      const url = item.querySelector('a')?.href || '';
      const image = item.querySelector('img')?.src || '';
      const date = item.querySelector('.card-text')?.innerText || 'No Date Available';

      if (title && url && image) {
        items.push({ title, url, image, date, source: 'Lotus' });
      }
    });
    return items;
  });
};

const scrapBigcPromotions = async (url) => {
  // ใช้ ScraperAPI เพื่อดึงข้อมูล HTML ของหน้า
  const response = await axios.get('http://api.scraperapi.com', {
    params: {
      api_key: SCRAPER_API_KEY,
      url: url,
      render: true, // เพื่อให้สามารถรับ Scrap เว็บในรูปแบบไดนามิก
    },
  });
  const html = response.data;

  // เปิดตัว Puppeteer เพื่อดู HTML และดึงข้อมูล
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.setContent(html);

  // รอให้รายการโหลดเสร็จ
  await page.waitForSelector('.carousel-item', { timeout: 5000 });

  const data = await page.evaluate(() => {
    const items = [];
    document.querySelectorAll('.carousel-item').forEach(item => {
      const title = item.querySelector('.cut-text-2line')?.innerText || 'No Title Available';
      const url = item.querySelector('a')?.href || '';
      const image = item.querySelector('img')?.src || '';
      // ต้องทำลิงค์รูปใหม่อีกทีเพราะมีการเพิ่มที่อยู่ของลิงค์ด้านหน้าเพื่อที่จะดู คือ https://corporate.bigc.co.th/
      const fullImageUrl = image.startsWith('http') ? image : `https://corporate.bigc.co.th/${image}`;

      if (title && url && image) {
        items.push({ title, url, fullImageUrl, source: 'Big C' });
      }
    });
    return items;
  });

  console.log('Scraped Promotions:', data);  // แสดง log ข้อมูลที่ scrap ได้ใน cmd

  await browser.close();
  return data;
};

app.get('/promotions', async (req, res) => {
  const site = req.query.site;
  if (!site || !['lotus', 'bigc'].includes(site)) {
    return res.status(400).send('พารามิเตอร์ไซต์ไม่ถูกต้อง ใช้ ?site=lotus หรือ ?site=bigc');
  }
  // เก็บ cacheKey ในรูปแบบ Ex. promotion:bigc
  const cacheKey = `promotions:${site}`;
  try {
    let cachedData = await getCache(cacheKey);
    if (cachedData) {
      return res.json(cachedData);
    }

    let promotions = [];
    const url = site === 'lotus'
      ? 'https://corporate.lotuss.com/promotions'
      : 'https://corporate.bigc.co.th/promotion';

    if (site === 'lotus') {
      const browser = await puppeteer.launch({ headless: true });
      const page = await browser.newPage();
      promotions = await scrapLotusPromotions(page, url);
      await browser.close();
    } else {
      promotions = await scrapBigcPromotions(url);
    }

    await setCache(cacheKey, promotions);
    res.json(promotions);
  } catch (error) {
    console.error('เกิดข้อผิดพลาดในการ Scrap ข้อมูลโปรโมชัน:', error);
    res.status(500).send('เกิดข้อผิดพลาดขณะทำการ Scrap ข้อมูลโปรโมชัน');
  }
});

// รัน server
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});

/* cmd -> node server.js เพื่อรัน server
npx puppeteer browsers install chrome
npm install express cors
npm install puppeteer
npm install firebase-admin

ตัวอย่างลิงค์ เมื่อ server ครอบด้วย scraperAPI
http://api.scraperapi.com/?api_key=e421828fbedffc3475a3793dcc285324&url=https://www.amazon.com/s?k=lays%20potato&render=true
*/
