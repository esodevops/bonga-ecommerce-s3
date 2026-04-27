# Local PostgreSQL: Connect, Load Data, and Run Queries

This guide shows how to run everything locally using Docker and PostgreSQL.

## 1. Prepare environment file

Development profile:

```bash
make setup-dev
```

Production-like profile:

```bash
make setup-prod
```

Then edit one of these files and set a strong password:

- `.env.dev`
- `.env.production`

Note: Make targets use `.env.dev` by default.

## 2. Load data into local PostgreSQL

Run with development profile:

```bash
make pipeline-dev
```

Run with production-like profile:

```bash
make pipeline-prod
```

What this does:

1. Starts PostgreSQL container
2. Creates schema from `sql/01_schema.sql`
3. Loads CSV data from `data/raw/*.csv` using `sql/02_load_data.sql`
4. Validates data with `sql/03_validate.sql`

## 3. Connect to PostgreSQL locally

### Option A: Connect from host using `psql`

For development profile (default port 55432):

```bash
PGPASSWORD='<your_dev_password>' psql -h localhost -p 55432 -U postgres -d bongadb_dev
```

For production-like profile (default port 55433):

```bash
PGPASSWORD='<your_prod_password>' psql -h localhost -p 55433 -U bonga_admin -d bongadb
```

### Option B: Connect inside the container

Development profile:

```bash
docker-compose --env-file .env.dev exec -T db psql -U bonga_admin -d bongadb_dev
```

Production-like profile:

```bash
docker-compose --env-file .env.production exec -T db psql -U bonga_admin -d bongadb
```

## 4. Execute query files locally

Run all solutions directly using the runnable SQL file:

```bash
docker-compose --env-file .env.dev exec -T db psql -U bonga_admin -d bongadb_dev -f /workspace/docs/solutions.sql
```

```bash
docker-compose --env-file .env.production exec -T db psql -U bonga_admin -d bongadb -f /workspace/docs/solutions.sql
```

## 5. Run single queries interactively

After connecting with `psql`, run examples:

```sql
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM orderitems;
```

## 6. Useful commands

Start only database:

```bash
make up ENV=.env.dev
```

Validate loaded data:

```bash
make validate ENV=.env.dev
```

View logs:

```bash
make logs ENV=.env.dev
```

Stop everything:

```bash
make down ENV=.env.dev
```
