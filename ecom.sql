USE xomdata_dataset;
GO

SELECT 
    t.name AS table_name,
    s.name AS schema_name
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON t.schema_id = s.schema_id
WHERE s.name = 'e_commerce'; -- thay tên schema 

SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ecom_sales' AND TABLE_SCHEMA = 'e_commerce'
ORDER BY ORDINAL_POSITION; -- Kiểm tra các cột trong bảng 'ecom_sales' thuộc schema 'e_commerce'

EXEC sp_help 'e_commerce.customer'; --kiểm tra nhanh table có những column gì

SELECT TOP 5 *
FROM e_commerce.ecom_sales; 

--Thống kê tổng số data và số dòng NULL của từng cột trong bảng thuộc schema 

DECLARE @SchemaName NVARCHAR(128) = 'e_commerce'; -- <-- TÊN SCHEMA 
DECLARE @TableName NVARCHAR(128) = 'customer';    -- <-- TÊN BẢNG 

DECLARE @FullTableName NVARCHAR(256) = QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName);
DECLARE @DynamicSQL NVARCHAR(MAX) = '';

    -- Tạo câu lệnh SQL động để quét từng cột từ INFORMATION_SCHEMA
SELECT @DynamicSQL = @DynamicSQL + 
    N'SELECT ''' + COLUMN_NAME + ''' AS [Tên Cột], ' +
    -- Đếm tổng số data THỰC TẾ của riêng cột này (loại bỏ các dòng bị NULL)
    N'COUNT(' + QUOTENAME(COLUMN_NAME) + N') AS [Tổng Số Data (Không NULL)], ' +
    -- Đếm số data duy nhất (Không tính NULL)
    N'COUNT(DISTINCT ' + QUOTENAME(COLUMN_NAME) + N') AS [Số Data Distinct], ' +
    -- Đếm số dòng bị NULL của riêng cột này
    N'SUM(CASE WHEN ' + QUOTENAME(COLUMN_NAME) + N' IS NULL THEN 1 ELSE 0 END) AS [Số Dòng NULL] FROM ' + @FullTableName + N' UNION ALL '
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = @SchemaName AND TABLE_NAME = @TableName;

    -- Cắt bỏ chữ 'UNION ALL' thừa ở cuối câu lệnh
IF LEN(@DynamicSQL) > 0
BEGIN
    SET @DynamicSQL = LEFT(@DynamicSQL, LEN(@DynamicSQL) - 10);
    -- Xuất kết quả hiển thị
    EXEC sp_executesql @DynamicSQL;
END
ELSE
BEGIN
    PRINT 'Không tìm thấy bảng hoặc schema này! Vui lòng kiểm tra lại chính xác chữ hoa/chữ thường.';
END

--Q1: tổng doanh thu từ trước đến nay là bao nhiêu, và tổng profit là bao nhiêu?

SELECT 
   ROUND(SUM(sales), 2) AS total_revenue,
   ROUND(SUM(profit), 2) AS total_profit
FROM e_commerce.ecom_sales;

--Q2: tổng doanh thu + tổng profit theo từng segment khách hàng(Consumer / Corporate / Home Office) để so sánh độ đóng góp của 3 nhóm. Sắp theo doanh thu giảm dần.

SELECT 
    segment,
    ROUND(SUM(sales), 2) AS total_revenue,
    ROUND(SUM(profit), 2) AS total_profit
FROM e_commerce.ecom_sales
GROUP BY segment
ORDER BY total_revenue DESC;

--Q3: Chị đang planning restock, cần top 10 sản phẩm bán chạy nhất theo số lượng (không tính doanh thu). Gửi chị: mã sản phẩm, tên sản phẩm, tổng số lượng đã bán

SELECT TOP 10
    p.product_code,
    p.product,
    SUM(s.quantity) AS total_quantity_sold
FROM e_commerce.ecom_sales AS s
INNER JOIN e_commerce.product AS p ON s.product_code = p.product_code
GROUP BY p.product_code, p.product
ORDER BY total_quantity_sold DESC, p.product_code; 

--Q4*: Team CRM cần bảng phân bố khách hàng theo giới tính và nghề nghiệp để chọn targeting cho campaign email. Output pivot table: nghề nghiệp (hàng) × giới tính (cột) × số khách
--Nên dùng cách này thay vì pivot để dễ đọc hơn
SELECT
    occupation,
    SUM(CASE WHEN gender = 'M' THEN 1 ELSE 0 END) AS Male,
    SUM(CASE WHEN gender = 'F' THEN 1 ELSE 0 END) AS Female,
    SUM(CASE WHEN gender IS NULL THEN 1 ELSE 0 END) AS Unknown,
    COUNT(*) AS Total_Customers
FROM e_commerce.customer
GROUP BY occupation
ORDER BY occupation;  

--Q5: mức discount trung bình đang áp dụng theo từng category sản phẩm. Trả discount dạng %. Category nào đang discount nhiều nhất?
-- Lưu ý: discount đang lưu dạng số thập phân (0.1 = 10%), nên cần nhân 100 để ra % và làm tròn 2 chữ số thập phân
SELECT 
    p.category,
    CAST(AVG(s.discount) * 100 AS DECIMAL(5, 2)) AS avg_discount_percentage,
    COUNT(*) AS line_count
FROM e_commerce.ecom_sales AS s
INNER JOIN e_commerce.product AS p ON s.product_code = p.product_code
GROUP BY p.category
ORDER BY avg_discount_percentage DESC;

--Q6: profit margin (%) theo từng market (US, EMEA, APAC, LATAM) để xem market nào đang lãi nhiều, market nào lỗ. Chỉ xét market có ít nhất 100 đơn để số ổn định. Margin = profit / doanh thu × 100.

SELECT
  r.market,
  COUNT(DISTINCT s.order_id) AS order_count,
  CAST(SUM(s.sales) AS DECIMAL(16, 2)) AS total_sales,
  CAST(SUM(s.profit) AS DECIMAL(16, 2)) AS total_profit,
  CAST(100.0 * SUM(s.profit) / NULLIF(SUM(s.sales), 0) AS DECIMAL(6, 2)) AS profit_margin_pct
FROM e_commerce.ecom_sales AS s
JOIN e_commerce.region AS r ON r.region_code = s.region_code
GROUP BY r.market
HAVING COUNT(DISTINCT s.order_id) >= 100
ORDER BY profit_margin_pct DESC;

--Q7*: nghi ngờ có đơn discount quá mạnh dẫn tới lỗ. Em check giúp anh: với mỗi segment, có bao nhiêu đơn bị lỗ (profit âm), tổng số tiền lỗ bao nhiêu, và chiếm bao nhiêu % tổng số đơn của segment đó? Anh cần đưa cảnh báo cho team pricing.
-- Khuôn "đếm có điều kiện": COUNT(DISTINCT CASE WHEN ... THEN order_id END).
-- CASE không có ELSE trả NULL, mà COUNT bỏ qua NULL — nên nó đếm đúng số
-- đơn thoả điều kiện. Viết ELSE 0 ở đây là hỏng: 0 cũng là một giá trị và
-- cũng được đếm. Ngược lại, ở cột total_loss thì phải có ELSE 0 vì đang SUM, và ta
-- muốn dòng không lỗ đóng góp 0 chứ không phải NULL. 
-- Đếm theo đơn chứ không theo dòng hàng: một đơn có thể có dòng lãi và dòng
-- lỗ. Cách trên coi đơn là "có lỗ" nếu có ít nhất một dòng lỗ — nói rõ định nghĩa
-- này khi giao số, vì anh CFO có thể đang hỏi "đơn lỗ ròng", một câu khác hẳn
SELECT 
    segment,
    CAST(SUM(CASE WHEN profit < 0 THEN profit ELSE 0 END) AS DECIMAL(16, 2)) AS profit_loss,
    COUNT(DISTINCT order_id) AS count_orders,
    COUNT(DISTINCT CASE WHEN profit < 0 THEN order_id END)  AS order_loss,
    CAST(COUNT(DISTINCT CASE WHEN profit < 0 THEN order_id END)  * 100.0 
    / COUNT(DISTINCT order_id) AS DECIMAL(5, 2)
  ) AS loss_order_pct
FROM e_commerce.ecom_sales
GROUP BY segment
ORDER BY loss_order_pct DESC;

--Q8*:  danh sách khách hàng chi tiêu top 50 trong lifetime của họ, nhưng đã 180 ngày không mua hàng. Đây là nhóm VIP sắp churn, team retention cần target ngay. 
-- Gửi chị: tên khách, tổng lifetime spend, ngày mua gần nhất

WITH last_dates AS (
    SELECT max(order_date) AS order_date_snapshot FROM e_commerce.ecom_sales
),

customer_statastics AS (
    SELECT 
        customer_id,
        SUM(sales) AS lifetime_spend,
        MAX(order_date) AS last_order_date
    FROM e_commerce.ecom_sales
    GROUP BY customer_id
),

top_50_sales AS (
    SELECT TOP 50 
        customer_id, lifetime_spend, last_order_date
    FROM customer_statastics
    ORDER BY lifetime_spend DESC, customer_id
)

SELECT    
    s.customer_id,
    c.first_name + ' ' + c.last_name AS full_name,
    s.lifetime_spend,
    s.last_order_date
FROM top_50_sales AS s
JOIN e_commerce.customer AS c ON s.customer_id = c.customer_id
CROSS JOIN last_dates AS b
WHERE s.last_order_date < DATEADD(DAY, 180, b.order_date_snapshot)
ORDER BY s.lifetime_spend DESC;

--Q9: cần tỷ trọng doanh thu Consumer vs Corporate ở mỗi category để hiểu category nào thiên về B2C, category nào thiên về B2B. Output: category, % Consumer, % Corporate (tổng = 100%).
-- Tương tự Q7, dùng sum case when để thiết kế pivot
SELECT 
    p.category,
    CAST(SUM(CASE WHEN segment = 'Consumer' THEN s.sales ELSE 0 END)/NULLIF(SUM(s.sales), 0) * 100 AS DECIMAL(5, 2)) AS pct_consumer_sales,
    CAST(SUM(CASE WHEN segment = 'Corporate' THEN s.sales ELSE 0 END)/NULLIF(SUM(s.sales), 0) * 100 AS DECIMAL(5, 2)) AS pct_corporate_sales,
    CAST(SUM(CASE WHEN segment = 'Self-Employed' THEN s.sales ELSE 0 END)/NULLIF(SUM(s.sales), 0) * 100 AS DECIMAL(5, 2)) AS pct_self_employed_sales,
    CAST(SUM(s.sales) AS DECIMAL(16, 2)) AS total_sales
FROM e_commerce.ecom_sales AS s
JOIN e_commerce.product AS p ON s.product_code = p.product_code
GROUP BY p.category
ORDER BY pct_corporate_sales DESC, p.category;

--Q10:  top 15 quốc gia theo doanh thu, mỗi nước xem có bao nhiêu region active, bao nhiêu customer, tổng doanh thu. Sắp theo doanh thu giảm dần.

SELECT TOP 15 
    country, 
    CAST(SUM(s.sales) AS DECIMAL(16, 2)) AS total_sales, 
    count(distinct s.customer_id) AS count_customers,
    count(distinct s.region_code) AS count_active_regions,
    COUNT(DISTINCT s.order_id) AS orders
FROM e_commerce.region AS r
JOIN e_commerce.ecom_sales AS s ON r.region_code = s.region_code
GROUP BY country
ORDER BY total_sales DESC;


--Q11:  doanh thu theo tháng + so sánh với cùng tháng năm trước (YoY growth %) 24 tháng gần nhất. Board muốn thấy trend tăng trưởng rõ ràng. 
--Output: year_month, doanh thu, doanh thu cùng kỳ năm trước, % tăng trưởng YoY. 

with sales_by_month as (
    SELECT 
        DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS year_month_start, 
        SUM(sales) AS total_sales
    FROM e_commerce.ecom_sales
    GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
),

max_year_month as (
    SELECT MAX(year_month_start) AS last_month FROM sales_by_month
),

prev_month as (
    SELECT 
        year_month_start, total_sales,    
        LAG(total_sales,12) OVER (ORDER BY year_month_start) AS prev_year_sales
    FROM sales_by_month
)

SELECT 
    FORMAT(p.year_month_start,'yyyy-MM') AS year_month,
    CAST(p.total_sales AS DECIMAL(16,2)) AS current_sales,
    CAST(p.prev_year_sales AS DECIMAL(16,2)) AS prev_year_sales,
    CAST((p.total_sales - p.prev_year_sales)*100.0/NULLIF(p.prev_year_sales,0)AS DECIMAL(8,2)) AS yoy_change
FROM prev_month AS p 
CROSS JOIN max_year_month AS y
WHERE p.year_month_start >= DATEADD(MONTH, -23, y.last_month)  
ORDER BY p.year_month_start; 

--Q12: top 3 sản phẩm có lifetime profit cao nhất trong mỗi category. Dùng để làm product spotlight trong báo cáo Q4. Output: category, tên sản phẩm, tổng profit, thứ hạng (1-3) trong category.

With profit_category AS (
    SELECT 
        p.category,
        p.product,
        p.product_code,
        SUM(s.profit) AS total_profit
    FROM e_commerce.ecom_sales AS s
    JOIN e_commerce.product AS p ON s.product_code = p.product_code
    GROUP BY p.category, p.product_code,p.product
    ),
rank_profit AS (
    SELECT
        category,
        product,
        total_profit,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY total_profit DESC, product_code) AS rank
    FROM profit_category
)

SELECT 
    category,
    product,
    total_profit,
    rank
FROM rank_profit
WHERE rank <= 3
ORDER BY category, rank;

--Q13***: bao nhiêu % khách hàng có mua ở nhiều khu vực khác nhau (VD: đơn đầu giao về một thành phố, các đơn sau lại giao đi nơi khác)? 
--Xác định cho mỗi khách: khu vực của lần mua đầu tiên, và liệu sau đó họ có mua ở khu vực khác không. 
--Output 1 con số % + top 20 khách mua nhiều khu vực chi tiêu nhiều nhất

--Nên nói với Head of International rằng: nếu chạy phân tích ở cấp market hoặc country, kết quả sẽ chính xác là 0% — trong dataset này, mỗi customer chỉ thuộc về một country.
--Việc khách hàng mua hàng ở nhiều nơi chỉ xuất hiện khi phân tích ở cấp city.

WITH start_order AS (
    SELECT 
        customer_id,
        FIRST_VALUE(region_code) OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS first_region_code,
        region_code,
        sales
        FROM e_commerce.ecom_sales
),

calculated AS (
    SELECT 
        customer_id,
        SUM(sales) AS total_sales,
        MAX(CASE WHEN region_code <> first_region_code THEN 1 ELSE 0 END) AS multi_region_code
    FROM start_order
    GROUP BY customer_id
)

SELECT TOP 20 
    c.customer_id,
    r.city AS first_city,
    r.country,
    CAST (c.total_sales AS DECIMAL(16,2)) AS total_sales,
    (SELECT CAST(100.0 *SUM(multi_region_code)/COUNT(*) AS DECIMAL(5, 2)) FROM calculated ) AS multi_region_pct
FROM calculated AS c 
JOIN e_commerce.ecom_sales AS s1 
    ON s1.row_id = (SELECT TOP 1 s2.row_id 
                    FROM e_commerce.ecom_sales AS s2
                    WHERE s2.customer_id = c.customer_id
                    ORDER BY s2.order_date, s2.row_id)
JOIN e_commerce.region AS r ON s1.region_code = r.region_code
WHERE c.multi_region_code = 1
ORDER BY c.total_sales DESC, c.customer_id;


--Q14: Team CRM cần phân khúc khách hàng theo RFM (Recency: số ngày từ đơn gần nhất, Frequency: số đơn, Monetary: tổng chi tiêu). 
--Chia mỗi chỉ số thành 5 mức (1-5, 5 là tốt nhất). Tính điểm RFM tổng hợp. Gửi chị top 20 khách có RFM cao nhất để team chạy loyalty program

with max_dates AS (
    SELECT MAX(order_date) AS max_date
    FROM e_commerce.ecom_sales),

RFM_raw AS (
    SELECT 
        s.customer_id,
        DATEDIFF(day, MAX(s.order_date), (SELECT max_date FROM max_dates)) AS recency,
        COUNT(DISTINCT s.order_id) AS frequency,
        SUM(s.sales) AS monetary
    FROM e_commerce.ecom_sales AS s
    GROUP BY s.customer_id
),

RFM_scores AS (
    SELECT customer_id, recency, frequency, monetary,
        NTILE(5) OVER (ORDER BY recency DESC) AS r_score, --Càng nhỏ thì điểm càng cao
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM RFM_raw
)

SELECT TOP 20
    customer_id,
    recency, frequency, CAST(monetary AS DECIMAL(16, 2)) AS monetary,
    r_score, f_score, m_score,
    r_score + f_score + m_score AS scores
FROM RFM_scores
ORDER BY scores DESC, monetary DESC, customer_id;


--Q15: top 15 cặp sản phẩm hay xuất hiện cùng trong 1 đơn hàng. Chỉ xét đơn có từ 2 sản phẩm khác nhau trở lên. 
--Output: sản phẩm A, sản phẩm B, số lần xuất hiện cùng

WITH order_products AS (
  SELECT DISTINCT s.order_id, s.product_code
  FROM e_commerce.ecom_sales AS s
),
pairs AS (
  SELECT
    a.product_code AS product_a_code,
    b.product_code AS product_b_code,
    COUNT(*) AS times_together
  FROM order_products AS a
  JOIN order_products AS b
    ON b.order_id = a.order_id
   AND b.product_code > a.product_code
  GROUP BY a.product_code, b.product_code
)
SELECT TOP (15)
  pa.product AS product_a,
  pb.product AS product_b,
  pr.times_together
FROM pairs AS pr
JOIN e_commerce.product AS pa
  ON pa.product_code = pr.product_a_code
JOIN e_commerce.product AS pb
  ON pb.product_code = pr.product_b_code
ORDER BY pr.times_together DESC, product_a, product_b;