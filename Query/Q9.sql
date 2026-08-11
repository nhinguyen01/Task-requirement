WITH customer_spend AS (
  SELECT
    c.country,
    c.customer_key,
    c.name,
    SUM(s.quantity * p.unit_price_usd) AS total_spend_usd
  FROM retails.sales AS s
  JOIN retails.customers AS c
    ON c.customer_key = s.customer_key
  JOIN retails.products AS p
    ON p.product_key = s.product_key
  WHERE s.order_date >= '2020-01-01'
    AND s.order_date < '2021-01-01'
  GROUP BY c.country, c.customer_key, c.name
),
ranked AS (
  SELECT
    country,
    name,
    total_spend_usd,
    ROW_NUMBER() OVER (
      PARTITION BY country
      ORDER BY total_spend_usd DESC, name
    ) AS rn
  FROM customer_spend
)
SELECT
  country,
  name,
  CAST(total_spend_usd AS DECIMAL(14, 2)) AS total_spend_usd
FROM ranked
WHERE rn = 1
ORDER BY total_spend_usd DESC;