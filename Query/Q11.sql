WITH bounds AS (
  SELECT DATEFROMPARTS(YEAR(MAX(order_date)), MONTH(MAX(order_date)), 1) AS last_month
  FROM retails.sales
),
monthly AS (
  SELECT
    DATEFROMPARTS(YEAR(s.order_date), MONTH(s.order_date), 1) AS month_start,
    SUM(s.quantity * p.unit_price_usd) AS revenue_usd
  FROM retails.sales AS s
  JOIN retails.products AS p
    ON p.product_key = s.product_key
  CROSS JOIN bounds AS b
  WHERE s.order_date >= DATEADD(MONTH, -23, b.last_month)
  GROUP BY DATEFROMPARTS(YEAR(s.order_date), MONTH(s.order_date), 1)
)
SELECT
  FORMAT(month_start, 'yyyy-MM') AS year_month,
  CAST(revenue_usd AS DECIMAL(14, 2)) AS revenue_usd,
  CAST(
    SUM(revenue_usd) OVER (ORDER BY month_start ROWS UNBOUNDED PRECEDING)
    AS DECIMAL(14, 2)
  ) AS cumulative_revenue_usd
FROM monthly
ORDER BY month_start;