"""
FastAPI backend for Olist Brazil Trade Routes map.
Connects to local SQL Server (YAHN_DESKTOP) via Windows Authentication.
Switch CONN_STR to the Azure variant when migrating to cloud.
"""
from __future__ import annotations

import unicodedata
from collections import defaultdict

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import pyodbc

# Local SQL Server — Windows Authentication, no password needed
CONN_STR = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=YAHN_DESKTOP;"
    "DATABASE=olist;"
    "Trusted_Connection=yes;"
    "Encrypt=no;"
    "Connection Timeout=30;"
)

# Azure SQL variant (uncomment when migrating to Supabase / Azure SQL):
# from pathlib import Path
# from dotenv import load_dotenv; import os
# load_dotenv(Path(__file__).parent.parent.parent / ".env")
# CONN_STR = (
#     f"DRIVER={{ODBC Driver 18 for SQL Server}};"
#     f"SERVER={os.getenv('DB_SERVER')};"
#     f"DATABASE={os.getenv('DB_NAME')};"
#     f"UID={os.getenv('DB_USER')};"
#     f"PWD={os.getenv('DB_PASSWORD')};"
#     f"Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
# )

app = FastAPI(title="Olist Trade Routes API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_conn():
    return pyodbc.connect(CONN_STR)


def rows_to_dicts(cursor):
    cols = [c[0] for c in cursor.description]
    return [dict(zip(cols, row)) for row in cursor.fetchall()]


def to_float(v):
    return float(v) if v is not None and hasattr(v, '__float__') else v


def normalize_city(name: str) -> str:
    """Lowercase, strip accents, collapse whitespace."""
    if not name:
        return ''
    nfkd = unicodedata.normalize('NFKD', name.strip().lower())
    return ''.join(c for c in nfkd if not unicodedata.combining(c))


# ---------------------------------------------------------------------------
# Raw SQL — pull all lat/lng observations for every city from both sides
# ---------------------------------------------------------------------------
ALL_COORDS_SQL = """
WITH geo AS (
    SELECT geolocation_zip_code_prefix AS zip,
           AVG(geolocation_lat) AS lat,
           AVG(geolocation_lng) AS lng
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix
)
-- seller side
SELECT s.seller_city AS city, s.seller_state AS state,
       gs.lat, gs.lng
FROM sellers s
JOIN geo gs ON gs.zip = s.seller_zip_code_prefix
WHERE gs.lat IS NOT NULL AND gs.lng IS NOT NULL

UNION ALL

-- customer side
SELECT c.customer_city AS city, c.customer_state AS state,
       gc.lat, gc.lng
FROM customers c
JOIN geo gc ON gc.zip = c.customer_zip_code_prefix
WHERE gc.lat IS NOT NULL AND gc.lng IS NOT NULL
"""

RAW_SELLERS_SQL = """
WITH geo AS (
    SELECT geolocation_zip_code_prefix AS zip,
           AVG(geolocation_lat) AS lat,
           AVG(geolocation_lng) AS lng
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix
)
SELECT
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT g.order_id)               AS order_count,
    CAST(SUM(oi.price + oi.freight_value) AS DECIMAL(14,2)) AS total_revenue,
    CAST(AVG(oi.freight_value)            AS DECIMAL(10,2)) AS avg_freight,
    CAST(AVG(g.distance_km)               AS DECIMAL(10,2)) AS avg_distance_km
FROM vw_geo g
JOIN order_items oi ON oi.order_id  = g.order_id
JOIN sellers s      ON s.seller_id  = oi.seller_id
JOIN geo gs         ON gs.zip       = s.seller_zip_code_prefix
WHERE g.order_status = 'delivered'
  AND gs.lat IS NOT NULL
GROUP BY s.seller_city, s.seller_state
HAVING COUNT(DISTINCT g.order_id) >= 5
"""

RAW_BUYERS_SQL = """
WITH geo AS (
    SELECT geolocation_zip_code_prefix AS zip,
           AVG(geolocation_lat) AS lat,
           AVG(geolocation_lng) AS lng
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix
)
SELECT
    c.customer_city,
    c.customer_state,
    COUNT(DISTINCT g.order_id)               AS order_count,
    CAST(SUM(oi.price + oi.freight_value) AS DECIMAL(14,2)) AS total_spend,
    CAST(AVG(oi.freight_value)            AS DECIMAL(10,2)) AS avg_freight,
    CAST(AVG(g.distance_km)               AS DECIMAL(10,2)) AS avg_distance_km
FROM vw_geo g
JOIN order_items oi ON oi.order_id   = g.order_id
JOIN orders o       ON o.order_id    = g.order_id
JOIN customers c    ON c.customer_id = o.customer_id
JOIN geo gc         ON gc.zip        = c.customer_zip_code_prefix
WHERE g.order_status = 'delivered'
  AND gc.lat IS NOT NULL
GROUP BY c.customer_city, c.customer_state
HAVING COUNT(DISTINCT g.order_id) >= 5
"""

RAW_ROUTES_SQL = """
WITH geo AS (
    SELECT geolocation_zip_code_prefix AS zip,
           AVG(geolocation_lat) AS lat,
           AVG(geolocation_lng) AS lng
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix
)
SELECT
    s.seller_city,
    s.seller_state,
    c.customer_city,
    c.customer_state,
    COUNT(DISTINCT g.order_id)               AS order_count,
    CAST(AVG(g.distance_km)               AS DECIMAL(10,2)) AS avg_distance_km,
    CAST(AVG(g.freight_value)             AS DECIMAL(10,2)) AS avg_freight,
    CAST(SUM(oi.price + oi.freight_value) AS DECIMAL(14,2)) AS total_revenue
FROM vw_geo g
JOIN order_items oi ON oi.order_id   = g.order_id
JOIN sellers s      ON s.seller_id   = oi.seller_id
JOIN orders o       ON o.order_id    = g.order_id
JOIN customers c    ON c.customer_id = o.customer_id
WHERE g.order_status = 'delivered'
GROUP BY s.seller_city, s.seller_state, c.customer_city, c.customer_state
HAVING COUNT(DISTINCT g.order_id) >= 1
ORDER BY order_count DESC
"""


def build_centroids(conn) -> dict:
    """
    Returns {norm_key: {lat, lng, canonical_city, canonical_state}}
    combining seller + customer coordinates for every city.
    norm_key = normalize_city(city) + '|' + state.lower()
    Cities whose normalized name matches are merged into one centroid.
    """
    cur = conn.cursor()
    cur.execute(ALL_COORDS_SQL)
    rows = cur.fetchall()

    # Accumulate lat/lng sums per normalized key
    acc = defaultdict(lambda: {'lat_sum': 0.0, 'lng_sum': 0.0, 'n': 0,
                               'city': '', 'state': ''})
    for city, state, lat, lng in rows:
        if lat is None or lng is None:
            continue
        nk = normalize_city(city) + '|' + (state or '').lower().strip()
        acc[nk]['lat_sum'] += float(lat)
        acc[nk]['lng_sum'] += float(lng)
        acc[nk]['n']       += 1
        # Keep the most common-looking canonical form (first seen)
        if not acc[nk]['city']:
            acc[nk]['city']  = city
            acc[nk]['state'] = state

    return {
        nk: {
            'lat':   v['lat_sum'] / v['n'],
            'lng':   v['lng_sum'] / v['n'],
            'city':  v['city'],
            'state': v['state'],
        }
        for nk, v in acc.items()
        if v['n'] > 0
    }


# ---------------------------------------------------------------------------
# GET /api/cities
# Returns one row per canonical city with both seller-side and buyer-side stats.
# seller_* = activity originating from this city (supply)
# buyer_*  = activity destined to this city (demand)
# ---------------------------------------------------------------------------
@app.get("/api/cities")
def get_cities():
    try:
        with get_conn() as conn:
            centroids = build_centroids(conn)
            cur = conn.cursor()
            cur.execute(RAW_SELLERS_SQL)
            raw_sellers = rows_to_dicts(cur)
            cur.execute(RAW_BUYERS_SQL)
            raw_buyers = rows_to_dicts(cur)

        def aggregate(rows, city_col, state_col, revenue_col):
            agg = defaultdict(lambda: {
                'order_count': 0, 'revenue': 0.0,
                'avg_freight_sum': 0.0, 'avg_distance_sum': 0.0, 'n': 0,
                'city': '', 'state': '',
            })
            for r in rows:
                nk = normalize_city(r[city_col]) + '|' + (r[state_col] or '').lower().strip()
                a = agg[nk]
                oc = r['order_count']
                a['order_count']      += oc
                a['revenue']          += to_float(r[revenue_col]) or 0
                a['avg_freight_sum']  += (to_float(r['avg_freight']) or 0) * oc
                a['avg_distance_sum'] += (to_float(r['avg_distance_km']) or 0) * oc
                a['n']                += oc
                if not a['city']:
                    a['city']  = r[city_col]
                    a['state'] = r[state_col]
            return agg

        sellers = aggregate(raw_sellers, 'seller_city', 'seller_state', 'total_revenue')
        buyers  = aggregate(raw_buyers,  'customer_city', 'customer_state', 'total_spend')

        all_keys = set(sellers) | set(buyers)
        result = []
        for nk in all_keys:
            c = centroids.get(nk)
            if not c:
                continue
            s = sellers.get(nk)
            b = buyers.get(nk)
            # canonical city name: prefer seller name, fall back to buyer name
            city_name  = (s or b)['city']
            state_name = (s or b)['state']
            result.append({
                'city_key':   nk,
                'city':       city_name,
                'state':      state_name,
                'lat':        round(c['lat'], 6),
                'lng':        round(c['lng'], 6),
                # seller-side (supply)
                'seller_order_count':   s['order_count'] if s else 0,
                'seller_revenue':       round(s['revenue'], 2) if s else 0,
                'seller_avg_freight':   round(s['avg_freight_sum']  / s['n'], 2) if s and s['n'] else 0,
                'seller_avg_distance':  round(s['avg_distance_sum'] / s['n'], 2) if s and s['n'] else 0,
                # buyer-side (demand)
                'buyer_order_count':    b['order_count'] if b else 0,
                'buyer_spend':          round(b['revenue'], 2) if b else 0,
                'buyer_avg_freight':    round(b['avg_freight_sum']  / b['n'], 2) if b and b['n'] else 0,
                'buyer_avg_distance':   round(b['avg_distance_sum'] / b['n'], 2) if b and b['n'] else 0,
            })

        result.sort(key=lambda x: x['seller_order_count'], reverse=True)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# GET /api/routes
# ---------------------------------------------------------------------------
@app.get("/api/routes")
def get_routes():
    try:
        with get_conn() as conn:
            centroids = build_centroids(conn)
            cur = conn.cursor()
            cur.execute(RAW_ROUTES_SQL)
            raw = rows_to_dicts(cur)

        # Aggregate routes that normalize to the same seller→customer pair
        agg = defaultdict(lambda: {
            'order_count': 0, 'total_revenue': 0.0,
            'avg_distance_sum': 0.0, 'avg_freight_sum': 0.0, 'n': 0,
            'seller_city': '', 'seller_state': '',
            'customer_city': '', 'customer_state': '',
        })
        for r in raw:
            snk = normalize_city(r['seller_city'])   + '|' + (r['seller_state']   or '').lower().strip()
            cnk = normalize_city(r['customer_city']) + '|' + (r['customer_state'] or '').lower().strip()
            pair = snk + '→' + cnk
            a = agg[pair]
            oc = r['order_count']
            a['order_count']      += oc
            a['total_revenue']    += to_float(r['total_revenue']) or 0
            a['avg_distance_sum'] += (to_float(r['avg_distance_km']) or 0) * oc
            a['avg_freight_sum']  += (to_float(r['avg_freight']) or 0) * oc
            a['n']                += oc
            a['seller_key']   = snk
            a['customer_key'] = cnk
            if not a['seller_city']:
                a['seller_city']    = r['seller_city']
                a['seller_state']   = r['seller_state']
                a['customer_city']  = r['customer_city']
                a['customer_state'] = r['customer_state']

        result = []
        for pair, a in agg.items():
            sc = centroids.get(a['seller_key'])
            cc = centroids.get(a['customer_key'])
            if not sc or not cc:
                continue
            result.append({
                'seller_city':    a['seller_city'],
                'seller_state':   a['seller_state'],
                'seller_key':     a['seller_key'],
                'customer_city':  a['customer_city'],
                'customer_state': a['customer_state'],
                'customer_key':   a['customer_key'],
                'seller_lat':     round(sc['lat'], 6),
                'seller_lng':     round(sc['lng'], 6),
                'customer_lat':   round(cc['lat'], 6),
                'customer_lng':   round(cc['lng'], 6),
                'order_count':    a['order_count'],
                'avg_distance_km': round(a['avg_distance_sum'] / a['n'], 2) if a['n'] else 0,
                'avg_freight':    round(a['avg_freight_sum']   / a['n'], 2) if a['n'] else 0,
                'total_revenue':  round(a['total_revenue'], 2),
            })

        result.sort(key=lambda x: x['order_count'], reverse=True)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ---------------------------------------------------------------------------
# GET /api/debug?city=porto+velho
# ---------------------------------------------------------------------------
@app.get("/api/debug")
def debug_city(city: str):
    try:
        with get_conn() as conn:
            centroids = build_centroids(conn)
        norm = normalize_city(city)
        matched = {k: v for k, v in centroids.items() if norm in k}
        return {"query": city, "normalized": norm, "centroids": matched}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
