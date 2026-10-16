# Data Dictionary

| Table | Grain | Purpose |
|---|---|---|
| `dim_date` | One calendar date | Calendar attributes and time analysis |
| `dim_department` | One department | Retail department master |
| `dim_store` | One store | Store/location master |
| `dim_supplier` | One supplier | Supplier profile, lead time and ordering attributes |
| `dim_product` | One SKU | Product hierarchy and descriptive attributes |
| `dim_promotion` | One campaign | Promotion/event master |
| `fact_sales` | One SKU line within one transaction | Sales, price, cost, discounts and returns |
| `fact_inventory_snapshot` | One SKU × store × day | Daily system inventory position |
| `fact_inventory_count` | One physical count event | System vs physical inventory counts |
| `fact_inventory_adjustment` | One adjustment event | Spoilage, damage, expiry, shrink and corrections |
| `fact_purchase_orders` | One SKU line within one PO | Ordering, receipt and supplier history |
| `fact_budget` | One store × department × month | Revenue, unit, GP and shrink targets |
| `bridge_promotion_product_store` | One promotion × SKU × store | Planned promotional assortment/discount |
| `fact_promotion_spend` | One promotion spend entry | Campaign cost and vendor funding |

## Important fields

### fact_sales
- `sale_line_id`: PK for each sale line
- `transaction_id`: transaction grouping ID
- `date_id`, `store_id`, `product_id`, `promotion_id`: dimensional keys
- `quantity`: positive source quantity; returns use `return_flag=1`
- `regular_unit_price`: non-discounted unit price at transaction time
- `net_unit_price`: actual selling price per unit
- `unit_cost`: historical cost associated with the transaction
- `discount_amount`: per-unit regular price minus net price
- `return_flag`: 1 for return, 0 for sale

### fact_inventory_snapshot
- `system_on_hand_qty`: perpetual/system inventory at snapshot
- `reorder_point_qty`: replenishment trigger threshold
- `safety_stock_qty`: safety stock threshold
- `unit_cost_at_snapshot`: cost used for historical inventory valuation

### fact_inventory_count
- `system_qty_at_count`: system quantity at count time
- `physical_count_qty`: physically counted quantity
- Inventory variance is derived as `physical_count_qty - system_qty_at_count`

### fact_purchase_orders
- `expected_delivery_date_id` / `received_date_id`: expected vs actual receipt dates
- `quantity_ordered` / `quantity_received`: used for supplier fill rate
- `order_reason`: Low Stock, Promotion, Seasonal Demand, etc.

### fact_budget
Budget is stored at a different grain from sales: month × store × department. This is intentionally not forced to SKU-level granularity.

### Promotion baseline
Promotion performance uses the same promoted SKU/store combinations during the immediately preceding equal-duration period as the baseline. This is a transparent analytical proxy, not proof of causal incrementality.
