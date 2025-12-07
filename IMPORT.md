# CSV Import Guide

This guide explains how to import historical data into the `day` table from a CSV file.

## Quick Start

```bash
# Install dependencies first
npm install

# Import your CSV file
node import-csv.js your-data.csv
```

## CSV Format

The import script is flexible and accepts various column name formats. It will look for columns in different case variations (e.g., `biomass`, `Biomass`, `BIOMASS`).

### Required Columns

- **region** (or `Region`, `regionid`) - Region ID number
- **date** (or `Date`) - Date in DD/MM/YYYY or any parseable format

### Optional Columns

All fuel type columns are optional. If missing, they default to 0:

- **biomass** (or `Biomass`)
- **nuclear** (or `Nuclear`)
- **hydro** (or `Hydro`)
- **solar** (or `Solar`)
- **wind** (or `Wind`)
- **gas** (or `Gas`)
- **coal** (or `Coal`)
- **imports** (or `Imports`)
- **other** (or `Other`)

### Calculated Columns

These will be auto-calculated if not provided:

- **cleaner_total** (or `cleaner`, `clean`) - Sum of biomass + nuclear + hydro + solar + wind
- **fossil_total** (or `fossil`) - Sum of gas + coal + imports + other

### Example CSV Formats

**Format 1: Simple**
```csv
region,date,biomass,nuclear,hydro,solar,wind,gas,coal,imports,other
1,01/12/2024,5.2,15.3,2.1,8.4,35.6,28.9,0.0,4.5,0.0
2,01/12/2024,4.8,18.2,1.9,6.7,32.4,31.2,0.0,4.8,0.0
```

**Format 2: With Totals**
```csv
Region,Date,Biomass,Nuclear,Hydro,Solar,Wind,Gas,Coal,Imports,Other,cleaner_total,fossil_total
1,01/12/2024,5.2,15.3,2.1,8.4,35.6,28.9,0.0,4.5,0.0,66.6,33.4
2,01/12/2024,4.8,18.2,1.9,6.7,32.4,31.2,0.0,4.8,0.0,64.0,36.0
```

**Format 3: With Created Timestamp**
```csv
region,date,biomass,nuclear,hydro,solar,wind,gas,coal,imports,other,created
1,01/12/2024,5.2,15.3,2.1,8.4,35.6,28.9,0.0,4.5,0.0,2024-12-01T00:00:00Z
```

## What the Script Does

1. **Reads your CSV file** - Parses all rows
2. **Validates data** - Checks for required fields (region, date)
3. **Calculates totals** - Auto-calculates cleaner_total and fossil_total if missing
4. **Creates JSON array** - Builds sorted generation mix array (filters zeros, sorts high to low)
5. **Imports to database** - Inserts all records into the `day` table
6. **Shows progress** - Displays progress every 100 records

## Running the Import

### Basic Usage

```bash
node import-csv.js historical-data.csv
```

### Example Output

```
Reading CSV file: historical-data.csv

Parsed 365 rows from CSV

Sample row (first record):
{
  "region": "1",
  "date": "01/01/2024",
  "biomass": "5.2",
  "nuclear": "15.3",
  "hydro": "2.1",
  "solar": "8.4",
  "wind": "35.6",
  "gas": "28.9",
  "coal": "0.0",
  "imports": "4.5",
  "other": "0.0"
}

Starting import...

Imported 100 records...
Imported 200 records...
Imported 300 records...

═══════════════════════════════════════
Import Complete
═══════════════════════════════════════
Total rows in CSV: 365
Successfully imported: 365
Skipped: 0
Errors: 0
```

## Troubleshooting

### "File not found" Error

Make sure the CSV file path is correct:
```bash
# Relative path
node import-csv.js ./data/historical.csv

# Absolute path
node import-csv.js /home/user/data/historical.csv
```

### "Missing required environment variables" Error

Ensure your `.env` file exists and contains database credentials:
```bash
cp .env.example .env
nano .env
```

### "Invalid region" Warnings

Check that your CSV has a `region` column with numeric values (1-17 for UK regions).

### Import Stops After Many Errors

The script stops if more than 10 errors occur. Check:
- CSV format matches expected columns
- Date format is valid (DD/MM/YYYY or ISO format)
- Region IDs are numeric
- No special characters in numeric fields

## Verifying the Import

After import, verify the data in your database:

```sql
-- Check total records imported
SELECT COUNT(*) FROM public.day;

-- Check records by region
SELECT region, COUNT(*) as days FROM public.day GROUP BY region ORDER BY region;

-- View sample records
SELECT * FROM public.day LIMIT 10;

-- Check the JSON arrays
SELECT region, date, json FROM public.day LIMIT 5;
```

## Re-importing Data

If you need to re-import:

1. **Clear existing data** (optional):
   ```sql
   TRUNCATE TABLE public.day;
   ```

2. **Re-run the import**:
   ```bash
   node import-csv.js your-data.csv
   ```

## Tips

- **Test with a small file first** - Try importing 10-20 rows to verify format
- **Check the sample row** - The script shows the first row after parsing
- **Large files** - The script handles large files efficiently with streaming
- **Date formats** - Supports DD/MM/YYYY, ISO format, or any JavaScript-parseable date
- **Case insensitive** - Column names can be any case (biomass, Biomass, BIOMASS)

## Need Help?

If you encounter issues:

1. Check the sample row output to see how your CSV is being parsed
2. Verify your CSV has required columns (region, date)
3. Ensure numeric fields contain valid numbers
4. Check database credentials in `.env`
5. Look at specific error messages for row numbers that failed