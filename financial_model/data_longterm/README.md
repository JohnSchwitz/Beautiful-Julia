# Long-Term Projection Parameters (2028-2030)

This directory contains CSV files that drive Years 3-5 of the NLU Portfolio financial model.

## File Descriptions

### `assumptions_2028.csv`, `assumptions_2029.csv`, `assumptions_2030.csv`
Annual growth rates, margins, and operating assumptions for each year.

**Key Parameters:**
- **Revenue CAGR:** Compound annual growth rate for each platform
- **Gross Margin:** Cost of goods sold as % of revenue
- **Commission Rate:** Sales commission (declines over time as deal sizes increase)
- **OpEx Categories:** R&D, Sales & Marketing, G&A spending
- **Headcount:** Total FTEs by department

**⚠️ CRITICAL FIRST STEP:**
1. Run detailed model: `julia main.jl` (generates 2026-2027 forecast)
2. Look at Dec 2027 revenue in output report
3. Update `assumptions_2028.csv` lines 7-9 with actual Dec 2027 values:
   ```csv
   disclosure_revenue_2027,16900000,dollars,UPDATE THIS VALUE
   lingua_revenue_2027,518000,dollars,UPDATE THIS VALUE
   nebula_revenue_2027,440000,dollars,UPDATE THIS VALUE