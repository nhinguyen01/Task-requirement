WITH product_sales AS (
  SELECT
    p.category,
    p.product_name,
    SUM(s.quantity) AS total_quantity
  FROM retails.sales AS s
  JOIN retails.products AS p
    ON p.product_key = s.product_key
  GROUP BY p.category, p.product_name
),
ranked AS (
  SELECT
    category,
    product_name,
    total_quantity,
    ROW_NUMBER() OVER (
      PARTITION BY category
      ORDER BY total_quantity DESC, product_name
    ) AS rank_in_category
  FROM product_sales
)
SELECT category, product_name, total_quantity, rank_in_category
FROM ranked
WHERE rank_in_category <= 5
ORDER BY category, rank_in_category;