const cron = require('node-cron');
const axios = require('axios');
const { Pool } = require('pg');

// Database configuration from environment variables
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'postgres',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
});

// Regional Update Job - runs every 30 minutes
async function regionalUpdateJob() {
  console.log(`[${new Date().toISOString()}] Starting Regional Update job...`);
  
  try {
    // Wait 3 seconds (as per the original workflow)
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Fetch data from Carbon Intensity API
    const response = await axios.get('https://api.carbonintensity.org.uk/regional');
    const regions = response.data.data[0].regions;
    
    console.log(`Fetched ${regions.length} regions`);
    
    // Process each region
    for (const region of regions) {
      const generationmix = region.generationmix;
      
      // Helper function to find fuel percentage
      const findFuel = (fuel) => generationmix.find(item => item.fuel === fuel)?.perc || 0;
      
      // Calculate totals
      const biomass = findFuel('biomass');
      const nuclear = findFuel('nuclear');
      const hydro = findFuel('hydro');
      const solar = findFuel('solar');
      const wind = findFuel('wind');
      const gas = findFuel('gas');
      const coal = findFuel('coal');
      const imports = findFuel('imports');
      const other = findFuel('other');
      
      const cleanerTotal = parseFloat((biomass + nuclear + hydro + solar + wind).toFixed(2));
      const fossilTotal = parseFloat((gas + coal + imports + other).toFixed(2));
      
      // Format times and dates
      const fromDate = new Date(response.data.data[0].from);
      const toDate = new Date(response.data.data[0].to);
      
      const fromTime = fromDate.toLocaleTimeString('en-GB', {
        timeZone: 'Europe/London',
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
      });
      
      const toTime = toDate.toLocaleTimeString('en-GB', {
        timeZone: 'Europe/London',
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
      });
      
      const date = toDate.toLocaleDateString('en-GB', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric'
      });
      
      // Filter and sort generation mix for JSON column
      const jsonData = generationmix
        .filter(item => item.perc > 0)
        .sort((a, b) => b.perc - a.perc);
      
      // Insert into database
      const query = `
        INSERT INTO public.live (
          region, carbon_forecast, biomass, nuclear, hydro, solar, wind, 
          gas, coal, imports, other, cleaner_total, fossil_total, 
          "from", "to", date, carbon_index, json, created
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
      `;
      
      const values = [
        region.regionid,
        region.intensity.forecast,
        biomass,
        nuclear,
        hydro,
        solar,
        wind,
        gas,
        coal,
        imports,
        other,
        cleanerTotal,
        fossilTotal,
        fromTime,
        toTime,
        date,
        region.intensity.index,
        JSON.stringify(jsonData),
        toDate
      ];
      
      await pool.query(query, values);
    }
    
    console.log(`[${new Date().toISOString()}] Regional Update job completed successfully`);
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Error in Regional Update job:`, error.message);
  }
}

// Regional Daily Totals Job - runs at 00:02 daily
async function regionalDailyTotalsJob() {
  console.log(`[${new Date().toISOString()}] Starting Regional Daily Totals job...`);
  
  try {
    // Get distinct regions
    const regionsResult = await pool.query('SELECT DISTINCT region FROM public.live ORDER BY region ASC');
    const regions = regionsResult.rows;
    
    console.log(`Processing ${regions.length} regions for daily totals`);
    
    // Process each region
    for (const regionRow of regions) {
      const query = `
        INSERT INTO public.day (
          region, date, biomass, nuclear, hydro, solar, wind, cleaner_total, 
          gas, coal, imports, other, fossil_total, created
        )
        SELECT 
          region, 
          date,
          ROUND(AVG(biomass)::NUMERIC, 2) as biomass,
          ROUND(AVG(nuclear)::NUMERIC, 2) as nuclear,
          ROUND(AVG(hydro)::NUMERIC, 2) as hydro,
          ROUND(AVG(solar)::NUMERIC, 2) as solar,
          ROUND(AVG(wind)::NUMERIC, 2) as wind,
          ROUND(AVG(cleaner_total)::NUMERIC) as cleaner_total,
          ROUND(AVG(gas)::NUMERIC, 2) as gas,
          ROUND(AVG(coal)::NUMERIC, 2) as coal,
          ROUND(AVG(imports)::NUMERIC, 2) as imports,
          ROUND(AVG(other)::NUMERIC, 2) as other,
          ROUND(AVG(fossil_total)::NUMERIC) as fossil_total,
          created + INTERVAL '1 day' as created
        FROM public.live
        WHERE created = CURRENT_DATE - INTERVAL '1 day' 
          AND region = $1
        GROUP BY region, date, created
      `;
      
      await pool.query(query, [regionRow.region]);
    }
    
    console.log(`[${new Date().toISOString()}] Regional Daily Totals job completed successfully`);
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Error in Regional Daily Totals job:`, error.message);
  }
}

// Schedule jobs
console.log('Starting Carbon Intensity Scheduler...');

// Regional Update - every 30 minutes (at :00 and :30)
cron.schedule('0,30 * * * *', regionalUpdateJob);
console.log('✓ Regional Update job scheduled (every 30 minutes)');

// Regional Daily Totals - at 00:02 daily
cron.schedule('2 0 * * *', regionalDailyTotalsJob);
console.log('✓ Regional Daily Totals job scheduled (daily at 00:02)');

console.log('Scheduler is running. Press Ctrl+C to exit.');

// Test database connection on startup
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('Database connection error:', err.message);
    process.exit(1);
  }
  console.log('✓ Database connected successfully');
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully...');
  await pool.end();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully...');
  await pool.end();
  process.exit(0);
});