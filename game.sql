SELECT TOP 5 * FROM mobile_games.games;

--Thống kê tổng số data và số dòng NULL của từng cột trong bảng thuộc schema 

DECLARE @SchemaName NVARCHAR(128) = 'mobile_games'; 
DECLARE @TableName NVARCHAR(128) = 'games';   
DECLARE @FullTableName NVARCHAR(256) = QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName);
DECLARE @DynamicSQL NVARCHAR(MAX) = '';

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

IF LEN(@DynamicSQL) > 0
BEGIN
    SET @DynamicSQL = LEFT(@DynamicSQL, LEN(@DynamicSQL) - 10);
    EXEC sp_executesql @DynamicSQL;
END
ELSE
BEGIN
    PRINT 'Không tìm thấy bảng hoặc schema này! Vui lòng kiểm tra lại chính xác chữ hoa/chữ thường.';
END


--Q1: Số game free vs paid + % mỗi nhóm. Khách hỏi nhanh để đánh giá landscape monetization

---Solution 1: Use CASE WHEN
SELECT 
    CAST(SUM(CASE WHEN price_usd > 0 THEN 1 ELSE 0 END) AS DECIMAL(5,0)) AS game_paid_quantity,
    CAST(SUM(CASE WHEN price_usd = 0 THEN 1 ELSE 0 END) AS DECIMAL(5,0)) AS game_free_quantity,
    CAST(SUM(CASE WHEN price_usd > 0 THEN 1 ELSE 0 END)*100.0/COUNT(*) AS DECIMAL(5,2)) AS pct_paid,
    CAST(SUM(CASE WHEN price_usd = 0 THEN 1 ELSE 0 END)*100.0/COUNT(*) AS DECIMAL(5,2)) AS pct_free
FROM mobile_games.games;

---Solution 2: Use SUM ... OVER ()
SELECT
  CASE WHEN price_usd = 0 THEN 'Free' ELSE 'Paid' END AS pricing_model,
  COUNT(*) AS games_quantity,
  CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5, 2)) AS pct_of_total
FROM mobile_games.games 
GROUP BY CASE WHEN price_usd = 0 THEN 'Free' ELSE 'Paid' END
ORDER BY games_quantity DESC;

--Q2: top 10 developer có nhiều game nhất trên App Store-khách đang tìm partner publish

---AVG tự động bỏ qua các giá trị NULL, vì vậy cột avg_rating chỉ phản ánh những game có điểm đánh giá. Trong bộ dữ liệu này, điều đó rất đáng lưu ý: 44% số game không có average_user_rating. Một nhà phát triển có 50 game nhưng chỉ 3 game được đánh giá vẫn có thể hiển thị một mức điểm trung bình trông rất “chắc chắn”.
---Đây chính là sự khác biệt giữa COUNT(*) (đếm số dòng) và COUNT(column) (đếm các giá trị không phải NULL) — một trong những chi tiết hữu ích nhất của SQL, nhưng cũng là một trong những chi tiết ít được sử dụng nhất.
-- Để thông tin trung thực hơn, hãy thêm COUNT(average_user_rating) để người đọc biết có bao nhiêu game thực sự được dùng để tính giá trị trung bình. 

SELECT TOP 10 
    developer,  
    COUNT(*) AS quantity,
    CAST(AVG(average_user_rating) AS DECIMAL(6,2)) AS avg_review,
    SUM(user_rating_count) AS total_user_review
FROM mobile_games.games
WHERE developer IS NOT NULL
GROUP BY developer
ORDER BY quantity DESC;

--Q3: rating trung bình + số review trung bình của từng genre chính. Dùng để so sánh popularity giữa các thể loại

SELECT 
    primary_genre,
    COUNT(*) AS games, --tất cả các dòng/game (bất kể game có rating hay k)
    COUNT(average_user_rating) AS game_with_rating,
    CAST(AVG(average_user_rating) AS DECIMAL (6,2)) AS avg_rating, --chỉ game có rating vì avg bỏ qua null
    CAST(AVG(user_rating_count) AS DECIMAL (16,2)) AS avg_user_review 
FROM mobile_games.games
GROUP BY primary_genre
ORDER BY games DESC;

--Q4: số game phát hành năm 2019 theo genre - phân phối output của các studio trong năm gần nhất mình có dữ liệu.

--- WHERE FORMAT(release_date,'yyyy') = '2019' --- cách dùng này cũng dc nhưng điều này
--- buộc SQL phải format lại từng năm rồi chọn 2019, nên cách dùng ở dưới vẫn ok và nhanh hơn

SELECT 
    primary_genre,
    COUNT(*) AS counted,
    CAST(AVG(average_user_rating) AS DECIMAL (6,2)) AS avg_rating
FROM mobile_games.games
WHERE release_date >= '2019-01-01'
  AND release_date < '2020-01-01'
GROUP BY primary_genre
ORDER BY counted DESC;

--Q5: phân phối giá game: 0 (free), 0-1 USD, 1-5, 5-20, trên 20. Số game mỗi mức

WITH aaa AS (
    SELECT 
        CASE 
            WHEN price_usd = 0 THEN '1. Free' 
            WHEN price_usd < 1 THEN '2. 0-1 USD'
            WHEN price_usd < 5 THEN '3. 1-5 USD'
            WHEN price_usd < 20 THEN '4. 5-20 USD'
            WHEN price_usd >= 20 THEN '5. 20 USD' 
        END AS games_histogram,
        average_user_rating
    FROM mobile_games.games)

SELECT 
    games_histogram, 
    COUNT(*) AS counted,
    CAST(100.0 * COUNT(*)/ SUM(COUNT(*)) OVER() AS DECIMAL (5,2)) AS pct,
    CAST(AVG(average_user_rating) AS DECIMAL(6,2)) AS avg_rating
FROM aaa
GROUP BY games_histogram
ORDER BY games_histogram;

--Q6: top 20 game có rating cao nhất, chỉ xét game có trên 10.000 review (loại bỏ fake rating). Để làm gallery showcase cho client

SELECT TOP 20 
    g.name, g.developer, g.primary_genre, g.user_rating_count,
    CAST(g.average_user_rating AS DECIMAL (6,2)) as rating,
    CAST(g.user_rating_count AS DECIMAL (16,2)) as counted,
    CAST(g.price_usd AS DECIMAL(8, 2)) AS price_usd
FROM mobile_games.games AS g
WHERE g.user_rating_count > 10000 AND g.average_user_rating IS NOT NULL
ORDER BY rating DESC, counted DESC, g.name;

--Q7: ma trận số game theo age rating × genre chính. Để đánh giá genre nào target trẻ em, genre nào adult.
--(PIVOT TABLE)

SELECT 
    primary_genre,
    CAST(SUM(CASE WHEN age_rating = '17+' THEN 1 ELSE 0 END) AS INT) AS '17+',
    CAST(SUM(CASE WHEN age_rating = '12+' THEN 1 ELSE 0 END) AS INT) AS '12+',
    CAST(SUM(CASE WHEN age_rating = '9+' THEN 1 ELSE 0 END) AS INT) AS '9+',
    CAST(SUM(CASE WHEN age_rating = '4+' THEN 1 ELSE 0 END) AS INT) AS '4+',
    COUNT(*) AS total_games
FROM mobile_games.games
GROUP BY primary_genre
ORDER BY primary_genre;

--Q8: Tính size trung bình của game theo genre tính bằng MB. Genre nào đòi hỏi storage lớn nhất?
--- Nếu không có where thì count(*) sẽ tính cả các null vào

SELECT 
    g.primary_genre,
    CAST(AVG(g.size_in_bytes)/1048576 AS DECIMAL(10,2)) AS avg_size_in_mb,
    COUNT(*) AS games,
    CAST(MAX(g.size_in_bytes)/1048576 AS DECIMAL(10,2)) AS max_size_in_mb
FROM mobile_games.games AS g
WHERE g.size_in_bytes IS NOT NULL
GROUP BY g.primary_genre
ORDER BY avg_size_in_mb DESC;

--Q9: số ngôn ngữ mà mỗi game support, tính trung bình theo genre. Genre nào đầu tư localization nhiều nhất?

SELECT TOP 3 *FROM mobile_games.games;

SELECT DISTINCT(languages) FROM mobile_games.games;