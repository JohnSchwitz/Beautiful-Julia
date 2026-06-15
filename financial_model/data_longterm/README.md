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
   discoverynlu_revenue_2027,11495000,dollars,UPDATE WITH ACTUAL MODEL OUTPUT
   noether_revenue_2027,11850000,dollars,UPDATE WITH ACTUAL MODEL OUTPUT
   nebulanlustudio_revenue_2027,1033000,dollars,UPDATE WITH ACTUAL MODEL OUTPUT
   ```

**Platform CAGR by Year:**

| Platform | 2027→2028 | 2028→2029 | 2029→2030 |
|---|---|---|---|
| DiscoveryNLU.studio | 75% | 64% | 49% |
| Noether.studio | 85% | 73% | 48% |
| NebulaNLU.studio | 195% | 100% | 33% |

**Why Noether.studio leads 2027-2028 CAGR:**
Series B funds a dedicated Noether enterprise team targeting AmLaw 200. BigLaw ($1.5M/yr) and Corp ($500K/yr) tier deals compound revenue rapidly. Noether CAGR exceeds DiscoveryNLU in 2028 because a smaller existing base captures larger deal sizes.

**Why NebulaNLU.studio peaks in 2028:**
Corporate contract renewals + 3 new Retirement Community Corporation logos. NebulaNLU CAGR decelerates sharply after 2029 as market penetration matures.

---

### `strategic_events.csv`
Discrete events that apply multipliers to platform revenue, margins, or costs in the long-term period. Events are categorized as:

- **Funding events:** Series B ($20M Sep 2028) and deployment schedule
- **Revenue acceleration:** noether_biglaw_acceleration, nebula_corporate_contracts, discovery_prosecution_advantage
- **Revenue headwinds:** Harvey AI competition (DiscoveryNLU), Thomson Reuters IP (Noether), market saturation (NebulaNLU.studio)
- **Margin improvements:** Google Cloud volume discounts, Julia compute optimization, Gemini API price drops
- **Cost reduction:** Commission rate schedule (25% → 20% → 18% → 15% by 2030)
- **Competitive intelligence:** Scenario flags with multiplier=0 (no model impact; for monitoring)

**Series B Timing:** September 2028 — timed to $45M ARR run rate for maximum valuation leverage (~$150M post-money target).

---

## Projected Long-Term Revenue

| Year | DiscoveryNLU.studio | Noether.studio | NebulaNLU.studio | Total |
|---|---|---|---|---|
| 2027 | $11.5M | $11.85M | $1.03M | **$24.3M** |
| 2028 | $20.1M | $21.9M | $3.0M | **$45.0M** |
| 2029 | $33.0M | $37.9M | $6.0M | **$76.9M** |
| 2030 | $48.9M | $56.1M | $8.0M | **$113.0M** |

**Exit Valuation (2030):** $1.2B–$1.8B (10-16× ARR)

---

## Workflow

```
julia main.jl                    # Run 2026-2027 stochastic model
  → output/monte_carlo_results.csv   # 100-simulation raw data
  → output/monte_carlo_report.md     # Statistics and valuation

Update assumptions_2028.csv      # Use Dec 2027 actuals from report
  → Run long-term projections module (future enhancement)
```
