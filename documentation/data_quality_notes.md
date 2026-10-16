# Data Quality & Ingestion Notes

## Source-to-target validation incident
During the initial CSV ingestion, `dim_product` loaded **352 rows instead of the expected 360**. The missing records contained legitimate blank `shelf_life_days` values for selected non-perishable items. The import tool did not correctly translate those blanks to SQL `NULL`.

Because `bridge_promotion_product_store` contains foreign keys to `dim_product`, dependent rows also failed to load, producing **2,316 bridge rows instead of 2,352**.

## Resolution
1. Reconciled source and target row counts.
2. Isolated the missing product IDs.
3. Confirmed blank optional shelf-life values as the common cause.
4. Updated the ingestion logic to stage optional fields in MySQL user variables and apply `NULLIF(value, '')`.
5. Reloaded the product dimension and dependent bridge table.
6. Revalidated row counts and referential integrity.

## Why this matters
This demonstrates that an "import successful" message is not sufficient validation. The project uses explicit source-to-target row counts, grain checks, NULL checks, domain checks, foreign-key audits and business-rule tests before business analysis.
