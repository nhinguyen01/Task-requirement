WITH cohort AS (
  SELECT
    s.customer_key,
    YEAR(MIN(s.order_date)) AS cohort_year
  FROM retails.sales AS s
  GROUP BY s.customer_key
),
cohort_size AS (
  SELECT cohort_year, COUNT(*) AS cohort_customers
  FROM cohort
  GROUP BY cohort_year
),
activity AS (
  SELECT DISTINCT
    c.cohort_year,
    s.customer_key,
    YEAR(s.order_date) - c.cohort_year AS year_offset
  FROM retails.sales AS s
  JOIN cohort AS c
    ON c.customer_key = s.customer_key
)
SELECT
  cs.cohort_year,
  cs.cohort_customers,
  a.year_offset,
  COUNT(DISTINCT a.customer_key) AS active_customers,
  CAST(100.0 * COUNT(DISTINCT a.customer_key) / cs.cohort_customers AS DECIMAL(5, 2)) AS retention_pct
FROM activity AS a
JOIN cohort_size AS cs
  ON cs.cohort_year = a.cohort_year
WHERE a.year_offset BETWEEN 0 AND 3
GROUP BY cs.cohort_year, cs.cohort_customers, a.year_offset
ORDER BY cs.cohort_year, a.year_offset;