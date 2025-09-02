# 📊 NLU Portfolio Three-Year Financial Projections

## Revenue Summary by Product (2025-2027)

| Product | 2025 Revenue | 2026 Revenue | 2027 Revenue | **Total Revenue** |
|---------|--------------|--------------|--------------|-------------------|
| **Nebula-NLU** | $52K | $4064K | $19184K | **$23299K** |
| **Disclosure-NLU** | $179K | $2453K | $4475K | **$7108K** |
| **Lingua-NLU** | $0K | $39K | $261K | **$300K** |
| **TOTAL PORTFOLIO** | **$231K** | **$6556K** | **$23919K** | **$30707K** |

## Financial Statements Overview

### Profit & Loss Statement
- **File Generated:** `monthly_pnl_with_deferred_salaries.csv`
- **Gross Margin:** 100% during Google Credits phase (months 1-36), then 85%
- **Operating Expenses:** Include team salaries, marketing, and overhead
- **Deferred Salary:** Founder salary deferred first 12 months, paid back months 13-24

### Sources & Uses of Funds
- **Files Generated:** `sources_uses_2025.csv`, `sources_uses_2026.csv`, `sources_uses_2027.csv`
- **2025:** Founder investment + Google Credits + initial revenue
- **2026:** Seed funding + Google Credits Tier 2 + scaling revenue
- **2027:** Series A + Google Credits Tier 3 + substantial revenue

### Balance Sheet
- **File Generated:** `balance_sheet_three_year.csv` 
- **Key Dates:** Dec 2025, Jun 2026, Dec 2026, Jun 2027, Dec 2027
- **Assets:** Cash, Accounts Receivable, Fixed Assets
- **Liabilities:** Deferred Revenue, Operating Liabilities  
- **Equity:** Founders Equity, Investor Equity progression

### Unit Economics by Platform

| Platform | Gross Margin | LTV:CAC Ratio | Notes |
|----------|-------------|---------------|-------|
| **Nebula-NLU** | 100%* then 85% | 10:1 to 40:1 | Mixed subscription model |
| **Disclosure-NLU** | 100%* then 85% | 33:1 to 250:1 | Annual firm-based contracts |
| **Lingua-NLU** | 100%* then 85% | 5:1 to 11:1 | Match-based professional pricing |

*During Google Startup Credits phase

## Revenue Model Details

### Parameters from CSV Configuration
- **All pricing parameters:** Loaded from `model_parameters.csv`
- **Growth rates:** Loaded from `probability_parameters.csv`
- **Customer acquisition:** Beta and Poisson distributions from CSV
- **Churn rates:** Platform-specific distributions from CSV

---

*All financial data exported to CSV files for detailed analysis. Parameters configurable via CSV files without code changes.*
