/* ============================================================
   HARBOUR FRESH MARKET
   File: 06_promotion_supplier.sql
   Purpose: Supplier reliability and promotion effectiveness
   ============================================================ */

USE harbour_fresh_market;

/* 1. Supplier service scorecard */
CREATE OR REPLACE VIEW vw_supplier_performance AS
SELECT
    po.supplier_id, s.supplier_name,
    COUNT(*) po_lines,
    SUM(po.quantity_ordered) units_ordered,
    SUM(po.quantity_received) units_received,
    SUM(po.quantity_received)/NULLIF(SUM(po.quantity_ordered),0) fill_rate,
    AVG(CASE WHEN po.received_date_id IS NOT NULL AND rd.full_date>ed.full_date THEN 1 ELSE 0 END) late_delivery_rate,
    AVG(CASE WHEN po.received_date_id IS NOT NULL THEN DATEDIFF(rd.full_date,ed.full_date) END) avg_days_vs_expected
FROM fact_purchase_orders po
JOIN dim_supplier s ON po.supplier_id=s.supplier_id
JOIN dim_date ed ON po.expected_delivery_date_id=ed.date_id
LEFT JOIN dim_date rd ON po.received_date_id=rd.date_id
GROUP BY po.supplier_id,s.supplier_name;

SELECT
    supplier_name,po_lines,units_ordered,units_received,
    ROUND(100*fill_rate,2) fill_rate_pct,
    ROUND(100*late_delivery_rate,2) late_delivery_rate_pct,
    ROUND(avg_days_vs_expected,2) avg_days_vs_expected
FROM vw_supplier_performance
ORDER BY fill_rate,late_delivery_rate DESC;

/* 2. Replenishment orders by reason */
SELECT
    order_reason,
    COUNT(*) po_lines,
    SUM(quantity_ordered) units_ordered,
    SUM(quantity_received) units_received,
    ROUND(100*SUM(quantity_received)/NULLIF(SUM(quantity_ordered),0),2) fill_rate_pct
FROM fact_purchase_orders
GROUP BY order_reason
ORDER BY po_lines DESC;

/* 3. Promotion performance.
   Baseline = immediately preceding period of equal duration.
   This is directional, not a causal experiment. */
CREATE OR REPLACE VIEW vw_promotion_performance AS
WITH scope AS (
    SELECT
        b.promotion_id,b.store_id,b.product_id,
        p.promotion_name,p.promotion_type,p.occasion,
        sd.full_date start_date,ed.full_date end_date,
        DATEDIFF(ed.full_date,sd.full_date)+1 duration_days
    FROM bridge_promotion_product_store b
    JOIN dim_promotion p ON b.promotion_id=p.promotion_id
    JOIN dim_date sd ON p.start_date_id=sd.date_id
    JOIN dim_date ed ON p.end_date_id=ed.date_id
), promo AS (
    SELECT promotion_id,store_id,product_id,
           SUM(net_units) promo_units,
           SUM(revenue) promo_revenue,
           SUM(gross_profit) promo_gp
    FROM vw_sales_enriched
    WHERE promotion_id IS NOT NULL
    GROUP BY promotion_id,store_id,product_id
), baseline AS (
    SELECT
        s.promotion_id,s.store_id,s.product_id,
        COALESCE(SUM(v.net_units),0) baseline_units,
        COALESCE(SUM(v.revenue),0) baseline_revenue,
        COALESCE(SUM(v.gross_profit),0) baseline_gp
    FROM scope s
    LEFT JOIN vw_sales_enriched v
      ON v.store_id=s.store_id
     AND v.product_id=s.product_id
     AND v.full_date BETWEEN DATE_SUB(s.start_date, INTERVAL s.duration_days DAY)
                         AND DATE_SUB(s.start_date, INTERVAL 1 DAY)
    GROUP BY s.promotion_id,s.store_id,s.product_id
), campaign AS (
    SELECT
        s.promotion_id,MAX(s.promotion_name) promotion_name,
        MIN(s.start_date) start_date,MAX(s.end_date) end_date,
        SUM(COALESCE(p.promo_units,0)) promo_units,
        SUM(COALESCE(p.promo_revenue,0)) promo_revenue,
        SUM(COALESCE(p.promo_gp,0)) promo_gp,
        SUM(COALESCE(b.baseline_units,0)) baseline_units,
        SUM(COALESCE(b.baseline_gp,0)) baseline_gp
    FROM scope s
    LEFT JOIN promo p
      ON s.promotion_id=p.promotion_id AND s.store_id=p.store_id AND s.product_id=p.product_id
    LEFT JOIN baseline b
      ON s.promotion_id=b.promotion_id AND s.store_id=b.store_id AND s.product_id=b.product_id
    GROUP BY s.promotion_id
), spend AS (
    SELECT promotion_id,
           SUM(spend_amount-vendor_funded_amount) net_promo_spend
    FROM fact_promotion_spend
    GROUP BY promotion_id
), stock AS (
    SELECT
        s.promotion_id,
        AVG(CASE WHEN i.system_on_hand_qty=0 THEN 1 ELSE 0 END) stockout_rate
    FROM scope s
    JOIN fact_inventory_snapshot i
      ON s.store_id=i.store_id
     AND s.product_id=i.product_id
     AND i.date_id BETWEEN CAST(DATE_FORMAT(s.start_date,'%Y%m%d') AS UNSIGNED)
                       AND CAST(DATE_FORMAT(s.end_date,'%Y%m%d') AS UNSIGNED)
    GROUP BY s.promotion_id
)
SELECT
    c.promotion_id,c.promotion_name,c.start_date,c.end_date,
    c.promo_units,c.baseline_units,
    (c.promo_units-c.baseline_units)/NULLIF(c.baseline_units,0) unit_lift,
    c.promo_revenue,c.promo_gp,
    c.promo_gp-c.baseline_gp incremental_gp,
    s.net_promo_spend,
    (c.promo_gp-c.baseline_gp)/NULLIF(s.net_promo_spend,0) promo_roi,
    st.stockout_rate
FROM campaign c
LEFT JOIN spend s ON c.promotion_id=s.promotion_id
LEFT JOIN stock st ON c.promotion_id=st.promotion_id;

/* 4. Promotion scorecard */
SELECT
    promotion_name,start_date,end_date,
    ROUND(promo_revenue,2) promo_revenue,
    ROUND(100*unit_lift,1) unit_lift_pct,
    ROUND(incremental_gp,2) incremental_gp,
    ROUND(net_promo_spend,2) net_promo_spend,
    ROUND(promo_roi,2) promo_roi,
    ROUND(100*stockout_rate,2) stockout_rate_pct
FROM vw_promotion_performance
ORDER BY promo_roi;

/* 5. High-lift but economically weak promotions */
SELECT
    promotion_name,
    ROUND(100*unit_lift,1) unit_lift_pct,
    ROUND(incremental_gp,2) incremental_gp,
    ROUND(promo_roi,2) promo_roi
FROM vw_promotion_performance
WHERE unit_lift>0 AND promo_roi<0
ORDER BY unit_lift DESC;
