/* ============================================================
   HARBOUR FRESH MARKET
   File: 07_final_validation.sql
   Purpose: Confirm final portfolio views and headline metrics
   ============================================================ */

USE harbour_fresh_market;

SELECT 'vw_sales_enriched' object_name, COUNT(*) row_count FROM vw_sales_enriched
UNION ALL
SELECT 'vw_inventory_enriched', COUNT(*) FROM vw_inventory_enriched
UNION ALL
SELECT 'vw_supplier_performance', COUNT(*) FROM vw_supplier_performance
UNION ALL
SELECT 'vw_promotion_performance', COUNT(*) FROM vw_promotion_performance;

SELECT
    ROUND(SUM(revenue),2) total_revenue,
    ROUND(SUM(gross_profit),2) total_gross_profit,
    ROUND(100*SUM(gross_profit)/NULLIF(SUM(revenue),0),2) gross_margin_pct,
    SUM(net_units) net_units
FROM vw_sales_enriched;
