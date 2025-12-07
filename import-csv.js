const fs = require('fs');
const { parse } = require('csv-parse');
const { Pool } = require('pg');
require('dotenv').config();

// Database configuration
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

// Get CSV filename from command line argument
const csvFile = process.argv[2];

if (!csvFile) {
  console.error('Usage: node import-csv.js <path-to-csv-file>');
  console.error('Example: node import-csv.js historical-data.csv');
  process.exit(1);
}

if (!fs.existsSync(csvFile)) {
  console.error(`Error: File not found: ${csvFile}`);
  process.exit(1);
}

console.log(`Reading CSV file: ${csvFile}`);
console.log('');

const records = [];
let rowCount = 0;
let errorCount = 0;

// Column names in order (no header in the file)
const columnNames = [
  'region', 'date', 'biomass', 'nuclear', 'hydro', 'solar', 'wind',
  'cleaner_total', 'gas', 'coal', 'imports', 'other', 'fossil_total', 'created'
];

// Parse CSV/TSV file
fs.createReadStream(csvFile)
  .pipe(parse({
    columns: columnNames, // Manually specify column names
    skip_empty_lines: true,
    trim: true,
    delimiter: '\t',
    quote: '"',
    relax_column_count: true,
  }))
  .on('data', (row) => {
    rowCount++;
    records.push(row);
  })
  .on('error', (error) => {
    console.error('CSV parsing error:', error.message);
    process.exit(1);
  })
  .on('end', async () => {
    console.log(`Parsed ${rowCount} rows from CSV`);
    console.log('');
    
    // Show first row as sample
    if (records.length > 0) {
      console.log('Sample row (first record):');
      console.log(JSON.stringify(records[0], null, 2));
      console.log('');
    }
    
    console.log('Starting import...');
    console.log('');
    
    let imported = 0;
    let skipped = 0;
    
    for (const row of records) {
      try {
        // Parse numeric values, handling potential nulls or empty strings
        const parseNum = (val) => {
          // Remove quotes if present
          const cleaned = typeof val === 'string' ? val.replace(/"/g, '').trim() : val;
          const num = parseFloat(cleaned);
          return isNaN(num) ? 0 : num;
        };
        
        const biomass = parseNum(row.biomass);
        const nuclear = parseNum(row.nuclear);
        const hydro = parseNum(row.hydro);
        const solar = parseNum(row.solar);
        const wind = parseNum(row.wind);
        const gas = parseNum(row.gas);
        const coal = parseNum(row.coal);
        const imports = parseNum(row.imports);
        const other = parseNum(row.other);
        
        // Get totals from CSV or calculate
        let cleanerTotal = parseNum(row.cleaner_total);
        let fossilTotal = parseNum(row.fossil_total);
        
        if (cleanerTotal === 0 && (biomass + nuclear + hydro + solar + wind) > 0) {
          cleanerTotal = parseFloat((biomass + nuclear + hydro + solar + wind).toFixed(2));
        }
        
        if (fossilTotal === 0 && (gas + coal + imports + other) > 0) {
          fossilTotal = parseFloat((gas + coal + imports + other).toFixed(2));
        }
        
        // Build the JSON array with non-zero values, sorted high to low
        const generationMix = [
          { fuel: 'biomass', perc: biomass },
          { fuel: 'nuclear', perc: nuclear },
          { fuel: 'hydro', perc: hydro },
          { fuel: 'solar', perc: solar },
          { fuel: 'wind', perc: wind },
          { fuel: 'gas', perc: gas },
          { fuel: 'coal', perc: coal },
          { fuel: 'imports', perc: imports },
          { fuel: 'other', perc: other }
        ];
        
        const jsonData = generationMix
          .filter(item => item.perc > 0)
          .sort((a, b) => b.perc - a.perc);
        
        // Parse region
        const region = parseInt(row.region);
        
        // Parse date (remove quotes and handle DD/MM/YYYY format)
        const dateStr = row.date.replace(/"/g, '').trim();
        
        // Parse created timestamp
        const createdStr = row.created.replace(/"/g, '').trim();
        const created = new Date(createdStr);
        
        if (isNaN(region)) {
          console.warn(`Row ${imported + skipped + 1}: Invalid region, skipping`);
          skipped++;
          continue;
        }
        
        if (!dateStr) {
          console.warn(`Row ${imported + skipped + 1}: No date found, skipping`);
          skipped++;
          continue;
        }
        
        // Insert into database
        const query = `
          INSERT INTO public.day (
            region, date, biomass, nuclear, hydro, solar, wind, cleaner_total,
            gas, coal, imports, other, fossil_total, json, created
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
        `;
        
        await pool.query(query, [
          region,
          dateStr,
          biomass,
          nuclear,
          hydro,
          solar,
          wind,
          cleanerTotal,
          gas,
          coal,
          imports,
          other,
          fossilTotal,
          JSON.stringify(jsonData),
          created
        ]);
        
        imported++;
        
        // Progress indicator
        if (imported % 100 === 0) {
          console.log(`Imported ${imported} records...`);
        }
        
      } catch (error) {
        errorCount++;
        console.error(`Error importing row ${imported + skipped + 1}:`, error.message);
        console.error('Row data:', row);
        
        // Stop if too many errors
        if (errorCount > 10) {
          console.error('Too many errors, stopping import');
          break;
        }
      }
    }
    
    console.log('');
    console.log('═══════════════════════════════════════');
    console.log('Import Complete');
    console.log('═══════════════════════════════════════');
    console.log(`Total rows in CSV: ${rowCount}`);
    console.log(`Successfully imported: ${imported}`);
    console.log(`Skipped: ${skipped}`);
    console.log(`Errors: ${errorCount}`);
    console.log('');
    
    await pool.end();
    process.exit(errorCount > 10 ? 1 : 0);
  });