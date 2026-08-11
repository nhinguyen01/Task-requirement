SELECT
  p.product_key,
  p.product_name,
  p.brand,
  p.category
FROM retails.products AS p
WHERE NOT EXISTS (
  SELECT 1
  FROM retails.sales AS s
  WHERE s.product_key = p.product_key
)
ORDER BY p.category, p.product_name;