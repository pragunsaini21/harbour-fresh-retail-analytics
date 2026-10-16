# Harbour Fresh Market — Business Requirements

## Business context
Harbour Fresh Market is a fictional Canadian multi-store grocery retailer. Leadership has seen revenue growth, but wants to understand whether that growth is translating into healthy profitability and inventory performance.

This portfolio project uses **fully synthetic data**. It does not contain Farm Boy, Canadian Tire, or any other employer's proprietary information.

## Stakeholders
- VP Operations — overall performance, risks and actions
- Finance — revenue, gross profit, margin and budget performance
- Category / Merchandising — category, SKU, pricing and assortment performance
- Supply Chain — inventory, replenishment, supplier service and stockouts
- Marketing — promotion effectiveness
- Store Management — store and department execution

## Analytical questions
1. How has revenue changed over the last two years, and which stores, departments and products drive growth or decline?
2. Which departments and products generate the strongest/weakest gross profit and gross margin, and where is margin leaking?
3. Which SKUs are strongest and weakest within each department by revenue, units, gross profit and growth?
4. Which products or store/department combinations show stockout, low-stock, overstock or slow-moving risk?
5. What seasonal patterns exist in demand, revenue, profitability and inventory?
6. Which suppliers have the strongest/weakest fill rates and delivery reliability?
7. Which departments/stores are missing budget and what operational factors may be associated with the misses?
8. Which promotions create meaningful unit lift, and which fail to generate sufficient incremental gross profit after promotional spend?

## Scope
**Included:** Jan 2024–Dec 2025; 4 GTA stores; 12 departments; 360 SKUs; transaction sales; historical price/cost; daily inventory; physical counts; adjustments; budgets; promotions; purchase orders; supplier performance.

**Out of scope for V1:** customer PII/loyalty, employee performance, e-commerce, competitor pricing, formal demand forecasting, causal price elasticity, machine learning.

## Key KPI definitions
- Revenue = signed quantity × net selling price
- COGS = signed quantity × unit cost
- Gross Profit = Revenue − COGS
- Gross Margin % = Gross Profit ÷ Revenue
- Discount % = Discount Value ÷ Regular-Price Sales Value
- Revenue Growth % = (Current − Prior) ÷ Prior
- Budget Variance $ = Actual Revenue − Budget Revenue
- Budget Variance % = Budget Variance $ ÷ Budget Revenue
- Inventory Value = On-Hand Quantity × Snapshot Unit Cost
- Inventory Turnover = Period COGS ÷ Average Daily Inventory Value
- Stockout Observation Rate = Zero-on-hand snapshots ÷ inventory snapshots
- Supplier Fill Rate = Units Received ÷ Units Ordered
- Late Delivery Rate = PO lines received after expected delivery date ÷ received PO lines
- Promotion Unit Lift % = (Promo Units − Baseline Units) ÷ Baseline Units
- Incremental Gross Profit = Promo GP − Baseline GP
- Promotion ROI = Incremental GP ÷ Net Promotion Spend

## Methodological boundaries
- Stockout observations show zero on-hand inventory; they do not directly measure lost sales.
- Promotion lift uses the immediately preceding equal-duration period as a directional baseline; it is not a causal experiment.
- Inventory variance is not automatically shrink. Physical-count variance and documented adjustment reasons are analyzed separately.
- Actual controllable contribution is not calculated because actual controllable-expense data is not available.
