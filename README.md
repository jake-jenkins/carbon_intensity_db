# Carbon Intensity Scheduler

A Node.js application that collects and processes UK carbon intensity data from the Carbon Intensity API on a scheduled basis. Connects to your existing PostgreSQL database.

## Features

- **Regional Update Job**: Runs every 30 minutes (at :00 and :30) to fetch current regional carbon intensity data
- **Daily Totals Job**: Runs daily at 00:02 to aggregate the previous day's data
- **External Database**: Connects to your existing PostgreSQL database
- Environment-based configuration
- Health checks and graceful shutdown handling
- Comprehensive backup scripts

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

- Docker and Docker Compose
- PostgreSQL database (external - not included)

## Quick Start

1. **Setup your database**
   
   Run the `init.sql` script on your PostgreSQL database to create the required tables:
   ```bash
   psql -h your-db-host -U your-user -d your-database -f init.sql
   ```

2. **Configure credentials**
   ```bash
   cp .env.example .env
   nano .env  # Add your database credentials
   ```

3. **Start the scheduler**
   ```bash
   docker-compose up -d
   ```

4. **View logs**
   ```bash
   docker-compose logs -f
   ```

That's it! The scheduler is now running and will connect to your external database.

## Configuration

Environment variables (set in `.env` file):

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `DB_HOST` | PostgreSQL host | **Yes** | - |
| `DB_PORT` | PostgreSQL port | No | `5432` |
| `DB_NAME` | Database name | **Yes** | - |
| `DB_USER` | Database user | **Yes** | - |
| `DB_PASSWORD` | Database password | **Yes** | - |

## Database Schema

The application requires two tables in your PostgreSQL database. Run `init.sql` to create them:

- **`public.live`**: Half-hourly regional data with carbon intensity and generation mix
- **`public.day`**: Daily aggregated averages by region

## Docker Commands

```bash
# Start the scheduler
docker-compose up -d

# Stop the scheduler
docker-compose down

# Restart the scheduler
docker-compose restart

# View real-time logs
docker-compose logs -f

# Rebuild after code changes
docker-compose up -d --build

# Check status
docker-compose ps
```

## Backup and Restore

The application includes comprehensive backup and restore scripts that work with your external database.

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

## Troubleshooting

**Container won't start:**
```bash
# Check logs
docker-compose logs

# Verify .env file exists and has correct credentials
cat .env
```

**Database connection fails:**
- Verify database host is accessible from Docker container
- Check firewall rules allow connection from container
- Verify database credentials are correct
- Ensure database tables exist (run `init.sql`)
- Check if database requires SSL (may need to modify connection config)

**Jobs not running:**
```bash
# Check scheduler logs
docker-compose logs scheduler

# Restart scheduler
docker-compose restart
```

**Backup scripts fail:**
- Ensure Docker container is running: `docker ps`
- Verify `.env` file has correct credentials
- Check backup directory permissions

## Database Connection Security

For production deployments:

1. **Use SSL connections** - Modify `index.js` to add SSL configuration:
   ```javascript
   const pool = new Pool({
     host: process.env.DB_HOST,
     port: process.env.DB_PORT || 5432,
     database: process.env.DB_NAME,
     user: process.env.DB_USER,
     password: process.env.DB_PASSWORD,
     ssl: {
       rejectUnauthorized: true,
       ca: fs.readFileSync('/path/to/ca-cert.pem').toString(),
     }
   });
   ```

2. **Use read-only credentials where possible**
3. **Restrict database access by IP**
4. **Use strong passwords**
5. **Enable database connection pooling limits**

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
      ┌──────▼──────────────────┐
      │   Your PostgreSQL DB    │
      │   (External/Managed)    │
      │                         │
      │   - RDS                 │
      │   - Supabase            │
      │   - Self-hosted         │
      │   - etc.                │
      └─────────────────────────┘
```

## Development

To modify schedules, edit the cron expressions in `index.js`:
- `'0,30 * * * *'` - Regional Update (every 30 minutes)
- `'2 0 * * *'` - Daily Totals (00:02 daily)

Then rebuild:
```bash
docker-compose up -d --build
```

## Network Considerations

If your database is on the same Docker network:
- Use the service/container name as `DB_HOST`
- No need to expose ports

If your database is external:
- Use the full hostname or IP as `DB_HOST`
- Ensure firewall allows connections
- Consider using Docker's `host` network mode for direct access

## Production Deployment

For production:

1. **Secure credentials** - Use Docker secrets or vault
2. **Enable monitoring** - Add health check endpoints
3. **Configure logging** - Use log aggregation (ELK, Loki)
4. **Set resource limits** in docker-compose.yml:
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '0.5'
         memory: 512M
   ```
5. **Use a process manager** - Consider Kubernetes for orchestration

## License

MIT