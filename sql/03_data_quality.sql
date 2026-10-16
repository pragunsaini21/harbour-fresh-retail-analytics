/* ============================================================
   HARBOUR FRESH MARKET
   File: 03_data_quality.sql
   Purpose: Validate completeness, uniqueness, referential integrity,
            numeric ranges and business-rule consistency before analysis
   ============================================================ */

USE harbour_fresh_market;

/* 1. EXPECTED ROW COUNTS */
SELECT 'dim_date' table_name, COUNT(*) actual_rows, 731 expected_rows FROM dim_date
UNION ALL SELECT 'dim_department',COUNT(*),12 FROM dim_department
UNION ALL SELECT 'dim_store',COUNT(*),4 FROM dim_store
UNION ALL SELECT 'dim_supplier',COUNT(*),24 FROM dim_supplier
UNION ALL SELECT 'dim_product',COUNT(*),360 FROM dim_product
UNION ALL SELECT 'dim_promotion',COUNT(*),16 FROM dim_promotion
UNION ALL SELECT 'bridge_promotion_product_store',COUNT(*),2352 FROM bridge_promotion_product_store
UNION ALL SELECT 'fact_budget',COUNT(*),1152 FROM fact_budget
UNION ALL SELECT 'fact_purchase_orders',COUNT(*),31381 FROM fact_purchase_orders
UNION ALL SELECT 'fact_inventory_snapshot',COUNT(*),1052640 FROM fact_inventory_snapshot
UNION ALL SELECT 'fact_inventory_count',COUNT(*),2688 FROM fact_inventory_count
UNION ALL SELECT 'fact_inventory_adjustment',COUNT(*),4371 FROM fact_inventory_adjustment
UNION ALL SELECT 'fact_promotion_spend',COUNT(*),192 FROM fact_promotion_spend
UNION ALL SELECT 'fact_sales',COUNT(*),426471 FROM fact_sales;

/* 2. DUPLICATE / GRAIN CHECKS */
SELECT sku_number, COUNT(*) duplicate_count
FROM dim_product
GROUP BY sku_number
HAVING COUNT(*) > 1;

SELECT date_id, store_id, product_id, COUNT(*) duplicate_count
FROM fact_inventory_snapshot
GROUP BY date_id, store_id, product_id
HAVING COUNT(*) > 1;

SELECT month_start_date_id, store_id, department_id, COUNT(*) duplicate_count
FROM fact_budget
GROUP BY month_start_date_id, store_id, department_id
HAVING COUNT(*) > 1;

SELECT promotion_id, product_id, store_id, COUNT(*) duplicate_count
FROM bridge_promotion_product_store
GROUP BY promotion_id, product_id, store_id
HAVING COUNT(*) > 1;

/* 3. REQUIRED NULL CHECKS */
SELECT
    SUM(product_id IS NULL) AS null_product_ids,
    SUM(sku_number IS NULL) AS null_skus,
    SUM(product_name IS NULL) AS null_product_names,
    SUM(department_id IS NULL) AS null_departments,
    SUM(category IS NULL) AS null_categories,
    SUM(storage_type IS NULL) AS null_storage_types
FROM dim_product;

SELECT
    SUM(date_id IS NULL) AS null_dates,
    SUM(store_id IS NULL) AS null_stores,
    SUM(product_id IS NULL) AS null_products,
    SUM(quantity IS NULL) AS null_quantities,
    SUM(net_unit_price IS NULL) AS null_net_prices,
    SUM(unit_cost IS NULL) AS null_costs
FROM fact_sales;

/* Legitimate optional NULLs — report, do not automatically treat as errors. */
SELECT
    SUM(brand IS NULL) AS products_without_brand,
    SUM(shelf_life_days IS NULL) AS products_without_shelf_life
FROM dim_product;

SELECT
    SUM(received_date_id IS NULL) AS po_lines_without_received_date,
    SUM(promotion_id IS NULL) AS po_lines_without_promotion
FROM fact_purchase_orders;

/* 4. RANGE / DOMAIN CHECKS */
SELECT COUNT(*) AS invalid_sales_rows
FROM fact_sales
WHERE quantity <= 0
   OR regular_unit_price < 0
   OR net_unit_price < 0
   OR unit_cost < 0
   OR discount_amount < 0
   OR return_flag NOT IN (0,1);

SELECT COUNT(*) AS net_price_above_regular_price
FROM fact_sales
WHERE net_unit_price > regular_unit_price + 0.01;

SELECT COUNT(*) AS discount_reconciliation_issues
FROM fact_sales
WHERE ABS(discount_amount - (regular_unit_price - net_unit_price)) > 0.01;

SELECT COUNT(*) AS invalid_inventory_rows
FROM fact_inventory_snapshot
WHERE system_on_hand_qty < 0
   OR reorder_point_qty < 0
   OR safety_stock_qty < 0
   OR unit_cost_at_snapshot < 0;

SELECT COUNT(*) AS safety_stock_above_reorder_point
FROM fact_inventory_snapshot
WHERE safety_stock_qty > reorder_point_qty;

SELECT COUNT(*) AS invalid_po_quantities
FROM fact_purchase_orders
WHERE quantity_ordered <= 0
   OR quantity_received < 0
   OR quantity_received > quantity_ordered
   OR unit_purchase_cost < 0;

/* 5. DATE / STATUS CONSISTENCY */
SELECT COUNT(*) AS po_expected_before_order
FROM fact_purchase_orders po
JOIN dim_date od ON po.order_date_id = od.date_id
JOIN dim_date ed ON po.expected_delivery_date_id = ed.date_id
WHERE ed.full_date < od.full_date;

SELECT COUNT(*) AS po_received_before_order
FROM fact_purchase_orders po
JOIN dim_date od ON po.order_date_id = od.date_id
JOIN dim_date rd ON po.received_date_id = rd.date_id
WHERE rd.full_date < od.full_date;

SELECT COUNT(*) AS received_status_without_received_date
FROM fact_purchase_orders
WHERE order_status IN ('Received','Partially Received')
  AND received_date_id IS NULL;

SELECT COUNT(*) AS open_status_with_received_date
FROM fact_purchase_orders
WHERE order_status = 'Open'
  AND received_date_id IS NOT NULL;

SELECT COUNT(*) AS invalid_promotion_date_ranges
FROM dim_promotion p
JOIN dim_date s ON p.start_date_id = s.date_id
JOIN dim_date e ON p.end_date_id = e.date_id
WHERE e.full_date < s.full_date;

/* 6. REFERENTIAL-INTEGRITY AUDITS */
SELECT COUNT(*) AS orphan_sales_products
FROM fact_sales s
LEFT JOIN dim_product p ON s.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT COUNT(*) AS orphan_sales_stores
FROM fact_sales s
LEFT JOIN dim_store st ON s.store_id = st.store_id
WHERE st.store_id IS NULL;

SELECT COUNT(*) AS orphan_inventory_products
FROM fact_inventory_snapshot i
LEFT JOIN dim_product p ON i.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT COUNT(*) AS orphan_po_suppliers
FROM fact_purchase_orders po
LEFT JOIN dim_supplier s ON po.supplier_id = s.supplier_id
WHERE s.supplier_id IS NULL;

/* 7. BUSINESS-RULE CHECKS */
/* A promotional sales line should fall inside the linked promotion window. */
SELECT COUNT(*) AS promo_sales_outside_campaign_window
FROM fact_sales s
JOIN dim_date sd ON s.date_id = sd.date_id
JOIN dim_promotion p ON s.promotion_id = p.promotion_id
JOIN dim_date ps ON p.start_date_id = ps.date_id
JOIN dim_date pe ON p.end_date_id = pe.date_id
WHERE s.promotion_id IS NOT NULL
  AND sd.full_date NOT BETWEEN ps.full_date AND pe.full_date;

/* Non-promotion discounts are permitted only for markdown-eligible products. */
SELECT COUNT(*) AS unauthorized_nonpromo_markdowns
FROM fact_sales s
JOIN dim_product p ON s.product_id = p.product_id
WHERE s.promotion_id IS NULL
  AND s.discount_amount > 0
  AND p.markdown_eligible = 0;

/* Budget records must be tied to the first date of a month. */
SELECT COUNT(*) AS budget_rows_not_month_start
FROM fact_budget b
JOIN dim_date d ON b.month_start_date_id = d.date_id
WHERE d.day_of_month <> 1;

/* 8. GRAIN RECONCILIATION */
SELECT
    (SELECT COUNT(*) FROM dim_product) AS products,
    (SELECT COUNT(*) FROM dim_store) AS stores,
    (SELECT COUNT(*) FROM dim_date) AS dates,
    (SELECT COUNT(*) FROM fact_inventory_snapshot) AS inventory_rows,
    (SELECT COUNT(*) FROM dim_product)
      * (SELECT COUNT(*) FROM dim_store)
      * (SELECT COUNT(*) FROM dim_date) AS expected_inventory_rows;

SELECT
    (SELECT COUNT(*) FROM dim_store) AS stores,
    (SELECT COUNT(*) FROM dim_department) AS departments,
    24 AS months,
    (SELECT COUNT(*) FROM fact_budget) AS budget_rows,
    (SELECT COUNT(*) FROM dim_store)
      * (SELECT COUNT(*) FROM dim_department)
      * 24 AS expected_budget_rows;

/* 9. SINGLE-PASS QA SUMMARY — issue_count should be 0 for error tests. */
SELECT 'Duplicate inventory grain' test_name, COUNT(*) issue_count
FROM (
    SELECT date_id,store_id,product_id
    FROM fact_inventory_snapshot
    GROUP BY date_id,store_id,product_id
    HAVING COUNT(*) > 1
) x
UNION ALL
SELECT 'Invalid sales values', COUNT(*)
FROM fact_sales
WHERE quantity <= 0 OR regular_unit_price < 0 OR net_unit_price < 0 OR unit_cost < 0
UNION ALL
SELECT 'Price above regular price', COUNT(*)
FROM fact_sales
WHERE net_unit_price > regular_unit_price + 0.01
UNION ALL
SELECT 'Discount reconciliation', COUNT(*)
FROM fact_sales
WHERE ABS(discount_amount - (regular_unit_price-net_unit_price)) > 0.01
UNION ALL
SELECT 'Negative inventory values', COUNT(*)
FROM fact_inventory_snapshot
WHERE system_on_hand_qty < 0 OR reorder_point_qty < 0 OR safety_stock_qty < 0
UNION ALL
SELECT 'PO receipt above order', COUNT(*)
FROM fact_purchase_orders
WHERE quantity_received > quantity_ordered
UNION ALL
SELECT 'Promotion sales outside dates', COUNT(*)
FROM fact_sales s
JOIN dim_date sd ON s.date_id=sd.date_id
JOIN dim_promotion p ON s.promotion_id=p.promotion_id
JOIN dim_date ps ON p.start_date_id=ps.date_id
JOIN dim_date pe ON p.end_date_id=pe.date_id
WHERE s.promotion_id IS NOT NULL
  AND sd.full_date NOT BETWEEN ps.full_date AND pe.full_date
UNION ALL
SELECT 'Unauthorized nonpromo markdowns', COUNT(*)
FROM fact_sales s
JOIN dim_product p ON s.product_id=p.product_id
WHERE s.promotion_id IS NULL AND s.discount_amount>0 AND p.markdown_eligible=0;
