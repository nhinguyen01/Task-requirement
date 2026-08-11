WITH order_products AS (
  SELECT DISTINCT s.order_number, s.product_key
  FROM retails.sales AS s
),
total_orders AS (
  SELECT COUNT(DISTINCT order_number) AS order_count
  FROM retails.sales
),
pairs AS (
  SELECT
    a.product_key AS product_a_key,
    b.product_key AS product_b_key,
    COUNT(*) AS times_together
  FROM order_products AS a
  JOIN order_products AS b
    ON b.order_number = a.order_number
   AND b.product_key > a.product_key
  GROUP BY a.product_key, b.product_key
)
SELECT TOP (20)
  pa.product_name AS product_a,
  pb.product_name AS product_b,
  pr.times_together,
  CAST(100.0 * pr.times_together / t.order_count AS DECIMAL(8, 4)) AS pct_of_orders
FROM pairs AS pr
JOIN retails.products AS pa
  ON pa.product_key = pr.product_a_key
JOIN retails.products AS pb
  ON pb.product_key = pr.product_b_key
CROSS JOIN total_orders AS t
ORDER BY pr.times_together DESC, product_a, product_b;