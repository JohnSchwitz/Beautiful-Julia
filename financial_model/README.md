# NLU Portfolio Financial Model

## Running the Analysis

**IMPORTANT:** All commands must be run from the `financial_model/` directory.

### Setup
```bash
cd ~/Beautiful_Julia/financial_model

financial_model/
├── data/                           # All CSV configuration files
│   ├── business_rules.csv
│   ├── config.csv
│   ├── cost_factors.csv
│   ├── factors.csv
│   ├── model_parameters.csv
│   ├── probability_parameters.csv
│   ├── project_tasks.csv
│   ├── resource_plan.csv
│   └── sales_force.csv
├── presentation/                   # Presentation module components
│   ├── formatting.jl
│   ├── visualizations.jl
│   ├── financial_statements.jl
│   ├── report_generators.jl
│   └── presentation_output.jl
├── load_factors.jl                 # Data loading module
├── stochastic_model.jl            # Revenue modeling module
├── main.jl                        # Entry point (RUN THIS)
└── README.md                      # This file

# Generated output files (created by main.jl):
├── NLU_Executive_Summary.md
├── NLU_Three_Year_Projections.md
└── NLU_Strategic_Plan_Complete.md

Modifying the Model
Change Revenue Parameters
Edit data/model_parameters.csv:

Pricing (MonthlyPrice, AnnualPrice)
Growth rates (AnnualGrowthRatePostTarget)
Firm revenue (SoloAnnualRevenue through BigLawAnnualRevenue)

Change Customer Acquisition
Edit data/probability_parameters.csv:

Poisson lambda values for each platform
Beta distribution parameters for conversion/churn

Change Sales Force
Edit data/sales_force.csv:

SAR share grants
Commission rates (currently 25% across all roles)
Start months for each role

Change Resource Plan
Edit data/resource_plan.csv:

Team size by month
Work days per month
Efficiency factors

Commission-Only Sales Structure
All sales roles are commission-only with SAR equity:

Commission: 25% of closed revenue, paid monthly as revenue is recognized
SAR Equity: 25K-75K shares (0.5%-1.5% equity)
Zero Salaries: No fixed costs until May 2026
Liquidity: Angel/VC investment triggers SAR cash-out or conversion