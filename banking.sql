--Thống kê tổng số data và số dòng NULL của từng cột trong bảng thuộc schema 

DECLARE @SchemaName NVARCHAR(128) = 'banking'; -- <-- TÊN SCHEMA 
DECLARE @TableName NVARCHAR(128) = 'transactions';    -- <-- TÊN BẢNG 

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

SELECT TOP 5 * FROM banking.transactions; 
SELECT TOP 5 * FROM banking.users;
SELECT TOP 5 * FROM banking.mcc_codes;
SELECT TOP 5 * FROM banking.cards;

--Q1: tổng số giao dịch thẻ của Bank trong năm 2023 - 1 con số

SELECT COUNT(*) AS giaodichthe
FROM banking.transactions
WHERE date >= '2023-01-01' AND date < '2024-01-01';

--Q2: top 5 thành phố merchant có nhiều giao dịch nhất + tổng số tiền giao dịch ở đó. 
--Để team marketing chọn địa điểm chạy campaign thẻ mới.

SELECT TOP 5
    merchant_city,
    COUNT(*) AS sogiaodich,
    CAST(SUM(amount) AS DECIMAL(16,2))AS tongsotien
FROM banking.transactions
GROUP BY merchant_city
ORDER BY sogiaodich DESC, tongsotien DESC;

--Q3: phân phối khách theo credit score chia 5 nhóm: dưới 580 (poor), 580-669 (fair), 670-739 (good), 
--740-799 (very good), 800+ (excellent). Cần để đánh giá chất lượng portfolio khách

--Câu này khá hay, phân nhóm KH, có hàm sum(COUNT (*)) over() đáng để học,
--is the trick for a whole-table total inside a grouped query: window functions run after grouping,
--so they see the groups, not the raw rows.
WITH band AS (
    SELECT
        CASE
            WHEN credit_score < 580 THEN 'Poor'
            WHEN credit_score < 670 THEN 'Fair'
            WHEN credit_score < 740 THEN 'Good'
            WHEN credit_score < 800 THEN 'Very good'
            ELSE 'Excellent'
        END AS score_band
    FROM banking.users
    )
SELECT 
    score_band,
    COUNT(*) AS customer,
    CAST(100.0 * COUNT(*)/ SUM(COUNT(*)) OVER() AS DECIMAL (5,2)) AS pct 
FROM band
GROUP BY score_band
ORDER BY score_band;

--Q4: có bao nhiêu thẻ theo từng brand (Visa, Mastercard, Amex, Discover)? Kèm % trên tổng. Chị cần để deal với đối tác Visa tuần sau.

SELECT 
    card_brand,
    COUNT(*) AS soluong,
    CAST(COUNT(*)*100.0 / SUM(COUNT(*)) OVER() AS DECIMAL (5,2)) AS pct
FROM banking.cards
GROUP BY card_brand
ORDER BY card_brand;

--Q5: % giao dịch bị lỗi (fail transaction) trên tổng, 
--và chi tiết số lượng theo từng loại lỗi. Anh cần để báo cáo cho board về chất lượng hệ thống.

--thêm hàm isnull cho output được đẹp
SELECT 
    ISNULL(errors,'OK') AS errors_type,
    COUNT(*) AS soluong,
    CAST(COUNT(*)*100.0 / SUM(COUNT(*)) OVER() AS DECIMAL (6,3)) AS pct
FROM banking.transactions
GROUP BY errors
ORDER BY soluong DESC; 

--Q6: Team marketing cần top 10 khách tiêu nhiều nhất trong 1 tháng bất kỳ (tính tổng chi tiêu của khách đó trong cùng 1 tháng). 
--Kèm giới tính + thu nhập năm của khách để phân khúc.

-- WHERE amount > 0 drops refunds. Keep them and a customer who bought then returned immediately nets out near zero and slides off the chart, despite genuinely swiping the largest amount that month - either choice can be right, but choose consciously
WITH aaa AS (
    SELECT 
        client_id, 
        FORMAT(date, 'yyyy-MM') AS year_month,
        SUM(amount) AS spent
    FROM banking.transactions 
    WHERE amount > 0
    GROUP BY client_id, FORMAT(date, 'yyyy-MM')
)

SELECT TOP 10 
    aaa.client_id, 
    u.gender,
    u.yearly_income,
    aaa.spent, 
    aaa.year_month
FROM aaa 
INNER JOIN banking.users AS u ON aaa.client_id = u.id
ORDER BY aaa.spent DESC, aaa.client_id;

--Q7: top 10 category merchant có khách chi tiêu nhiều nhất 
--(chỉ tính giao dịch hợp lệ, không tính refund). Để hiểu khách tiêu tiền vào đâu

-- LƯU Ý: error is null để thành công và amount để no refund
SELECT TOP 10
    t.mcc,
    m.description,
    CAST(SUM(t.amount) AS DECIMAL(16,2))AS tongsotien,
    COUNT(*) AS soluong
FROM banking.transactions AS t 
JOIN banking.mcc_codes AS m ON t.mcc = m.mcc_id
WHERE t.amount > 0 AND t.errors IS NULL
GROUP BY t.mcc, m.description
ORDER BY tongsotien DESC;

--Q8: check tỷ lệ sử dụng hạn mức thẻ tín dụng của từng khách trong 30 ngày gần nhất (tổng chi tiêu / tổng hạn mức)
-- Chỉ xét thẻ credit, không tính debit/prepaid. Khách utilization cao = rủi ro default cao


SELECT TOP 5 * FROM banking.cards;
SELECT TOP 5 * FROM banking.transactions;
