SELECT COUNT(DISTINCT s.order_number) AS total_orders_2020
FROM retails.sales AS s
WHERE s.order_date >= '2020-01-01'
  AND s.order_date < '2021-01-01';