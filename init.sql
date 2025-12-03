-- Create the live table for half-hourly data
CREATE TABLE IF NOT EXISTS public.live (
    id SERIAL PRIMARY KEY,
    region INTEGER NOT NULL,
    "from" VARCHAR(10),
    "to" VARCHAR(10),
    date VARCHAR(20),
    carbon_forecast INTEGER,
    carbon_index VARCHAR(20),
    biomass NUMERIC(10, 2),
    nuclear NUMERIC(10, 2),
    hydro NUMERIC(10, 2),
    solar NUMERIC(10, 2),
    wind NUMERIC(10, 2),
    gas NUMERIC(10, 2),
    coal NUMERIC(10, 2),
    imports NUMERIC(10, 2),
    other NUMERIC(10, 2),
    cleaner_total NUMERIC(10, 2),
    fossil_total NUMERIC(10, 2),
    created TIMESTAMP,
    json JSONB
);

-- Create the day table for daily aggregates
CREATE TABLE IF NOT EXISTS public.day (
    id SERIAL PRIMARY KEY,
    region INTEGER NOT NULL,
    date VARCHAR(20),
    biomass NUMERIC(10, 2),
    nuclear NUMERIC(10, 2),
    hydro NUMERIC(10, 2),
    solar NUMERIC(10, 2),
    wind NUMERIC(10, 2),
    cleaner_total NUMERIC(10, 2),
    gas NUMERIC(10, 2),
    coal NUMERIC(10, 2),
    imports NUMERIC(10, 2),
    other NUMERIC(10, 2),
    fossil_total NUMERIC(10, 2),
    created TIMESTAMP
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_live_region ON public.live(region);
CREATE INDEX IF NOT EXISTS idx_live_created ON public.live(created);
CREATE INDEX IF NOT EXISTS idx_live_date ON public.live(date);
CREATE INDEX IF NOT EXISTS idx_day_region ON public.day(region);
CREATE INDEX IF NOT EXISTS idx_day_created ON public.day(created);