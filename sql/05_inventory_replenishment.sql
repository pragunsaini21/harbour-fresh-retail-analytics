/* ============================================================
   HARBOUR FRESH MARKET
   File: 05_inventory_replenishment.sql
   Purpose: Inventory health, stockouts, working capital and loss
   ============================================================ */

USE harbour_fresh_market;

CREATE OR REPLACE VIEW vw_inventory_enriched AS
SELECT
    i.inventory_snapshot_id, i.date_id, d.full_date, d.year,
    i.store_id, st.store_name,
    i.product_id, p.sku_number, p.product_name, p.department_id,
    dep.department_name,
    i.system_on_hand_qty, i.reorder_point_qty, i.safety_stock_qty,
    i.unit_cost_at_snapshot,
    i.system_on_hand_qty*i.unit_cost_at_snapshot AS inventory_value,
    CASE WHEN i.system_on_hand_qty=0 THEN 1 ELSE 0 END AS stockout_flag,
    CASE WHEN i.system_on_hand_qty<=i.reorder_point_qty THEN 1 ELSE 0 END AS reorder_flag
FROM fact_inventory_snapshot i
JOIN dim_date d ON i.date_id=d.date_id
JOIN dim_store st ON i.store_id=st.store_id
JOIN dim_product p ON i.product_id=p.product_id
JOIN dim_department dep ON p.department_id=dep.department_id;

/* 1. Inventory risk by store, 2025 */
SELECT
    store_name,
    ROUND(100*AVG(stockout_flag),2) stockout_rate_pct,
    ROUND(100*AVG(reorder_flag),2) at_or_below_reorder_pct,
    ROUND(AVG(inventory_value),2) avg_inventory_value_per_snapshot
FROM vw_inventory_enriched
WHERE year=2025
GROUP BY store_name
ORDER BY stockout_rate_pct DESC;

/* 2. Inventory risk by department, 2025 */
SELECT
    department_name,
    ROUND(100*AVG(stockout_flag),2) stockout_rate_pct,
    ROUND(100*AVG(reorder_flag),2) at_or_below_reorder_pct,
    ROUND(AVG(inventory_value),2) avg_inventory_value_per_snapshot
FROM vw_inventory_enriched
WHERE year=2025
GROUP BY department_name
ORDER BY stockout_rate_pct DESC;

/* 3. Inventory turnover by department, 2025 */
WITH inv AS (
    SELECT department_id,department_name,full_date,SUM(inventory_value) daily_inventory_value
    FROM vw_inventory_enriched
    WHERE year=2025
    GROUP BY department_id,department_name,full_date
), avg_inv AS (
    SELECT department_id,department_name,AVG(daily_inventory_value) avg_inventory_value
    FROM inv GROUP BY department_id,department_name
), cogs AS (
    SELECT department_id,SUM(cogs) cogs
    FROM vw_sales_enriched
    WHERE year=2025
    GROUP BY department_id
)
SELECT
    a.department_name,
    ROUND(c.cogs,2) cogs,
    ROUND(a.avg_inventory_value,2) avg_inventory_value,
    ROUND(c.cogs/NULLIF(a.avg_inventory_value,0),2) inventory_turnover
FROM avg_inv a
JOIN cogs c ON a.department_id=c.department_id
ORDER BY inventory_turnover;

/* 4. Slow-moving / working-capital candidates, 2025 */
WITH inv AS (
    SELECT product_id,full_date,AVG(inventory_value) daily_inventory_value
    FROM vw_inventory_enriched
    WHERE year=2025
    GROUP BY product_id,full_date
), avg_inv AS (
    SELECT product_id,AVG(daily_inventory_value) avg_inventory_value
    FROM inv GROUP BY product_id
), sales AS (
    SELECT product_id,SUM(cogs) cogs,SUM(net_units) units
    FROM vw_sales_enriched
    WHERE year=2025
    GROUP BY product_id
)
SELECT
    p.sku_number,p.product_name,dep.department_name,
    ROUND(i.avg_inventory_value,2) avg_inventory_value,
    s.units,
    ROUND(s.cogs/NULLIF(i.avg_inventory_value,0),2) inventory_turnover
FROM avg_inv i
JOIN sales s ON i.product_id=s.product_id
JOIN dim_product p ON i.product_id=p.product_id
JOIN dim_department dep ON p.department_id=dep.department_id
WHERE i.avg_inventory_value>=20
ORDER BY inventory_turnover,avg_inventory_value DESC
LIMIT 25;

/* 5. Documented inventory loss by reason */
SELECT
    adjustment_reason,
    COUNT(*) events,
    -SUM(CASE WHEN quantity_adjusted<0 THEN quantity_adjusted ELSE 0 END) units_lost,
    ROUND(-SUM(CASE WHEN quantity_adjusted<0 THEN quantity_adjusted*unit_cost ELSE 0 END),2) loss_value
FROM fact_inventory_adjustment
WHERE adjustment_reason IN ('Spoilage','Damage','Expired Product','Theft / Shrink')
GROUP BY adjustment_reason
ORDER BY loss_value DESC;

/* 6. Documented inventory loss by department */
SELECT
    dep.department_name,
    COUNT(*) loss_events,
    ROUND(-SUM(CASE WHEN a.quantity_adjusted<0 THEN a.quantity_adjusted*a.unit_cost ELSE 0 END),2) loss_value
FROM fact_inventory_adjustment a
JOIN dim_product p ON a.product_id=p.product_id
JOIN dim_department dep ON p.department_id=dep.department_id
WHERE a.adjustment_reason IN ('Spoilage','Damage','Expired Product','Theft / Shrink')
GROUP BY dep.department_name
ORDER BY loss_value DESC;

/* 7. Physical-vs-system count variance */
SELECT
    dep.department_name,
    COUNT(*) count_events,
    SUM(ABS(c.physical_count_qty-c.system_qty_at_count)) absolute_unit_variance,
    ROUND(SUM(ABS(c.physical_count_qty-c.system_qty_at_count)*i.unit_cost_at_snapshot),2) absolute_variance_value
FROM fact_inventory_count c
JOIN dim_product p ON c.product_id=p.product_id
JOIN dim_department dep ON p.department_id=dep.department_id
LEFT JOIN fact_inventory_snapshot i
  ON c.date_id=i.date_id AND c.store_id=i.store_id AND c.product_id=i.product_id
GROUP BY dep.department_name
ORDER BY absolute_variance_value DESC;
