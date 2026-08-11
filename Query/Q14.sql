WITH store_pairs AS (
  SELECT
    incumbent.store_key AS incumbent_store,
    newcomer.store_key AS new_store,
    incumbent.country,
    newcomer.open_date AS new_store_open_date
  FROM retails.stores AS incumbent
  JOIN retails.stores AS newcomer
    ON newcomer.country = incumbent.country
   AND newcomer.open_date > incumbent.open_date
),
windowed AS (
  SELECT
    sp.incumbent_store,
    sp.new_store,
    sp.country,
    sp.new_store_open_date,
    SUM(CASE
      WHEN s.order_date >= DATEADD(MONTH, -6, sp.new_store_open_date)
       AND s.order_date < sp.new_store_open_date
      THEN s.quantity * p.unit_price_usd
    END) AS revenue_before,
    SUM(CASE
      WHEN s.order_date >= sp.new_store_open_date
       AND s.order_date < DATEADD(MONTH, 6, sp.new_store_open_date)
      THEN s.quantity * p.unit_price_usd
    END) AS revenue_after
  FROM store_pairs AS sp
  JOIN retails.sales AS s
    ON s.store_key = sp.incumbent_store
  JOIN retails.products AS p
    ON p.product_key = s.product_key
  GROUP BY sp.incumbent_store, sp.new_store, sp.country, sp.new_store_open_date
)
SELECT
  incumbent_store,
  new_store,
  country,
  new_store_open_date,
  CAST(revenue_before AS DECIMAL(14, 2)) AS revenue_before,
  CAST(ISNULL(revenue_after, 0) AS DECIMAL(14, 2)) AS revenue_after,
  CAST(100.0 * (ISNULL(revenue_after, 0) - revenue_before) / revenue_before AS DECIMAL(7, 2)) AS change_pct
FROM windowed
WHERE revenue_before > 0
  AND ISNULL(revenue_after, 0) < revenue_before * 0.85
ORDER BY change_pct, incumbent_store, new_store;