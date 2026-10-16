/* ============================================================
   HARBOUR FRESH MARKET
   File: 04_sales_profitability.sql
   Purpose: Revenue, growth, margin, budget and SKU performance
   ============================================================ */

USE harbour_fresh_market;

/* Reusable analytical layer. Returns are converted to signed values. */
CREATE OR REPLACE VIEW vw_sales_enriched AS
SELECT
    s.sale_line_id, s.transaction_id, s.date_id, d.full_date, d.year,
    d.month_number, d.month_name, d.quarter,
    s.store_id, st.store_name,
    s.product_id, p.sku_number, p.product_name, p.department_id,
    dep.department_name, p.category, p.brand, p.private_label_flag,
    s.promotion_id, s.quantity, s.regular_unit_price, s.net_unit_price,
    s.unit_cost, s.discount_amount, s.return_flag,
    CASE WHEN s.return_flag=1 THEN -s.quantity ELSE s.quantity END AS net_units,
    CASE WHEN s.return_flag=1 THEN -(s.quantity*s.net_unit_price)
         ELSE s.quantity*s.net_unit_price END AS revenue,
    CASE WHEN s.return_flag=1 THEN -(s.quantity*s.unit_cost)
         ELSE s.quantity*s.unit_cost END AS cogs,
    CASE WHEN s.return_flag=1 THEN -(s.quantity*(s.net_unit_price-s.unit_cost))
         ELSE s.quantity*(s.net_unit_price-s.unit_cost) END AS gross_profit,
    CASE WHEN s.return_flag=1 THEN -(s.quantity*s.discount_amount)
         ELSE s.quantity*s.discount_amount END AS discount_value
FROM fact_sales s
JOIN dim_date d ON s.date_id=d.date_id
JOIN dim_store st ON s.store_id=st.store_id
JOIN dim_product p ON s.product_id=p.product_id
JOIN dim_department dep ON p.department_id=dep.department_id;

/* 1. Executive KPI baseline */
SELECT
    ROUND(SUM(revenue),2) revenue,
    SUM(net_units) units,
    ROUND(SUM(gross_profit),2) gross_profit,
    ROUND(100*SUM(gross_profit)/NULLIF(SUM(revenue),0),2) gross_margin_pct
FROM vw_sales_enriched;

/* 2. Year-over-year performance */
WITH y AS (
    SELECT year, SUM(revenue) revenue, SUM(gross_profit) gp, SUM(net_units) units
    FROM vw_sales_enriched GROUP BY year
), x AS (
    SELECT *, LAG(revenue) OVER(ORDER BY year) prior_revenue,
              LAG(gp) OVER(ORDER BY year) prior_gp
    FROM y
)
SELECT
    year, ROUND(revenue,2) revenue, units, ROUND(gp,2) gross_profit,
    ROUND(100*gp/NULLIF(revenue,0),2) gross_margin_pct,
    ROUND(100*(revenue-prior_revenue)/NULLIF(prior_revenue,0),2) revenue_yoy_pct,
    ROUND(100*(gp-prior_gp)/NULLIF(prior_gp,0),2) gp_yoy_pct
FROM x ORDER BY year;

/* 3. Monthly trend */
SELECT
    year, month_number, month_name,
    ROUND(SUM(revenue),2) revenue,
    ROUND(SUM(gross_profit),2) gross_profit,
    ROUND(100*SUM(gross_profit)/NULLIF(SUM(revenue),0),2) gross_margin_pct
FROM vw_sales_enriched
GROUP BY year,month_number,month_name
ORDER BY year,month_number;

/* 4. Store performance */
SELECT
    store_name,
    ROUND(SUM(revenue),2) revenue,
    ROUND(SUM(gross_profit),2) gross_profit,
    ROUND(100*SUM(gross_profit)/NULLIF(SUM(revenue),0),2) gross_margin_pct
FROM vw_sales_enriched
GROUP BY store_name
ORDER BY revenue DESC;

/* 5. Department growth and margin movement */
WITH d AS (
    SELECT department_name,
        SUM(CASE WHEN year=2024 THEN revenue ELSE 0 END) rev_2024,
        SUM(CASE WHEN year=2025 THEN revenue ELSE 0 END) rev_2025,
        SUM(CASE WHEN year=2024 THEN gross_profit ELSE 0 END) gp_2024,
        SUM(CASE WHEN year=2025 THEN gross_profit ELSE 0 END) gp_2025
    FROM vw_sales_enriched
    GROUP BY department_name
)
SELECT
    department_name,
    ROUND(rev_2024,2) revenue_2024,
    ROUND(rev_2025,2) revenue_2025,
    ROUND(100*(rev_2025-rev_2024)/NULLIF(rev_2024,0),2) revenue_growth_pct,
    ROUND(100*gp_2024/NULLIF(rev_2024,0),2) margin_2024_pct,
    ROUND(100*gp_2025/NULLIF(rev_2025,0),2) margin_2025_pct,
    ROUND((100*gp_2025/NULLIF(rev_2025,0))-(100*gp_2024/NULLIF(rev_2024,0)),2) margin_change_pp
FROM d
ORDER BY margin_change_pp;

/* 6. Top 5 SKUs within each department, 2025 */
WITH p AS (
    SELECT department_name, product_id, sku_number, product_name,
           SUM(revenue) revenue, SUM(gross_profit) gp, SUM(net_units) units
    FROM vw_sales_enriched
    WHERE year=2025
    GROUP BY department_name,product_id,sku_number,product_name
), r AS (
    SELECT *, DENSE_RANK() OVER(PARTITION BY department_name ORDER BY revenue DESC) revenue_rank
    FROM p
)
SELECT department_name,revenue_rank,sku_number,product_name,
       ROUND(revenue,2) revenue, units, ROUND(gp,2) gross_profit
FROM r
WHERE revenue_rank<=5
ORDER BY department_name,revenue_rank;

/* 7. Pricing pressure: weighted selling-price change vs cost change */
WITH pc AS (
    SELECT department_name, year,
        SUM(net_unit_price*quantity)/NULLIF(SUM(quantity),0) avg_net_price,
        SUM(unit_cost*quantity)/NULLIF(SUM(quantity),0) avg_unit_cost
    FROM vw_sales_enriched
    WHERE return_flag=0
    GROUP BY department_name,year
), c AS (
    SELECT department_name,
        MAX(CASE WHEN year=2024 THEN avg_net_price END) price_2024,
        MAX(CASE WHEN year=2025 THEN avg_net_price END) price_2025,
        MAX(CASE WHEN year=2024 THEN avg_unit_cost END) cost_2024,
        MAX(CASE WHEN year=2025 THEN avg_unit_cost END) cost_2025
    FROM pc GROUP BY department_name
)
SELECT
    department_name,
    ROUND(100*(price_2025-price_2024)/NULLIF(price_2024,0),2) selling_price_change_pct,
    ROUND(100*(cost_2025-cost_2024)/NULLIF(cost_2024,0),2) cost_change_pct
FROM c
ORDER BY (cost_2025-cost_2024)/NULLIF(cost_2024,0)
       - (price_2025-price_2024)/NULLIF(price_2024,0) DESC;

/* 8. Actual vs budget by store */
WITH actual AS (
    SELECT
        CAST(DATE_FORMAT(full_date,'%Y%m01') AS UNSIGNED) month_start_date_id,
        store_id, department_id,
        SUM(revenue) actual_revenue,
        SUM(gross_profit) actual_gp
    FROM vw_sales_enriched
    GROUP BY 1,2,3
), bva AS (
    SELECT b.store_id, st.store_name,
           SUM(a.actual_revenue) actual_revenue,
           SUM(b.budget_revenue) budget_revenue,
           SUM(a.actual_gp) actual_gp,
           SUM(b.budget_gross_profit) budget_gp
    FROM fact_budget b
    JOIN dim_store st ON b.store_id=st.store_id
    LEFT JOIN actual a
      ON b.month_start_date_id=a.month_start_date_id
     AND b.store_id=a.store_id
     AND b.department_id=a.department_id
    GROUP BY b.store_id,st.store_name
)
SELECT
    store_name,
    ROUND(actual_revenue,2) actual_revenue,
    ROUND(budget_revenue,2) budget_revenue,
    ROUND(actual_revenue-budget_revenue,2) revenue_variance,
    ROUND(100*(actual_revenue-budget_revenue)/NULLIF(budget_revenue,0),2) revenue_variance_pct,
    ROUND(actual_gp-budget_gp,2) gp_variance
FROM bva
ORDER BY revenue_variance;

/* 9. Promotional vs non-promotional margin */
SELECT
    CASE WHEN promotion_id IS NULL THEN 'Non-Promotional' ELSE 'Promotional' END sale_type,
    ROUND(SUM(revenue),2) revenue,
    ROUND(SUM(gross_profit),2) gross_profit,
    ROUND(100*SUM(gross_profit)/NULLIF(SUM(revenue),0),2) gross_margin_pct
FROM vw_sales_enriched
GROUP BY sale_type;