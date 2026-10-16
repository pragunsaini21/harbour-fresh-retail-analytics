/* ============================================================
   HARBOUR FRESH MARKET
   Retail Revenue & Inventory Analytics Project

   File: 01_database_setup.sql
   Purpose: Create database, dimensions, facts and relationships
   ============================================================ */


/* ============================================================
   1. CREATE DATABASE
   ============================================================ */



CREATE DATABASE harbour_fresh_market;

USE harbour_fresh_market;


/* ============================================================
   2. DIMENSION TABLES
   ============================================================ */


/* ------------------------------------------------------------
   dim_date
   Grain: One row per calendar date
   ------------------------------------------------------------ */

CREATE TABLE dim_date (
    date_id INT PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    day_of_week VARCHAR(10) NOT NULL,
    day_of_month TINYINT NOT NULL,
    week_number TINYINT NOT NULL,
    month_number TINYINT NOT NULL,
    month_name VARCHAR(10) NOT NULL,
    quarter TINYINT NOT NULL,
    year SMALLINT NOT NULL,
    is_weekend BOOLEAN NOT NULL,
    season VARCHAR(10) NOT NULL
);


/* ------------------------------------------------------------
   dim_department
   Grain: One row per department
   ------------------------------------------------------------ */

CREATE TABLE dim_department (
    department_id INT AUTO_INCREMENT PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL UNIQUE
);


/* ------------------------------------------------------------
   dim_store
   Grain: One row per store
   ------------------------------------------------------------ */

CREATE TABLE dim_store (
    store_id INT AUTO_INCREMENT PRIMARY KEY,
    store_name VARCHAR(100) NOT NULL UNIQUE,
    city VARCHAR(100) NOT NULL,
    province CHAR(2) NOT NULL,
    store_format VARCHAR(50) NOT NULL,
    opening_date DATE
);


/* ------------------------------------------------------------
   dim_supplier
   Grain: One row per supplier
   ------------------------------------------------------------ */

CREATE TABLE dim_supplier (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_name VARCHAR(150) NOT NULL,
    supplier_type VARCHAR(50),
    city VARCHAR(100),
    province CHAR(2),
    lead_time_days INT,
    minimum_order_qty INT,
    delivery_schedule VARCHAR(50),

    CHECK (
        lead_time_days IS NULL
        OR lead_time_days >= 0
    ),

    CHECK (
        minimum_order_qty IS NULL
        OR minimum_order_qty >= 0
    )
);


/* ------------------------------------------------------------
   dim_product
   Grain: One row per SKU/product
   ------------------------------------------------------------ */

CREATE TABLE dim_product (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    sku_number VARCHAR(30) NOT NULL UNIQUE,
    product_name VARCHAR(150) NOT NULL,
    department_id INT NOT NULL,
    category VARCHAR(100) NOT NULL,
    subcategory VARCHAR(100),
    brand VARCHAR(100),
    package_size VARCHAR(50),
    unit_of_measure VARCHAR(20),
    private_label_flag BOOLEAN NOT NULL DEFAULT FALSE,
    storage_type VARCHAR(30) NOT NULL,
    markdown_eligible BOOLEAN NOT NULL DEFAULT FALSE,
    shelf_life_days INT,

    CONSTRAINT fk_product_department
        FOREIGN KEY (department_id)
        REFERENCES dim_department(department_id),

    CHECK (
        shelf_life_days IS NULL
        OR shelf_life_days >= 0
    )
);


/* ------------------------------------------------------------
   dim_promotion
   Grain: One row per promotional campaign/event
   ------------------------------------------------------------ */

CREATE TABLE dim_promotion (
    promotion_id INT AUTO_INCREMENT PRIMARY KEY,
    promotion_name VARCHAR(150) NOT NULL,
    promotion_type VARCHAR(50) NOT NULL,
    occasion VARCHAR(100),
    start_date_id INT NOT NULL,
    end_date_id INT NOT NULL,

    CONSTRAINT fk_promotion_start_date
        FOREIGN KEY (start_date_id)
        REFERENCES dim_date(date_id),

    CONSTRAINT fk_promotion_end_date
        FOREIGN KEY (end_date_id)
        REFERENCES dim_date(date_id)
);


/* ============================================================
   3. FACT TABLES
   ============================================================ */


/* ------------------------------------------------------------
   fact_sales
   Grain: One product line within one customer transaction
   ------------------------------------------------------------ */

CREATE TABLE fact_sales (
    sale_line_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    transaction_id BIGINT NOT NULL,
    date_id INT NOT NULL,
    transaction_time TIME NOT NULL,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    promotion_id INT,
    quantity INT NOT NULL,
    regular_unit_price DECIMAL(10,2) NOT NULL,
    net_unit_price DECIMAL(10,2) NOT NULL,
    unit_cost DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    return_flag BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT fk_sales_date
        FOREIGN KEY (date_id)
        REFERENCES dim_date(date_id),

    CONSTRAINT fk_sales_store
        FOREIGN KEY (store_id)
        REFERENCES dim_store(store_id),

    CONSTRAINT fk_sales_product
        FOREIGN KEY (product_id)
        REFERENCES dim_product(product_id),

    CONSTRAINT fk_sales_promotion
        FOREIGN KEY (promotion_id)
        REFERENCES dim_promotion(promotion_id),

    CHECK (quantity > 0),
    CHECK (regular_unit_price >= 0),
    CHECK (net_unit_price >= 0),
    CHECK (unit_cost >= 0),
    CHECK (discount_amount >= 0)
);


/* ------------------------------------------------------------
   fact_inventory_snapshot
   Grain: One product × one store × one day
   ------------------------------------------------------------ */

CREATE TABLE fact_inventory_snapshot (
    inventory_snapshot_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    date_id INT NOT NULL,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    system_on_hand_qty INT NOT NULL,
    reorder_point_qty INT NOT NULL,
    safety_stock_qty INT NOT NULL,
    unit_cost_at_snapshot DECIMAL(10,2) NOT NULL,

    CONSTRAINT fk_inventory_date
        FOREIGN KEY (date_id)
        REFERENCES dim_date(date_id),

    CONSTRAINT fk_inventory_store
        FOREIGN KEY (store_id)
        REFERENCES dim_store(store_id),

    CONSTRAINT fk_inventory_product
        FOREIGN KEY (product_id)
        REFERENCES dim_product(product_id),

    CONSTRAINT uq_inventory_snapshot
        UNIQUE (date_id, store_id, product_id),

    CHECK (system_on_hand_qty >= 0),
    CHECK (reorder_point_qty >= 0),
    CHECK (safety_stock_qty >= 0),
    CHECK (unit_cost_at_snapshot >= 0)
);


/* ------------------------------------------------------------
   fact_inventory_count
   Grain: One physical inventory count event for one SKU/store
   ------------------------------------------------------------ */

CREATE TABLE fact_inventory_count (
    count_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    date_id INT NOT NULL,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    system_qty_at_count INT NOT NULL,
    physical_count_qty INT NOT NULL,
    count_type VARCHAR(50) NOT NULL,

    CONSTRAINT fk_count_date
        FOREIGN KEY (date_id)
        REFERENCES dim_date(date_id),

    CONSTRAINT fk_count_store
        FOREIGN KEY (store_id)
        REFERENCES dim_store(store_id),

    CONSTRAINT fk_count_product
        FOREIGN KEY (product_id)
        REFERENCES dim_product(product_id),

    CHECK (system_qty_at_count >= 0),
    CHECK (physical_count_qty >= 0)
);


/* ------------------------------------------------------------
   fact_inventory_adjustment
   Grain: One inventory adjustment event
   ------------------------------------------------------------ */

CREATE TABLE fact_inventory_adjustment (
    adjustment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    date_id INT NOT NULL,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    adjustment_reason VARCHAR(50) NOT NULL,
    quantity_adjusted INT NOT NULL,
    unit_cost DECIMAL(10,2) NOT NULL,

    CONSTRAINT fk_adjustment_date
        FOREIGN KEY (date_id)
        REFERENCES dim_date(date_id),

    CONSTRAINT fk_adjustment_store
        FOREIGN KEY (store_id)
        REFERENCES dim_store(store_id),

    CONSTRAINT fk_adjustment_product
        FOREIGN KEY (product_id)
        REFERENCES dim_product(product_id),

    CHECK (unit_cost >= 0)
);


/* ------------------------------------------------------------
   fact_purchase_orders
   Grain: One product line within one purchase order
   ------------------------------------------------------------ */

CREATE TABLE fact_purchase_orders (
    purchase_order_line_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    purchase_order_id BIGINT NOT NULL,
    order_date_id INT NOT NULL,
    expected_delivery_date_id INT NOT NULL,
    received_date_id INT,
    store_id INT NOT NULL,
    supplier_id INT NOT NULL,
    product_id INT NOT NULL,
    promotion_id INT,
    quantity_ordered INT NOT NULL,
    quantity_received INT NOT NULL DEFAULT 0,
    unit_purchase_cost DECIMAL(10,2) NOT NULL,
    order_status VARCHAR(30) NOT NULL,
    order_reason VARCHAR(50) NOT NULL,

    CONSTRAINT fk_po_order_date
        FOREIGN KEY (order_date_id)
        REFERENCES dim_date(date_id),

    CONSTRAINT fk_po_expected_date
        FOREIGN KEY (expected_delivery_date_id)
        REFERENCES dim_date(date_id),

    CONSTRAINT fk_po_received_date
        FOREIGN KEY (received_date_id)
        REFERENCES dim_date(date_id),

    CONSTRAINT fk_po_store
        FOREIGN KEY (store_id)
        REFERENCES dim_store(store_id),

    CONSTRAINT fk_po_supplier
        FOREIGN KEY (supplier_id)
        REFERENCES dim_supplier(supplier_id),

    CONSTRAINT fk_po_product
        FOREIGN KEY (product_id)
        REFERENCES dim_product(product_id),

    CONSTRAINT fk_po_promotion
        FOREIGN KEY (promotion_id)
        REFERENCES dim_promotion(promotion_id),

    CHECK (quantity_ordered > 0),
    CHECK (quantity_received >= 0),
    CHECK (unit_purchase_cost >= 0)
);


/* ------------------------------------------------------------
   fact_budget
   Grain: One store × one department × one month
   ------------------------------------------------------------ */

CREATE TABLE fact_budget (
    budget_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    month_start_date_id INT NOT NULL,
    store_id INT NOT NULL,
    department_id INT NOT NULL,
    budget_revenue DECIMAL(14,2) NOT NULL,
    budget_units INT NOT NULL,
    budget_gross_profit DECIMAL(14,2) NOT NULL,
    budget_shrink_amount DECIMAL(14,2) NOT NULL,
    budget_controllable_contribution DECIMAL(14,2),

    CONSTRAINT fk_budget_date
        FOREIGN KEY (month_start_date_id)
        REFERENCES dim_date(date_id),

    CONSTRAINT fk_budget_store
        FOREIGN KEY (store_id)
        REFERENCES dim_store(store_id),

    CONSTRAINT fk_budget_department
        FOREIGN KEY (department_id)
        REFERENCES dim_department(department_id),

    CONSTRAINT uq_budget
        UNIQUE (
            month_start_date_id,
            store_id,
            department_id
        ),

    CHECK (budget_revenue >= 0),
    CHECK (budget_units >= 0),
    CHECK (budget_gross_profit >= 0),
    CHECK (budget_shrink_amount >= 0)
);


/* ============================================================
   4. PROMOTION BRIDGE
   ============================================================ */


/* ------------------------------------------------------------
   bridge_promotion_product_store
   Grain: One promotion × one product × one store
   ------------------------------------------------------------ */

CREATE TABLE bridge_promotion_product_store (
    promotion_id INT NOT NULL,
    product_id INT NOT NULL,
    store_id INT NOT NULL,
    planned_discount_type VARCHAR(30) NOT NULL,
    planned_discount_value DECIMAL(10,2) NOT NULL,

    PRIMARY KEY (
        promotion_id,
        product_id,
        store_id
    ),

    CONSTRAINT fk_bridge_promotion
        FOREIGN KEY (promotion_id)
        REFERENCES dim_promotion(promotion_id),

    CONSTRAINT fk_bridge_product
        FOREIGN KEY (product_id)
        REFERENCES dim_product(product_id),

    CONSTRAINT fk_bridge_store
        FOREIGN KEY (store_id)
        REFERENCES dim_store(store_id),

    CHECK (planned_discount_value >= 0)
);


/* ============================================================
   5. PROMOTION SPEND FACT
   ============================================================ */


/* ------------------------------------------------------------
   fact_promotion_spend
   Grain: One promotional spend entry
   ------------------------------------------------------------ */

CREATE TABLE fact_promotion_spend (
    promotion_spend_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    promotion_id INT NOT NULL,
    store_id INT NOT NULL,
    spend_date_id INT NOT NULL,
    spend_type VARCHAR(50) NOT NULL,
    spend_amount DECIMAL(12,2) NOT NULL,
    vendor_funded_amount DECIMAL(12,2) NOT NULL DEFAULT 0,

    CONSTRAINT fk_spend_promotion
        FOREIGN KEY (promotion_id)
        REFERENCES dim_promotion(promotion_id),

    CONSTRAINT fk_spend_store
        FOREIGN KEY (store_id)
        REFERENCES dim_store(store_id),

    CONSTRAINT fk_spend_date
        FOREIGN KEY (spend_date_id)
        REFERENCES dim_date(date_id),

    CHECK (spend_amount >= 0),
    CHECK (vendor_funded_amount >= 0)
);


/* ============================================================
   6. VERIFY DATABASE
   ============================================================ */

SELECT DATABASE();

SHOW TABLES;

DESCRIBE fact_sales;

DESCRIBE fact_purchase_orders;