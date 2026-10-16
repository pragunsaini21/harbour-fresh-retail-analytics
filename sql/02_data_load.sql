/* ============================================================
   HARBOUR FRESH MARKET
   Retail Revenue & Inventory Analytics Project

   File: 02_data_load.sql
   Purpose: Load synthetic CSV data into MySQL tables
   ============================================================ */

USE harbour_fresh_market;


/* ============================================================
   IMPORTANT
   ------------------------------------------------------------
   This script assumes:
   1. 01_database_setup.sql has already been executed.
   2. Tables are empty.
   3. local_infile is enabled.
   4. CSV files are stored in the data/raw folder.

   Change the file path if the project folder moves.
   ============================================================ */


/* ============================================================
   1. DATE DIMENSION
   ============================================================ */

LOAD DATA LOCAL INFILE
'C:/Users/pragu/Desktop/HARBOUR FRESH RETAIL ANALYTICS/Documents/data/raw/dim_date.csv'
INTO TABLE dim_date
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    date_id,
    full_date,
    day_of_week,
    day_of_month,
    week_number,
    month_number,
    month_name,
    quarter,
    year,
    is_weekend,
    season
);


/* ============================================================
   2. DEPARTMENT DIMENSION
   ============================================================ */

LOAD DATA LOCAL INFILE
'C:/Users/pragu/Desktop/HARBOUR FRESH RETAIL ANALYTICS/Documents/data/raw/dim_department.csv'
INTO TABLE dim_department
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    department_id,
    department_name
);


/* ============================================================
   3. STORE DIMENSION
   ============================================================ */

LOAD DATA LOCAL INFILE
'C:/Users/pragu/Desktop/HARBOUR FRESH RETAIL ANALYTICS/Documents/data/raw/dim_store.csv'
INTO TABLE dim_store
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    store_id,
    store_name,
    city,
    province,
    store_format,
    opening_date
);


/* ============================================================
   4. SUPPLIER DIMENSION
   ============================================================ */

LOAD DATA LOCAL INFILE
'C:/Users/pragu/Desktop/HARBOUR FRESH RETAIL ANALYTICS/Documents/data/raw/dim_supplier.csv'
INTO TABLE dim_supplier
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    supplier_id,
    supplier_name,
    supplier_type,
    @city,
    province,
    lead_time_days,
    minimum_order_qty,
    delivery_schedule
)
SET
    city = NULLIF(@city, '');


/* ============================================================
   5. PRODUCT DIMENSION
   ============================================================ */

/*
   NULLIF() is important here.

   During the first manual import, blank shelf_life_days values
   caused 8 valid product rows to fail. That reduced dim_product
   from 360 to 352 rows and subsequently caused dependent
   promotion-bridge records to fail FK validation.

   Loading blank values as SQL NULL prevents that issue.
*/

LOAD DATA LOCAL INFILE
'C:/Users/pragu/Desktop/HARBOUR FRESH RETAIL ANALYTICS/Documents/data/raw/dim_product.csv'
INTO TABLE dim_product
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    product_id,
    sku_number,
    product_name,
    department_id,
    category,
    @subcategory,
    @brand,
    @package_size,
    @unit_of_measure,
    private_label_flag,
    storage_type,
    markdown_eligible,
    @shelf_life_days
)
SET
    subcategory = NULLIF(@subcategory, ''),
    brand = NULLIF(@brand, ''),
    package_size = NULLIF(@package_size, ''),
    unit_of_measure = NULLIF(@unit_of_measure, ''),
    shelf_life_days = NULLIF(@shelf_life_days, '');


/* ============================================================
   6. PROMOTION DIMENSION
   ============================================================ */

LOAD DATA LOCAL INFILE
'C:/Users/pragu/Desktop/HARBOUR FRESH RETAIL ANALYTICS/Documents/data/raw/dim_promotion.csv'
INTO TABLE dim_promotion
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    promotion_id,
    promotion_name,
    promotion_type,
    @occasion,
    start_date_id,
    end_date_id
)
SET
    occasion = NULLIF(@occasion, '');


/* ============================================================
   7. PROMOTION / PRODUCT / STORE BRIDGE
   ============================================================ */

LOAD DATA LOCAL INFILE
'C:/Users/pragu/Desktop/HARBOUR FRESH RETAIL ANALYTICS/Documents/data/raw/bridge_promotion_product_store.csv'
INTO TABLE bridge_promotion_product_store
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    promotion_id,
    product_id,
    store_id,
    planned_discount_type,
    planned_discount_value
);


/* ============================================================
   8. BUDGET FACT
   ============================================================ */

LOAD DATA LOCAL INFILE
'C:/Users/pragu/Desktop/HARBOUR FRESH RETAIL ANALYTICS/Documents/data/raw/fact_budget.csv'
INTO TABLE fact_budget
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    budget_id,
    month_start_date_id,
    store_id,
    department_id,
    budget_revenue,
    budget_units,
    budget_gross_profit,
    budget_shrink_amount,
    @budget_controllable_contribution
)
SET
    budget_controllable_contribution =
        NULLIF(@budget_controllable_contribution, '');


/* ============================================================
   9. PURCHASE ORDERS
   ============================================================ */

LOAD DATA LOCAL INFILE
'C:/Users/pragu/Desktop/HARBOUR FRESH RETAIL ANALYTICS/Documents/data/raw/fact_purchase_orders.csv'
INTO TABLE fact_purchase_orders
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    purchase_order_line_id,
    purchase_order_id,
    order_date_id,
    expected_delivery_date_id,
    @received_date_id,
    store_id,
    supplier_id,
    product_id,
    @promotion_id,
    quantity_ordered,
    quantity_received,
    unit_purchase_cost,
    order_status,
    order_reason
)
SET
    received_date_id = NULLIF(@received_date_id, ''),
    promotion_id = NULLIF(@promotion_id, '');


/* ============================================================
   10. INVENTORY SNAPSHOTS
   ============================================================ */

LOAD DATA LOCAL INFILE
'C:/Users/pragu/Desktop/HARBOUR FRESH RETAIL ANALYTICS/Documents/data/raw/fact_inventory_snapshot.csv'
INTO TABLE fact_inventory_snapshot
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    inventory_snapshot_id,
    date_id,
    store_id,
    product_id,
    system_on_hand_qty,
    reorder_point_qty,
    safety_stock_qty,
    unit_cost_at_snapshot
);


/* ============================================================
   11. PHYSICAL INVENTORY COUNTS
   ============================================================ */

LOAD DATA LOCAL INFILE
'C:/Users/pragu/Desktop/HARBOUR FRESH RETAIL ANALYTICS/Documents/data/raw/fact_inventory_count.csv'
INTO TABLE fact_inventory_count
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    count_id,
    date_id,
    store_id,
    product_id,
    system_qty_at_count,
    physical_count_qty,
    count_type
);


/* ============================================================
   12. INVENTORY ADJUSTMENTS
   ============================================================ */

LOAD DATA LOCAL INFILE
'C:/Users/pragu/Desktop/HARBOUR FRESH RETAIL ANALYTICS/Documents/data/raw/fact_inventory_adjustment.csv'
INTO TABLE fact_inventory_adjustment
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    adjustment_id,
    date_id,
    store_id,
    product_id,
    adjustment_reason,
    quantity_adjusted,
    unit_cost
);


/* ============================================================
   13. PROMOTION SPEND
   ============================================================ */

LOAD DATA LOCAL INFILE
'C:/Users/pragu/Desktop/HARBOUR FRESH RETAIL ANALYTICS/Documents/data/raw/fact_promotion_spend.csv'
INTO TABLE fact_promotion_spend
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    promotion_spend_id,
    promotion_id,
    store_id,
    spend_date_id,
    spend_type,
    spend_amount,
    vendor_funded_amount
);


/* ============================================================
   14. SALES FACT
   ============================================================ */

LOAD DATA LOCAL INFILE
'C:/Users/pragu/Desktop/HARBOUR FRESH RETAIL ANALYTICS/Documents/data/raw/fact_sales.csv'
INTO TABLE fact_sales
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    sale_line_id,
    transaction_id,
    date_id,
    transaction_time,
    store_id,
    product_id,
    @promotion_id,
    quantity,
    regular_unit_price,
    net_unit_price,
    unit_cost,
    discount_amount,
    return_flag
)
SET
    promotion_id = NULLIF(@promotion_id, '');


/* ============================================================
   15. SOURCE-TO-TARGET ROW COUNT VALIDATION
   ============================================================ */

SELECT 'dim_date' AS table_name, COUNT(*) AS row_count
FROM dim_date

UNION ALL
SELECT 'dim_department', COUNT(*)
FROM dim_department

UNION ALL
SELECT 'dim_store', COUNT(*)
FROM dim_store

UNION ALL
SELECT 'dim_supplier', COUNT(*)
FROM dim_supplier

UNION ALL
SELECT 'dim_product', COUNT(*)
FROM dim_product

UNION ALL
SELECT 'dim_promotion', COUNT(*)
FROM dim_promotion

UNION ALL
SELECT 'bridge_promotion_product_store', COUNT(*)
FROM bridge_promotion_product_store

UNION ALL
SELECT 'fact_budget', COUNT(*)
FROM fact_budget

UNION ALL
SELECT 'fact_purchase_orders', COUNT(*)
FROM fact_purchase_orders

UNION ALL
SELECT 'fact_inventory_snapshot', COUNT(*)
FROM fact_inventory_snapshot

UNION ALL
SELECT 'fact_inventory_count', COUNT(*)
FROM fact_inventory_count

UNION ALL
SELECT 'fact_inventory_adjustment', COUNT(*)
FROM fact_inventory_adjustment

UNION ALL
SELECT 'fact_promotion_spend', COUNT(*)
FROM fact_promotion_spend

UNION ALL
SELECT 'fact_sales', COUNT(*)
FROM fact_sales;


/* ============================================================
   EXPECTED ROW COUNTS

   dim_date                         731
   dim_department                    12
   dim_store                          4
   dim_supplier                      24
   dim_product                      360
   dim_promotion                     16
   bridge_promotion_product_store  2352
   fact_budget                     1152
   fact_purchase_orders           31381
   fact_inventory_snapshot      1052640
   fact_inventory_count            2688
   fact_inventory_adjustment       4371
   fact_promotion_spend              192
   fact_sales                    426471
   ============================================================ */