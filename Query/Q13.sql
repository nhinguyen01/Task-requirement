WITH store_revenue AS (
  SELECT
    st.store_key,
    st.country,
    st.square_meters,
    SUM(s.quantity * p.unit_price_usd) AS revenue_usd
  FROM retails.sales AS s
  JOIN retails.products AS p
    ON p.product_key = s.product_key
  JOIN retails.stores AS st
    ON st.store_key = s.store_key
  WHERE s.order_date >= '2020-01-01'
    AND s.order_date < '2021-01-01'
    AND st.square_meters > 0
  GROUP BY st.store_key, st.country, st.square_meters
)
SELECT
  store_key,
  country,
  CAST(revenue_usd / square_meters AS DECIMAL(12, 2)) AS revenue_per_sqm,
  NTILE(4) OVER (
    PARTITION BY country
    ORDER BY revenue_usd / square_meters DESC
  ) AS quartile_in_country
FROM store_revenue
ORDER BY country, quartile_in_country, revenue_per_sqm DESC;