-- Query 1: List of markets for "Atliq Exclusive" in the APAC region
SELECT 
    customer, market, region
FROM
    dim_customer
WHERE
    region = 'APAC'
        AND customer = 'Atliq Exclusive';

    -- Query 2: Percentage of unique product increase in 2021 vs. 2020
    WITH products_2020 AS (
        SELECT COUNT(DISTINCT product_code) AS unique_products_2020
        FROM fact_sales_monthly
        WHERE fiscal_year = '2020'
    ),
    products_2021 AS (
        SELECT COUNT(DISTINCT product_code) AS unique_products_2021
        FROM fact_sales_monthly
        WHERE fiscal_year = '2021'
    )
    SELECT 
        p2020.unique_products_2020, 
        p2021.unique_products_2021, 
        CONCAT(ROUND((p2021.unique_products_2021 - p2020.unique_products_2020) / p2020.unique_products_2020 * 100, 1), '%') AS percentage_chg
    FROM products_2020 p2020, products_2021 p2021;

    -- Query 3: Unique product counts for each segment, sorted in descending order
SELECT 
    segment, COUNT(DISTINCT product_code) AS product_count
FROM
    dim_product
GROUP BY segment
ORDER BY product_count DESC;

    -- Query 4: Segment with the most increase in unique products (2021 vs 2020)
    WITH product_info AS (
        SELECT 
            p.product_code, sm.fiscal_year, p.segment
        FROM fact_sales_monthly AS sm
        JOIN dim_product AS p
        ON p.product_code = sm.product_code
    ),
    unique_product_2021 AS (
        SELECT COUNT(DISTINCT product_code) AS product_count_2021, segment 
        FROM product_info
        WHERE fiscal_year = 2021
        GROUP BY segment
    ),
    unique_product_2020 AS (
        SELECT COUNT(DISTINCT product_code) AS product_count_2020, segment 
        FROM product_info
        WHERE fiscal_year = 2020
        GROUP BY segment
    )
    SELECT 
        u2020.segment,
        u2021.product_count_2021,
        u2020.product_count_2020,
        u2021.product_count_2021 - u2020.product_count_2020 AS difference
    FROM unique_product_2020 u2020
    JOIN unique_product_2021 u2021
    ON u2021.segment = u2020.segment
    ORDER BY difference DESC;

    -- Query 5: Products with the highest and lowest manufacturing costs
SELECT 
    product_code, product, manufacturing_cost
FROM
    fact_manufacturing_cost
        JOIN
    dim_product USING (product_code)
WHERE
    manufacturing_cost = (SELECT 
            MAX(manufacturing_cost)
        FROM
            fact_manufacturing_cost) 
UNION SELECT 
    product_code, product, manufacturing_cost
FROM
    fact_manufacturing_cost
        JOIN
    dim_product USING (product_code)
WHERE
    manufacturing_cost = (SELECT 
            MIN(manufacturing_cost)
        FROM
            fact_manufacturing_cost);

    -- Query 6: Top 5 customers with the highest average pre-invoice discount in 2021 (Indian market)
SELECT 
    customer_code,
    customer,
    ROUND(AVG(pre_invoice_discount_pct), 2) AS average_discount_percentage
FROM
    fact_pre_invoice_deductions
        JOIN
    dim_customer USING (customer_code)
WHERE
    fiscal_year = '2021'
        AND market = 'India'
GROUP BY customer_code , customer
ORDER BY average_discount_percentage DESC
LIMIT 5;

    -- Query 7: Gross sales report for "Atliq Exclusive" by month and year
    WITH CTE1 AS (
        SELECT 
            MONTHNAME(date) AS month, 
            YEAR(date) AS year, 
            ROUND(SUM(sold_quantity * gross_price), 1) AS gross_sales_amount
        FROM fact_sales_monthly
        JOIN dim_customer
        USING (customer_code)
        JOIN fact_gross_price
        USING (fiscal_year, product_code)
        WHERE customer = 'Atliq Exclusive'
        GROUP BY year, month
    ),
    CTE2 AS (
        SELECT 
            month, year, 
            CONCAT(FORMAT(gross_sales_amount / 1000000, 1), 'M') AS gross_sales_amount
        FROM CTE1
    )
    SELECT * FROM CTE2;

    -- Query 8: Quarter with the maximum total sold quantity in 2020
    WITH CTE1 AS (
        SELECT 
            date, sold_quantity, fiscal_year,        
            CASE 
                WHEN MONTH(date) IN (9, 10, 11) THEN 'Q1'
                WHEN MONTH(date) IN (12, 1, 2) THEN 'Q2'
                WHEN MONTH(date) IN (3, 4, 5) THEN 'Q3'
                WHEN MONTH(date) IN (6, 7, 8) THEN 'Q4'
            END AS quarter
        FROM fact_sales_monthly
    ),
    CTE2 AS (
        SELECT quarter, FORMAT(SUM(sold_quantity) / 1000000, 1) AS total_sold_quantity
        FROM CTE1
        WHERE fiscal_year = '2020'
        GROUP BY quarter
    )
    SELECT quarter, CONCAT(total_sold_quantity, 'M') AS total_sold_quantity
    FROM CTE2
    ORDER BY total_sold_quantity DESC;

    -- Query 9: Channel with the highest gross sales in 2021 and contribution percentage
    WITH CTE1 AS (
        SELECT 
            channel,
            SUM(sold_quantity * gross_price) / 1000000 AS total_gross_sales_mln
        FROM fact_sales_monthly
        JOIN dim_customer
        USING (customer_code)
        JOIN fact_gross_price
        USING (product_code)
        WHERE fact_sales_monthly.fiscal_year = 2021
        GROUP BY channel
    ),
    CTE2 AS (
        SELECT 
            channel,
            CONCAT(ROUND(total_gross_sales_mln, 1), 'M') AS gross_sales_mln,
            CONCAT(ROUND(total_gross_sales_mln / SUM(total_gross_sales_mln) OVER() * 100, 1), '%') AS percentage
        FROM CTE1
    )
    SELECT * FROM CTE2
    ORDER BY percentage DESC;

    -- Query 10: Top 3 products in each division by total sold quantity in 2021
    WITH CTE1 AS (
        SELECT 
            division, 
            product_code, 
            product,
            SUM(sold_quantity) AS total_sold_quantity
        FROM 
            fact_sales_monthly
        JOIN dim_product
        USING (product_code)
        WHERE fiscal_year = 2021
        GROUP BY division, product_code, product
    ),
    CTE2 AS (
        SELECT *,
        DENSE_RANK() OVER (PARTITION BY division ORDER BY total_sold_quantity DESC) AS rank_order
        FROM CTE1
    )
    SELECT * FROM CTE2
    WHERE rank_order <= 3;