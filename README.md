# Olist E-Commerce Analysis

**Team:** Michael Amaya, Vanessa Quiroz, Jan Zika
**Course:** Azure + T-SQL Database Analysis
**Topic:** Sales performance, customer behavior, and trade route visualization for a large Brazilian e-commerce marketplace

**Database export (.bacpac, 49 MB):** [Download from GitHub Releases](https://github.com/jan-zika/olist-db/releases/tag/v1.0)

---

## About the Dataset

This project uses the [Olist E-Commerce Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), covering 2016–2018 with orders, customers, sellers, products, payments, and reviews across 11 tables and ~1.56 million rows.

| Table | Rows | Description |
|---|---|---|
| orders | 99,441 | Order headers with status and timestamps |
| order_items | 112,650 | Line items per order |
| order_payments | 103,886 | Payment method and installments |
| order_reviews | 99,224 | Customer review scores and comments |
| customers | 99,441 | Customer location data |
| sellers | 3,095 | Seller location data |
| products | 32,951 | Product dimensions and category |
| product_category_name_translation | 71 | Portuguese → English category names |
| geolocation | 1,000,163 | ZIP code lat/lng lookup |
| leads_qualified | 8,000 | Marketing qualified leads |
| leads_closed | 842 | Converted leads |

---

## Repository Structure

```
queries/
  01_queries_jan.sql         -- Sales & Revenue (Jan Zika)
  02_queries_michael.sql     -- Customer & Delivery (Michael Amaya)
  03_queries_vanessa.sql     -- Seller & Product Performance (Vanessa Quiroz)
  04_queries_bonus.sql       -- Geolocation analysis + vw_geo view (Jan Zika)
  verify_schema.sql          -- Schema verification (SQL Server)
  verify_schema_sqlite.sql   -- Schema verification (SQLite)

app/
  frontend/
    src/
      App.jsx                -- Root layout + state management
      api.js                 -- Fetch wrappers (live backend or static JSON)
      theme.css              -- CSS variables (dark theme)
      components/
        BrazilMap.jsx        -- Leaflet map: circles, route lines, tooltips
    public/
      cities.json            -- Pre-exported city data (514 KB, 1 674 cities)
      routes.json            -- Pre-exported route data (12.7 MB, 35 759 routes)
    index.html
    package.json
    vite.config.js           -- Dev proxy: /api → localhost:8000
    .env.local.example       -- Documents VITE_API_URL for live backend mode

  backend/
    main.py                  -- FastAPI + pyodbc, /api/cities and /api/routes
    requirements.txt

  start.ps1                  -- PowerShell launcher (starts both services)

netlify.toml                 -- Netlify build config (base: app/frontend)
```

---

## Analysis Goals

### Jan Zika — Sales & Revenue
- Revenue trend over time
- Most popular payment methods and average installment count
- States with highest average order value
- Product categories driving the most revenue

### Michael Amaya — Customer & Delivery Behavior
- On-time vs late delivery rate
- Customer review score distribution
- Repeat customer rate
- Order status breakdown

### Vanessa Quiroz — Seller & Product Performance
- Top-performing sellers by revenue
- Most popular product categories by volume
- Marketing lead conversion funnel
- Freight cost vs product weight correlation

### Bonus — Interactive Trade Route Map (Jan Zika)
- Interactive Leaflet map of Brazil with seller and buyer cities
- Seller → customer city routes with order counts, distances, and freight values
- `vw_geo`: reusable view that deduplicates geolocation and pre-computes seller-to-customer distance per order

---

## Interactive Map App

The `app/` folder contains a full-stack web app for exploring trade routes between cities.

### Features
- **Three view modes**: Seller (outgoing orders), Buyer (incoming orders), Both (combined GMV)
- **Four metric layers**: Order count, Order value (revenue/spend), Avg shipping distance, Avg freight cost
- **City circles** sized and colored by the active metric (log scale, blue → red gradient)
- **Route lines** between seller and buyer cities, thickness and color by active metric
- **City selection**: click cities on the map or search by name; multi-select supported
- **Show top routes** mode: displays the top N routes globally, independent of city selection
- **Left panel**: scrollable city tiles with per-city stats and individual deselect buttons
- **Resizable** panel/map split

### Live Demo

Deployed on Netlify using static JSON (no backend required):
**[https://olist-db.netlify.app](https://olist-db.netlify.app)**

---

## Running Locally

### Option A — Static JSON (no database needed)

The frontend reads pre-exported `cities.json` and `routes.json` from `app/frontend/public/`:

```bash
cd app/frontend
npm install
npm run dev
```

Open `http://localhost:5173`.

### Option B — Live backend (requires SQL Server connection)

1. Copy `.env.example` to `.env` in the project root and fill in your credentials:
   ```
   DB_SERVER=...
   DB_NAME=...
   DB_USER=...
   DB_PASSWORD=...
   ```
2. Copy `app/frontend/.env.local.example` to `app/frontend/.env.local` and uncomment `VITE_API_URL=http://localhost:8000`
3. Launch both services:
   ```powershell
   powershell -File app/start.ps1
   ```

Requires Python 3.11+, Node 18+, and [ODBC Driver 18 for SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server).

---

## Database Setup

The full database is available as a `.bacpac` export (49 MB) in the [GitHub Releases](../../releases). Import it into SQL Server or Azure SQL using SSMS: **Tasks → Import Data-tier Application**.

For local development the app also works without any database — see Option A above.

---

## Deploying to Netlify

The repo includes a `netlify.toml` at the root. Connect the repo in Netlify and it will automatically build from `app/frontend/` and publish `dist/`.

No environment variables are needed for static JSON mode. To point at a live API, set `VITE_API_URL` in Netlify's environment settings.
