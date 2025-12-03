# Carbon Intensity Scheduler

A fully self-contained Node.js application with PostgreSQL that collects and processes UK carbon intensity data from the Carbon Intensity API on a scheduled basis.

## Features

- **Regional Update Job**: Runs every 30 minutes (at :00 and :30) to fetch current regional carbon intensity data
- **Daily Totals Job**: Runs daily at 00:02 to aggregate the previous day's data
- **Self-contained**: PostgreSQL database included in Docker Compose
- **Automatic setup**: Database schema created automatically on first run
- Environment-based configuration
- Health checks and graceful shutdown handling
- Data persistence with Docker volumes

## Scheduled Jobs

### Regional Update (Every 30 minutes)
- Fetches data from `https://api.carbonintensity.org.uk/regional`
- Processes all UK regions
- Calculates clean vs fossil fuel totals
- Stores half-hourly snapshots in the `live` table

### Regional Daily Totals (Daily at 00:02)
- Aggregates previous day's data by region
- Calculates daily averages for all fuel types
- Stores results in the `day` table

## Prerequisites

- Docker and Docker Compose (that's it!)

## Quick Start

1. **Clone and setup**
   ```bash
   cp .env.example .env
   # Edit .env to change the default password
   nano .env
   ```

2. **Start the entire stack**
   ```bash
   docker-compose up -d
   ```

3. **View logs**
   ```bash
   # View scheduler logs
   docker-compose logs -f scheduler
   
   # View all logs
   docker-compose logs -f
   ```

4. **Check status**
   ```bash
   docker-compose ps
   ```

That's it! Both the database and scheduler are now running.

## Configuration

Environment variables (set in `.env` file):

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_USER` | PostgreSQL user | `postgres` |
| `DB_PASSWORD` | PostgreSQL password | `changeme` |
| `DB_NAME` | Database name | `carbon_intensity` |
| `DB_PORT` | PostgreSQL port (host) | `5432` |

## Accessing the Database

The PostgreSQL database is accessible from your host machine:

```bash
# Using psql
psql -h localhost -p 5432 -U postgres -d carbon_intensity

# Using a GUI tool (DBeaver, pgAdmin, etc.)
# Host: localhost
# Port: 5432
# Database: carbon_intensity
# User: postgres
# Password: (whatever you set in .env)
```

## Database Schema

The application automatically creates two tables on first run:

- **`public.live`**: Half-hourly regional data with carbon intensity and generation mix
- **`public.day`**: Daily aggregated averages by region

## Docker Commands

```bash
# Start everything
docker-compose up -d

# Stop everything
docker-compose down

# Stop and remove all data (WARNING: deletes database!)
docker-compose down -v

# Restart just the scheduler
docker-compose restart scheduler

# View real-time logs
docker-compose logs -f

# Rebuild after code changes
docker-compose up -d --build

# Check resource usage
docker stats
```

## Data Persistence

Database data is stored in a Docker volume named `postgres-data`. This means:
- Data persists across container restarts
- Data survives `docker-compose down`
- Data is only deleted with `docker-compose down -v`

## Backup and Restore

The application includes comprehensive backup and restore scripts.

### Manual Backup

Create a backup anytime:

```bash
chmod +x backup.sh
./backup.sh
```

This creates a compressed backup in the `./backups` directory with a timestamp:
- Filename: `carbon_intensity_YYYYMMDD_HHMMSS.sql.gz`
- Automatic cleanup of backups older than 30 days
- Creates a `latest.sql.gz` symlink to the most recent backup

### Automated Backups

Set up automated backups with cron:

```bash
chmod +x setup-backup-cron.sh
./setup-backup-cron.sh
```

Choose from several schedules:
1. Daily at 2:00 AM
2. Daily at 3:00 AM (recommended - runs after the daily totals job)
3. Twice daily (2:00 AM and 2:00 PM)
4. Every 6 hours
5. Custom schedule

Backup logs are written to `backup.log`.

### List Backups

View all available backups:

```bash
chmod +x list-backups.sh
./list-backups.sh
```

### Restore from Backup

Restore a specific backup:

```bash
chmod +x restore.sh
./restore.sh carbon_intensity_20251203_150000.sql.gz
```

Or restore the latest backup:

```bash
./restore.sh latest
```

The restore script:
- Creates a safety backup before restoring
- Prompts for confirmation
- Verifies the restore was successful
- Shows record counts after restore

### Backup Best Practices

1. **Test restores regularly** - Verify backups are working
2. **Store backups externally** - Copy to S3, NAS, or other location
3. **Monitor backup size** - Ensure disk space is sufficient
4. **Keep retention policy reasonable** - Default is 30 days

### External Backup Storage

To copy backups to external storage:

```bash
# AWS S3
aws s3 sync ./backups s3://your-bucket/carbon-backups/

# rsync to remote server
rsync -avz ./backups/ user@server:/backups/carbon-intensity/

# Synology NAS
rsync -avz ./backups/ /volume1/backups/carbon-intensity/
```

## Monitoring

The application logs all job executions:

```
[2025-12-03T12:00:00.000Z] Starting Regional Update job...
Fetched 17 regions
[2025-12-03T12:00:03.456Z] Regional Update job completed successfully
```

The database has a health check that ensures it's ready before the scheduler starts.

## Troubleshooting

**Containers won't start:**
```bash
# Check logs
docker-compose logs

# Check if port 5432 is already in use
lsof -i :5432  # macOS/Linux
netstat -ano | findstr :5432  # Windows
```

**Database connection fails:**
- Wait 10-15 seconds after startup for health checks to pass
- Check logs: `docker-compose logs postgres`
- Verify .env file has correct credentials

**Jobs not running:**
```bash
# Check scheduler logs
docker-compose logs scheduler

# Restart scheduler
docker-compose restart scheduler
```

**Need to reset everything:**
```bash
# Stop and remove all containers and data
docker-compose down -v

# Start fresh
docker-compose up -d
```

## Architecture

```
┌─────────────────────────────────────┐
│   Carbon Intensity API              │
│   api.carbonintensity.org.uk        │
└────────────┬────────────────────────┘
             │
             │ HTTP GET (every 30 min)
             │
      ┌──────▼──────┐
      │  Scheduler  │
      │  Container  │
      │             │
      │  Node.js    │
      │  + cron     │
      └──────┬──────┘
             │
             │ PostgreSQL Protocol
             │
      ┌──────▼──────┐
      │  PostgreSQL │
      │  Container  │
      │             │
      │  Port: 5432 │
      └─────────────┘
             │
             │ Volume Mount
             │
      ┌──────▼──────┐
      │   Docker    │
      │   Volume    │
      │ (postgres-  │
      │   data)     │
      └─────────────┘
```

## Development

To modify schedules, edit the cron expressions in `index.js`:
- `'0,30 * * * *'` - Regional Update (every 30 minutes)
- `'2 0 * * *'` - Daily Totals (00:02 daily)

Then rebuild:
```bash
docker-compose up -d --build
```

## Production Deployment

For production:

1. **Change the password** in `.env`
2. **Restrict database port** (remove port mapping if not needed externally)
3. **Set up monitoring** (consider adding Prometheus/Grafana)
4. **Configure backups** (automated pg_dump scripts)
5. **Add log aggregation** (ELK stack, Loki, etc.)

## License

MIT