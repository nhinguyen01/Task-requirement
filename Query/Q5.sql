SELECT
  st.country,
  COUNT(*) AS store_count
FROM retails.stores AS st
GROUP BY st.country
ORDER BY store_count DESC, st.country;