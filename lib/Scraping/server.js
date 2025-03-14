const express = require('express');
const puppeteer = require('puppeteer');
const axios = require('axios');
const cors = require('cors');

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
  await client.set(key, JSON.stringify(data), { EX: 3600 });  // ตั้งแคชไว้ 1 ชั่วโมง
};

/* API ของ ScraperAPI
/ acc demoprojectx3 e421828fbedffc3475a3793dcc285324
  acc vblackx02     29b1284868eb55b6933bd88a0ecc395e // acc vblackx02
*/
const SCRAPER_API_KEY = '428893d6207e2045bf147fac47d4ab59'; //


// path สำหรับไว้เช็คสถานะ server
app.get('/', (req, res) => {
  res.send('Server is running. Use /scrap?query=<product_name>&site=<bigc|lotus> to fetch data.');

});

// Scrap จาก bigc
const scrapBigc = async (page, url, retries = 3) => {
  let attempt = 0;
  let data = [];
  // กำหนด seenUrls เพื่อใช้สำหรับตรวจสอบชื่อข้อมูลที่ซ้ำโดยใช้ url ของข้อมูลสินค้านั้นๆ
  const seenUrls = new Set();

  while (attempt < retries) {
    try {
      await page.goto(url, { waitUntil: 'networkidle2' });
      data = await page.evaluate((seenUrlsArray) => {
        const seenUrls = new Set(seenUrlsArray);  // แปลงอาร์เรย์เป็น Set ใหม่ที่มี URL ไม่ซ้ำกัน
        const items = [];

        document.querySelectorAll('[class*="product"]').forEach(item => {
          const title = item.querySelector('.productCard_title__f1ohZ')?.innerText || 'No Title Available';
          const productUrl = item.querySelector('a')?.href || '';
          const image = item.querySelector('img')?.src || '';
          const price = item.querySelector('div.productCard_price__9T3J8')?.innerText || 'Not Available';
          const category = 'Big C';
          const isOutOfStock = item.querySelector('.productCard_text__Y6wJP')?.innerText || 'Have Stock';

          if (title && productUrl && image && !seenUrls.has(productUrl)) { // ตรวจสอบชื่อข้อมูลซ้ำซ้อนอิงตาม URL ของสินค้า
            // เพิ่ม productUrl ลง seenUrls ซึ่งเป็น Set ข้อมูลที่เคยเก็บไว้แล้ว เช่น ลิงค์ A ไม่เหมือนลิงค์ B ก็จะเก็บลิงค์ B ลง seenUrls
            seenUrls.add(productUrl);
            items.push({
              title,
              url: productUrl,
              image,
              price,
              category,
              isOutOfStock,
            });
          }
        });
        return items;
      }, Array.from(seenUrls));  // แปลงเป็นอาร์เรย์ก่อนส่งไปทำต่อ

      console.log('Scraped data:', data);  // แสดง log ข้อมูลที่ scrap ได้ใน cmd
      return data;
    } catch (error) {
      console.log(`Retrying (${attempt + 1}/${retries})...`);
      attempt++;
      if (attempt >= retries) {
        throw error;
      }
    }
  }
};

// Scrap จาก Lotus (ใช้ Puppeteer ไม่ใช้ ScraperAPI เพราะไม่สามรถทำได้)
const scrapLotus = async (page, url) => {
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('.product-grid-item');

  const data = await page.evaluate(() => {
    const items = [];
    console.log('Scraping started');  // log
    document.querySelectorAll('.product-grid-item').forEach(item => {
      const title = item.querySelector('.sc-eicpiI')?.innerText || 'No Title Available';
      const url = item.querySelector('a')?.href || '';
      const image = item.querySelector('img')?.src || '';
      const price = item.querySelector('.sc-kHxTfl')?.innerText || 'Not Available';
      const category = 'Lotus';
      console.log('Scraped product:', { title, price, url, image });  // Debugging log

      if (title && url && image) {
      const priceWithUnit = price !== 'Not Available' ? `${price} บาท` : price;
        items.push({
          title,
          url,
          image,
          price: priceWithUnit,  // ใช้ราคาที่มีหน่วย 'บาท'
          category,
        });
      }
    });
    return items;
  });

  console.log('Scraped data:', data);  // แสดง log ข้อมูลที่ scrap ได้ใน cmd

  return data;
};

app.get('/scrap', async (req, res) => {
  const productName = req.query.query;  // ร้องขอชื่อ product จาก query
  const site = req.query.site || 'Unknow';  // ร้องขอชื่อ website

  if (!productName) {
    return res.status(400).send('Query parameter "query" is required.');
  }
 const cacheKey = `product:${site}:${productName}`;

  try {
    // ตรวจสอบแคช Redis
    let cachedData = await getCache(cacheKey);
    if (cachedData) {
      return res.json(cachedData);  // ส่งคืนข้อมูลหากมีข้อมูลในแคชแล้ว
    }

    // ไม่มีข้อมูลสิ่งๆนั้นในแคชให้ทำการ Scrap
    let products = [];
    const searchUrl = site === 'lotus'
          ? `https://www.lotuss.com/th/search/${encodeURIComponent(productName)}?sort=relevance:DESC`
          :  `https://www.bigc.co.th/search?q=${encodeURIComponent(productName)}`

    console.log(`Scraping ${site}:`, searchUrl);

    if (site === 'lotus') {
      // ใช้ pupteer สำหรับ lotus
      const browser = await puppeteer.launch({ headless: true });
      const page = await browser.newPage();
      products = await scrapLotus(page, searchUrl);
      await browser.close();
    } else {
      // ใช้ pupteer และ ครอบ ScraperAPI กับ BigC ที่ทำงี้เพราะบอท BigC เข้มงวดมากๆ
      const response = await axios.get('http://api.scraperapi.com', {
        params: {
          api_key: SCRAPER_API_KEY,
          url: searchUrl,
          render: true,
        },
      });
      const html = response.data;
      const browser = await puppeteer.launch({ headless: true });
      const page = await browser.newPage();
      await page.setContent(html);
      const scrapFunction = site === 'bigc' ? scrapBigc : scrapLotus;
      products = await scrapFunction(page, searchUrl);
      await browser.close();
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

ตัวอย่างลิงค์ เมื่อ seerver ครอบด้วย scraperAPI
http://api.scraperapi.com/?api_key=e421828fbedffc3475a3793dcc285324&url=https://www.amazon.com/s?k=lays%20potato&render=true
*/

