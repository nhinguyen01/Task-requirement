SELECT
  p.subcategory,
  COUNT(*) AS product_count,
  CAST(
    AVG((p.unit_price_usd - p.unit_cost_usd) / NULLIF(p.unit_price_usd, 0)) * 100
    AS DECIMAL(6, 2)
  ) AS avg_margin_pct
FROM retails.products AS p
GROUP BY p.subcategory
HAVING COUNT(*) >= 10
ORDER BY avg_margin_pct DESC;