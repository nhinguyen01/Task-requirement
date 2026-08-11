WITH delivered AS (
  SELECT DISTINCT
    s.order_number,
    s.customer_key,
    s.order_date,
    s.delivery_date
  FROM retails.sales AS s
  WHERE s.delivery_date IS NOT NULL
)
SELECT
  c.country,
  COUNT(*) AS delivered_orders,
  CAST(
    AVG(CAST(DATEDIFF(DAY, d.order_date, d.delivery_date) AS DECIMAL(10, 2)))
    AS DECIMAL(10, 2)
  ) AS avg_delivery_days
FROM delivered AS d
JOIN retails.customers AS c
  ON c.customer_key = d.customer_key
GROUP BY c.country
ORDER BY avg_delivery_days DESC;