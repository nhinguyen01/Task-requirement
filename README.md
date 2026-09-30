# SQL Server with business requirement 

| Domain | Question | Answer | Note |
| --- | :---: | :---: | --- |
| E-commerce | 15 | 15 | 7 8 13 15 |
| Banking | 15 | 7 | 0 |
| Retail | 15 | 0 | 0 |
| Games | 15 | 5 | 0 |


## I. Schema E-commerce

**1. Dataset**  

Total: 4 table, >100K rows, 34 columns

| Table | Column | Row |
| --- | :---: | :---: |
|customer| 11 columns| >17K rows|
|ecom_sales| 11 columns| >51K rows|
|product| 4 columns| >28K rows|
|region| 8 columns| >3K rows|

**2. Analyst** 

Nhận request từ các phòng ban để thực hiện phân tích, trọng tâm xoay quanh DT, SKU, discount, phân khúc KH theo FRM, cross sell, KH có nguy cơ churn

## II. Schema Banking

**1. Dataset**  

Total: 4 table, >165K rows, 40 columns

| Table | Column | Row |
| --- | :---: | :---: |
| cards | 12 columns | >6K rows| 
| mcc_codes | 2 columns | 109 rows |
| transactions | 12 columns | >157K rows |
| users | 14 columns | 2K rows |

**2. Analyst**  

Nhận request từ các phòng ban để thực hiện phân tích, trọng tâm xoay quanh transaction, phân khúc KH theo score, merchant, KH có nguy cơ churn

## III. Schema Games

**1. Dataset**  

Total: 1 table, >16K rows, 16 columns

**2. Analyst**  

Nhận request từ các phòng ban để thực hiện phân tích, trọng tâm xoay quanh DT, SKU, discount, phân khúc KH theo FRM, cross sell, KH có nguy cơ churn