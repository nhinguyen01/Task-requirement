SELECT 
  c.city,
  c.state,
  c.country,
  COUNT(*) AS customer_count
FROM retails.customers AS c
GROUP BY c.city, c.state, c.country
ORDER BY customer_count DESC, c.city
lIMIT 10;