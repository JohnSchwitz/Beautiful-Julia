# NLU Portfolio Financial Model

## Running the Analysis

**IMPORTANT:** All commands must be run from the `financial_model/` directory.

### Setup
```bash
cd ~/Beautiful_Julia/financial_model
julia main.jl
```

## Directory Structure

```
financial_model/
├── data/                           # All CSV configuration files
│   ├── actuals/
│   │   ├── discoverynlu_actuals.csv
│   │   └── noether_actuals.csv
│   ├── business_rules.csv
│   ├── config.csv
│   ├── cost_factors.csv
│   ├── factors.csv
│   ├── financing.csv
│   ├── Headcount.csv
│   ├── model_parameters.csv
│   ├── probability_parameters.csv
│   ├── Salaries.csv
│   └── sales_force.csv
├── data_longterm/                  # Years 3-5 projection parameters
│   ├── assumptions_2028.csv
│   ├── assumptions_2029.csv
│   ├── assumptions_2030.csv
│   ├── strategic_events.csv
│   └── README.md
├── output/                         # Generated output (do not edit directly)
│   ├── monte_carlo_report.md
│   └── monte_carlo_results.csv
├── presentation/                   # Presentation module components
│   ├── formatting.jl
│   ├── visualizations.jl
│   ├── financial_statements.jl
│   ├── report_generators.jl
│   └── presentation_output.jl
├── load_factors.jl                 # Data loading module
├── stochastic_model.jl             # Revenue modeling module
├── main.jl                         # Entry point (RUN THIS)
└── README.md                       # This file
```

### Generated output files (created by main.jl)
- `NLU_Executive_Summary.md`
- `NLU_Three_Year_Projections.md`
- `NLU_Strategic_Plan_Complete.md`

---

## Modifying the Model

### Change Revenue Parameters
Edit `data/model_parameters.csv`:
- **NebulaNLU.studio:** `CorporateContractMin`, `CorporateContractMax`, `NebulaNLU_Revenue_Start`
- **DiscoveryNLU.studio:** `SoloAnnualRevenue` through `BigLawAnnualRevenue`, `DiscoveryNLU_Revenue_Start`
- **Noether.studio:** `NoetherSoloAnnualRevenue` through `NoetherCorpAnnualRevenue`, `NoetherNLU_Revenue_Start`
- Ramp parameters: `DiscoveryRampMonth1` through `DiscoveryRampMonth5Plus` (and matching Noether ramp params)

### Change Customer Acquisition
Edit `data/probability_parameters.csv`:
- Poisson lambda values for each platform/tier (`lambda_solo_firms`, `lambda_small_firms`, etc.)
- Beta distribution churn parameters (`alpha_churn`, `beta_churn`) — currently Beta(1,15) ≈ 6.25% mean monthly churn

### Change Sales Force
Edit `data/sales_force.csv`:
- SAR share grants per role
- Commission rates (25% standard; 30% accelerator on deals >$150K)
- Recoverable draw amounts and duration (hunters: $5K/month × 3 months)
- Start months for each role
- Attorney Advisor channel structure (Virginia + NYC; 20% Year-1 commission)

### Commission-Only Sales Structure
All sales roles are commission-only with SAR equity:
- **Commission:** 25% of closed revenue, paid monthly as revenue is recognized; 30% accelerator on deals >$150K
- **Recoverable Draws:** Hunters receive $5K/month for 3 months (recouped from first commissions)
- **SAR Equity:** 50K–75K shares per role
- **Attorney Advisors:** 20% Year-1 commission + 75K SARs each (no draw)
- **Liquidity:** Angel/VC investment triggers SAR cash-out or conversion

### Change Funding Events
Edit `data/financing.csv`:
- `StartingCash`, `Founder`, `Angel` (Jul 2026), `VCRound` (Mar 2027), `SeriesB` (Sep 2028)

### Change Headcount
Edit `data/Headcount.csv`:
- **Development:** 4 STEM/OPT engineers + 2 heavily-subsidized interns (6 total through Feb 2027)
- **Sales_Channel:** 6 commission-only reps starting Jul 2026 (2 hunters + 2 NebulaNLU corporate + 2 attorney advisors); 8 from Mar 2027; 10 from Oct 2027
- **DevOps/GA:** 0 until Mar 2027 (post-VC funding); 1 DevOps + 3 GA from Mar 2027
- Commission-only reps are not salaried — headcount column reflects channel size, not payroll count

### Change Salaries
Edit `data/Salaries.csv`:
- Jan–Jun 2026: $9K/month total (4 STEM/OPT + 2 interns, working for equity)
- Jul–Sep 2026: $9K development + $10K hunter draws (temporary)
- Oct 2026–Feb 2027: $9K/month (draws expire)
- Mar 2027+: $40K development + $10K DevOps + $20K GA (post-VC hire plan)

### Resource Plan Note
Headcount and salary data are maintained in this repository. The former Google Sheet source
(`NLU Portfolio/Financial Strategy & Risk Management/Headcount&Salaries`) has been superseded by
`data/Headcount.csv` and `data/Salaries.csv` as the authoritative sources.

---

## Platforms

| Platform | Domain | Launch | Primary Buyers |
|---|---|---|---|
| **NebulaNLU.studio** | Retirement/elder care decision support | Jul 2026 | Retirement Community Corporations (top-down B2B) |
| **DiscoveryNLU.studio** | Legal document analysis & discovery | Aug 2026 (trial) / Sep 2026 (revenue) | Solo → BigLaw litigation attorneys |
| **Noether.studio** | USPTO patent corpus analysis | Sep 2026 (trial) / Sep 2026 (revenue) | Solo → BigLaw + Corp (in-house GC) patent attorneys |

---

## Key Model Assumptions

- **Arrival process:** Poisson(λ) new clients per month per tier, with 5-month ramp (20%/40%/65%/85%/100% of λ) for major-market-only launch
- **Churn:** Beta(1,15) ≈ 6.25% mean monthly firm churn; low due to institutional switching costs
- **Monte Carlo:** 100 simulations; results in `output/monte_carlo_results.csv`
- **Google Startup Credits:** $277K lifetime offset to COGS applied Jul–Dec 2026
- **R&D Tax Credit:** 20% of eligible development salaries
- **STEM/OPT:** H-1B petitions required by Mar 2027; modeled as headcount continuity risk
