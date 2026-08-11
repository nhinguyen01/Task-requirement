SELECT
  p.category,
  COUNT(*) AS sku_count
FROM retails.products AS p
GROUP BY p.category
ORDER BY p.category;