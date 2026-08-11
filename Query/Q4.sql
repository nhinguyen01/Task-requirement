SELECT SUM(s.quantity * p.unit_price_usd) AS revenue_usd
FROM retails.sales AS s
JOIN retails.products AS p
  ON p.product_key = s.product_key
WHERE s.order_date >= '2020-12-01'
  AND s.order_date < '2021-01-01';