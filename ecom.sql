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
JOIN e_commerce.region AS r
  ON r.region_code = s.region_code
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


--Q11: 

SELECT TOP 5 * FROM e_commerce.ecom_sales;

