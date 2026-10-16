# Harbour Fresh Market — Dataset

This folder contains the source data used in the Harbour Fresh Market Retail Revenue & Inventory Analytics project.

All data in this project is **synthetic** and was created specifically for portfolio and learning purposes.

No confidential, proprietary, or real customer information is included.

---

## Dataset Scope

The dataset simulates retail operations from:

**January 1, 2024 through December 31, 2025**

It contains:

- 4 retail stores
- 12 departments
- 360 products
- 24 suppliers
- 16 promotional campaigns
- 426,000+ sales transaction lines
- 1,052,000+ daily inventory snapshots
- 31,000+ purchase-order lines

---

## Raw Data

All original source files are stored in:

```text
data/raw/
```

The raw CSV files should remain unchanged.

Data cleaning, NULL handling, validation, and analytical transformations are performed through SQL rather than by manually editing the original CSV files.

---

## Source Files

### Dimensions

#### `dim_date.csv`

Calendar dimension covering every date from January 2024 through December 2025.

Includes attributes such as:

- Date
- Day of week
- Month
- Quarter
- Year
- Weekend flag
- Season

#### `dim_department.csv`

Contains the retail department master list.

Grain:

**One row per department**

#### `dim_store.csv`

Contains store-level descriptive information.

Grain:

**One row per store**

#### `dim_supplier.csv`

Contains supplier information including:

- Supplier name
- Supplier type
- Location
- Lead time
- Minimum order quantity
- Delivery schedule

Grain:

**One row per supplier**

#### `dim_product.csv`

Contains product/SKU-level descriptive attributes including:

- SKU number
- Product name
- Department
- Category
- Subcategory
- Brand
- Package size
- Storage type
- Private-label flag
- Markdown eligibility
- Shelf life

Grain:

**One row per product/SKU**

#### `dim_promotion.csv`

Contains promotion/event information.

Grain:

**One row per promotional campaign**

---

## Fact Tables

### `fact_sales.csv`

Contains product-level sales transaction lines.

Grain:

**One product line within one customer transaction**

Key fields include:

- Transaction ID
- Date
- Store
- Product
- Promotion
- Quantity
- Regular selling price
- Net selling price
- Unit cost
- Discount
- Return flag

### `fact_inventory_snapshot.csv`

Contains daily inventory positions.

Grain:

**One product × one store × one day**

Key fields include:

- System on-hand quantity
- Reorder point
- Safety stock
- Unit cost

### `fact_inventory_count.csv`

Contains physical inventory-count events.

Grain:

**One product count event at one store**

Used to compare:

- System inventory
- Physical inventory

Inventory variance should not automatically be interpreted as shrink.

### `fact_inventory_adjustment.csv`

Contains documented inventory adjustments.

Examples include:

- Spoilage
- Damage
- Expired product
- Theft / shrink
- Receiving corrections
- Count corrections

Grain:

**One inventory-adjustment event**

### `fact_purchase_orders.csv`

Contains purchase-order product lines.

Grain:

**One product line within one purchase order**

Key fields include:

- Supplier
- Store
- Product
- Order date
- Expected delivery date
- Received date
- Quantity ordered
- Quantity received
- Purchase cost
- Order status
- Order reason

### `fact_budget.csv`

Contains monthly financial and operational targets.

Grain:

**One store × one department × one month**

Includes:

- Budget revenue
- Budget units
- Budget gross profit
- Budget shrink
- Budget controllable contribution

The controllable-contribution metric used in this synthetic project is a simplified project-specific measure and should not be interpreted as a universal retail-finance definition.

### `fact_promotion_spend.csv`

Contains promotional investment information.

Includes:

- Promotion
- Store
- Spend date
- Spend type
- Spend amount
- Vendor-funded amount

---

## Bridge Table

### `bridge_promotion_product_store.csv`

Maps planned promotional participation.

Grain:

**One promotion × one product × one store**

This table allows the analysis to distinguish between:

- A product that was not included in a promotion
- A product that was promoted but generated no sales

---

## Data Loading

The source CSV files are loaded into MySQL using:

```text
sql/02_data_load.sql
```

The loading process includes explicit NULL handling using `NULLIF()` where appropriate.

---

## Data Quality

Validation is performed through:

```text
sql/03_data_quality.sql
```

Checks include:

- Row-count reconciliation
- Duplicate detection
- Grain validation
- Required-field NULL checks
- Numeric range validation
- Foreign-key integrity
- Business-rule validation
- Date coverage

---

## Important Note

The files in `data/raw/` are treated as the project's source-of-truth data.

They should not be manually modified to resolve analytical or ingestion issues.

Any required handling should instead be documented and implemented through the SQL ingestion or transformation process.
