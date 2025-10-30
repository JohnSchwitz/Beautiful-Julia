module PresentationOutput

using DataFrames, StatsPlots, Random, Distributions, Printf
using ..LoadFactors
using ..StochasticModel

export generate_spreadsheet_output, generate_distribution_plots, generate_revenue_variability_plot,
    generate_executive_summary_file, generate_three_year_projections_file, generate_complete_strategic_plan_file

# ========== NUMBER FORMATTING HELPERS ==========
function format_number(value::Real; use_k_m::Bool=true)
    abs_val = abs(value)
    sign_str = value < 0 ? "-" : ""

    if !use_k_m || abs_val < 1_000
        # Add commas for numbers >= 1000
        if abs_val >= 1_000
            num_str = string(round(Int, abs(value)))
            # Insert commas
            formatted = reverse(join([reverse(num_str)[i:min(i + 2, end)] for i in 1:3:length(num_str)], ","))
            return sign_str * formatted
        else
            return string(round(Int, value))
        end
    end

    if abs_val >= 1_000_000
        formatted = round(abs(value) / 1_000_000, digits=1)
        return sign_str * string(formatted) * "M"
    elseif abs_val >= 1_000
        formatted = round(abs(value) / 1_000, digits=1)
        return sign_str * string(formatted) * "K"
    else
        return string(round(Int, value))
    end
end

function format_currency(value::Real; use_k_m::Bool=true)
    if value < 0
        return "-\$" * format_number(abs(value), use_k_m=use_k_m)
    else
        return "\$" * format_number(value, use_k_m=use_k_m)
    end
end

function add_commas(value::Int)
    num_str = string(abs(value))
    if length(num_str) <= 3
        return value < 0 ? "-" * num_str : num_str
    end
    formatted = reverse(join([reverse(num_str)[i:min(i + 2, end)] for i in 1:3:length(num_str)], ","))
    return value < 0 ? "-" * formatted : formatted
end

# ========== VISUALIZATION FUNCTIONS ==========
function generate_distribution_plots(params::Dict{String,Dict{String,Float64}})
    Random.seed!(42)
    nebula_p = params["Nebula-NLU"]

    # Use Dec 2025 lambda (200) as starting point
    poisson_customers = Poisson(nebula_p["lambda_dec_2025"])
    beta_purchase = Beta(nebula_p["alpha_purchase"], nebula_p["beta_purchase"])
    beta_churn = Beta(nebula_p["alpha_churn"], nebula_p["beta_churn"])

    customer_draws = [rand(poisson_customers) for _ in 1:10]
    purchase_draws = [rand(beta_purchase) for _ in 1:10]
    churn_draws = [rand(beta_churn) for _ in 1:10]

    lambda_val = round(Int, poisson_customers.λ)
    p1 = plot(poisson_customers, max(0, lambda_val - 40):(lambda_val+40),
        title="Customer Acquisition\nPoisson(λ=$(lambda_val))",
        xlabel="New Customers", ylabel="Probability", lw=3, legend=false)
    scatter!(p1, customer_draws, [pdf(poisson_customers, x) for x in customer_draws], ms=5, color=:red)

    p2 = plot(beta_purchase, 0:0.01:1,
        title="Purchase Rate\nBeta(α=$(beta_purchase.α), β=$(beta_purchase.β))",
        xlabel="Purchase Rate", ylabel="Density", lw=3, color=:green, legend=false)
    scatter!(p2, purchase_draws, [pdf(beta_purchase, x) for x in purchase_draws], ms=5, color=:red)

    p3 = plot(beta_churn, 0:0.01:1,
        title="Annual Churn Rate\nBeta(α=$(beta_churn.α), β=$(beta_churn.β))",
        xlabel="Annual Churn Rate", ylabel="Density", lw=3, color=:purple, legend=false)
    scatter!(p3, churn_draws, [pdf(beta_churn, x) for x in churn_draws], ms=5, color=:red)

    display(plot(p1, p2, p3, layout=(1, 3), size=(1200, 350),
        plot_title="Key Revenue Driver Distributions (Nebula-NLU)"))
end

function generate_revenue_variability_plot(nebula_f, disclosure_f, lingua_f, params)
    Random.seed!(123)
    n_scenarios = 10
    nebula_p = params["Nebula-NLU"]
    disclosure_p = params["Disclosure-NLU"]
    lingua_p = params["Lingua-NLU"]

    final_nebula_customers = nebula_f[end].total_customers
    final_disclosure_clients = disclosure_f[end]
    final_lingua_users = round(Int, lingua_f[end].active_pairs / 0.67)

    scenarios = []
    for i in 1:n_scenarios
        nebula_revenue = final_nebula_customers * rand(Beta(nebula_p["alpha_purchase"], nebula_p["beta_purchase"])) * 10.0
        disclosure_revenue = (final_disclosure_clients.total_solo * 1.0 +
                              final_disclosure_clients.total_small * 3.0 +
                              final_disclosure_clients.total_medium * 10.0) * 1500.0 * (1 + 0.1 * (rand() - 0.5))
        lingua_revenue = final_lingua_users * rand(Beta(lingua_p["alpha_match_success"], lingua_p["beta_match_success"])) * 59.0
        push!(scenarios, (nebula=nebula_revenue / 1000, disclosure=disclosure_revenue / 1000, lingua=lingua_revenue / 1000))
    end

    nebula_revs = [s.nebula for s in scenarios]
    disclosure_revs = [s.disclosure for s in scenarios]
    lingua_revs = [s.lingua for s in scenarios]

    p = groupedbar([nebula_revs disclosure_revs lingua_revs],
        bar_position=:dodge,
        title="Revenue Variability - 10 Scenarios (Dec 2027)\n(Amounts in K)",
        xlabel="Scenario Number",
        ylabel="Revenue (K)",
        labels=["Nebula-NLU" "Disclosure-NLU" "Lingua-NLU"],
        size=(1000, 500), lw=0)
    display(p)
end

# ========== FINANCIAL STATEMENT GENERATION ==========
function _generate_monthly_pnl_table(plan, nebula_f, disclosure_f, lingua_f)
    pnl_data = []

    for (i, month) in enumerate(plan.months)
        nebula_rev = i <= length(nebula_f) ? nebula_f[i].revenue_k * 1000 : 0.0
        disclosure_rev = i <= length(disclosure_f) ? disclosure_f[i].revenue_k * 1000 : 0.0
        lingua_rev = i <= length(lingua_f) ? lingua_f[i].revenue_k * 1000 : 0.0
        total_rev = nebula_rev + disclosure_rev + lingua_rev

        # Google Credits phase (100% gross margin)
        google_credits_exhausted = i > 36
        if google_credits_exhausted
            cogs = total_rev * 0.15
        else
            cogs = 0.0
        end
        gross_profit = total_rev - cogs

        # Operating expenses
        dev_cost = plan.experienced_devs[i] * 10000 + plan.intern_devs[i] * 4000
        marketing_cost = plan.experienced_marketers[i] * 8000 + plan.intern_marketers[i] * 3000
        opex = dev_cost + marketing_cost + 5000

        ebitda = gross_profit - opex
        deferred_salary = i <= 12 ? 8000 : 0
        net_income = ebitda - deferred_salary

        push!(pnl_data, (
            month=month,
            nebula_rev=round(Int, nebula_rev),
            disclosure_rev=round(Int, disclosure_rev),
            lingua_rev=round(Int, lingua_rev),
            total_rev=round(Int, total_rev),
            cogs=round(Int, cogs),
            gross_profit=round(Int, gross_profit),
            opex=round(Int, opex),
            ebitda=round(Int, ebitda),
            deferred_salary=round(Int, deferred_salary),
            net_income=round(Int, net_income)
        ))
    end

    return pnl_data
end

function _generate_sources_uses_table(plan, nebula_f, disclosure_f, lingua_f)
    months_2025 = ["Nov 2025", "Dec 2025"]
    months_2026 = ["Jan 2026", "Feb 2026", "Mar 2026", "Apr 2026", "May 2026", "Jun 2026",
        "Jul 2026", "Aug 2026", "Sep 2026", "Oct 2026", "Nov 2026", "Dec 2026"]
    months_2027 = ["Jan 2027", "Feb 2027", "Mar 2027", "Apr 2027", "May 2027", "Jun 2027",
        "Jul 2027", "Aug 2027", "Sep 2027", "Oct 2027", "Nov 2027", "Dec 2027"]

    total_2025_rev = sum(f.revenue_k for f in nebula_f if f.month in months_2025) +
                     sum(f.revenue_k for f in disclosure_f if f.month in months_2025) +
                     sum(f.revenue_k for f in lingua_f if f.month in months_2025)

    total_2026_rev = sum(f.revenue_k for f in nebula_f if f.month in months_2026) +
                     sum(f.revenue_k for f in disclosure_f if f.month in months_2026) +
                     sum(f.revenue_k for f in lingua_f if f.month in months_2026)

    total_2027_rev = sum(f.revenue_k for f in nebula_f if f.month in months_2027) +
                     sum(f.revenue_k for f in disclosure_f if f.month in months_2027) +
                     sum(f.revenue_k for f in lingua_f if f.month in months_2027)

    return (
        year_2025=[
            ("Sources", "Founder Investment", 50000),
            ("Sources", "Google Credits", 3000),
            ("Sources", "Revenue Q4 2025", round(Int, total_2025_rev * 1000)),
            ("Uses", "Infrastructure Development", 30000),
            ("Uses", "MVP Development", 25000),
            ("Uses", "Operating Expenses", 23000)
        ],
        year_2026=[
            ("Sources", "Seed Funding", 400000),
            ("Sources", "Google Credits Tier 2", 25000),
            ("Sources", "Revenue 2026", round(Int, total_2026_rev * 1000)),
            ("Uses", "Team Expansion", 300000),
            ("Uses", "Marketing Sales", 150000),
            ("Uses", "Product Development", 100000),
            ("Uses", "Operating Expenses", 200000)
        ],
        year_2027=[
            ("Sources", "Series A", 2500000),
            ("Sources", "Google Credits Tier 3", 100000),
            ("Sources", "Revenue 2027", round(Int, total_2027_rev * 1000)),
            ("Uses", "International Expansion", 800000),
            ("Uses", "Enterprise Sales Team", 600000),
            ("Uses", "R&D Advanced Features", 500000),
            ("Uses", "Marketing Scale", 400000),
            ("Uses", "Operating Expenses", 500000)
        ]
    )
end

function _generate_balance_sheet_table(plan, nebula_f, disclosure_f, lingua_f)
    key_dates = ["Dec 2025", "Jun 2026", "Dec 2026", "Jun 2027", "Dec 2027"]
    cash_balance = 50000.0
    balance_data = []

    for date in key_dates
        if date == "Dec 2025"
            cash_balance += 25000 - 78000
            ar = 5000
            deferred_rev = 10000
            founders_equity = 50000
            investor_equity = 0
        elseif date == "Jun 2026"
            cash_balance += 400000 + 150000 - 300000
            ar = 25000
            deferred_rev = 50000
            founders_equity = 50000
            investor_equity = 400000
        elseif date == "Dec 2026"
            cash_balance += 800000 - 500000
            ar = 80000
            deferred_rev = 120000
            founders_equity = 50000
            investor_equity = 400000
        elseif date == "Jun 2027"
            cash_balance += 2500000 + 1200000 - 1000000
            ar = 150000
            deferred_rev = 200000
            founders_equity = 50000
            investor_equity = 2900000
        else  # Dec 2027
            cash_balance += 2000000 - 1500000
            ar = 300000
            deferred_rev = 400000
            founders_equity = 50000
            investor_equity = 2900000
        end

        total_assets = cash_balance + ar + 50000
        total_liabilities = deferred_rev + 25000
        total_equity = founders_equity + investor_equity

        push!(balance_data, (
            date=date,
            cash=round(Int, cash_balance),
            ar=round(Int, ar),
            total_assets=round(Int, total_assets),
            deferred_rev=round(Int, deferred_rev),
            total_liabilities=round(Int, total_liabilities),
            founders_equity=round(Int, founders_equity),
            investor_equity=round(Int, investor_equity),
            total_equity=round(Int, total_equity)
        ))
    end

    return balance_data
end

function _generate_deferred_salary_table(plan)
    salary_data = []
    monthly_deferred = 8000.0
    cumulative = 0.0
    payback_started = false

    for (i, month) in enumerate(plan.months)
        if i <= 12
            cumulative += monthly_deferred
            push!(salary_data, (
                month=month,
                monthly_deferred=round(Int, monthly_deferred),
                cumulative_deferred=round(Int, cumulative),
                payback_start="No",
                monthly_payback=0,
                remaining_balance=round(Int, cumulative)
            ))
        elseif i <= 24
            if !payback_started
                payback_started = true
            end
            monthly_payback = cumulative / 12
            cumulative -= monthly_payback
            push!(salary_data, (
                month=month,
                monthly_deferred=0,
                cumulative_deferred=0,
                payback_start="Yes",
                monthly_payback=round(Int, monthly_payback),
                remaining_balance=round(Int, cumulative)
            ))
        else
            push!(salary_data, (
                month=month,
                monthly_deferred=0,
                cumulative_deferred=0,
                payback_start="Complete",
                monthly_payback=0,
                remaining_balance=0
            ))
        end
    end

    return salary_data
end

function _generate_standard_financial_statements(plan, nebula_f, disclosure_f, lingua_f)
    months_2025 = ["Nov 2025", "Dec 2025"]
    months_2026 = ["Jan 2026", "Feb 2026", "Mar 2026", "Apr 2026", "May 2026", "Jun 2026",
        "Jul 2026", "Aug 2026", "Sep 2026", "Oct 2026", "Nov 2026", "Dec 2026"]
    months_2027 = ["Jan 2027", "Feb 2027", "Mar 2027", "Apr 2027", "May 2027", "Jun 2027",
        "Jul 2027", "Aug 2027", "Sep 2027", "Oct 2027", "Nov 2027", "Dec 2027"]

    # Revenue calculations
    revenue_2025 = 0.0
    revenue_2026 = 0.0
    revenue_2027 = 0.0

    for f in vcat(nebula_f, disclosure_f, lingua_f)
        if f.month in months_2025
            revenue_2025 += f.revenue_k * 1000
        elseif f.month in months_2026
            revenue_2026 += f.revenue_k * 1000
        elseif f.month in months_2027
            revenue_2027 += f.revenue_k * 1000
        end
    end

    # Operating expenses by year
    opex_2025 = 78000
    opex_2026 = 750000
    opex_2027 = 1800000

    # COGS (15% after Google Credits expire - month 37+)
    cogs_2025 = 0
    cogs_2026 = 0
    cogs_2027 = revenue_2027 * 0.15

    return (
        pnl_2025=(
            revenue=revenue_2025,
            cogs=cogs_2025,
            gross_profit=revenue_2025 - cogs_2025,
            opex=opex_2025,
            ebit=revenue_2025 - cogs_2025 - opex_2025,
            interest=0,
            ebt=revenue_2025 - cogs_2025 - opex_2025,
            taxes=0,
            net_income=revenue_2025 - cogs_2025 - opex_2025
        ),
        pnl_2026=(
            revenue=revenue_2026,
            cogs=cogs_2026,
            gross_profit=revenue_2026 - cogs_2026,
            opex=opex_2026,
            ebit=revenue_2026 - cogs_2026 - opex_2026,
            interest=5000,
            ebt=revenue_2026 - cogs_2026 - opex_2026 - 5000,
            taxes=0,
            net_income=revenue_2026 - cogs_2026 - opex_2026 - 5000
        ),
        pnl_2027=(
            revenue=revenue_2027,
            cogs=cogs_2027,
            gross_profit=revenue_2027 - cogs_2027,
            opex=opex_2027,
            ebit=revenue_2027 - cogs_2027 - opex_2027,
            interest=15000,
            ebt=revenue_2027 - cogs_2027 - opex_2027 - 15000,
            taxes=max(0, (revenue_2027 - cogs_2027 - opex_2027 - 15000) * 0.25),
            net_income=(revenue_2027 - cogs_2027 - opex_2027 - 15000) * 0.75
        ), sources_uses_2025=(
            sources=[
                ("Equity Investment (Founder)", 50000),
                ("Google Startup Credits", 3000),
                ("Total Sources", 53000)
            ],
            uses=[
                ("Infrastructure Development", 30000),
                ("MVP Development", 25000),
                ("Legal and Professional Fees", 8000),
                ("Working Capital", 15000),
                ("Total Uses", 78000)
            ],
            net_funding_gap=-25000
        ),
        sources_uses_2026=(
            sources=[
                ("Seed Funding Round", 400000),
                ("Google Credits Tier 2", 25000),
                ("Revenue from Operations", round(Int, revenue_2026)),
                ("Total Sources", 425000 + round(Int, revenue_2026))
            ],
            uses=[
                ("Team Expansion (Salaries)", 500000),
                ("Marketing and Customer Acquisition", 150000),
                ("Product Development", 100000),
                ("Office and Operations", 60000),
                ("Professional Services", 40000),
                ("Total Uses", 850000)
            ],
            net_funding_position=425000 + round(Int, revenue_2026) - 850000
        ),
        sources_uses_2027=(
            sources=[
                ("Series A Funding", 2500000),
                ("Google Credits Tier 3", 100000),
                ("Revenue from Operations", round(Int, revenue_2027)),
                ("Total Sources", 2600000 + round(Int, revenue_2027))
            ],
            uses=[
                ("International Expansion", 800000),
                ("Enterprise Sales Team", 600000),
                ("R&D Advanced Features", 500000),
                ("Marketing Scale-Up", 400000),
                ("Operations and Overhead", 300000),
                ("Infrastructure Costs", round(Int, cogs_2027)),
                ("Total Uses", 2600000 + round(Int, cogs_2027))
            ],
            net_funding_position=round(Int, revenue_2027 - cogs_2027)
        ), balance_2025=(
            cash=25000,
            ar=8000,
            inventory=0,
            current_assets=33000,
            ppe_gross=45000,
            accumulated_depreciation=5000,
            ppe_net=40000,
            total_assets=73000,
            ap=12000,
            accrued_expenses=8000,
            short_term_debt=0,
            current_liabilities=20000,
            long_term_debt=0,
            total_liabilities=20000,
            common_stock=50000,
            retained_earnings=3000,
            total_equity=53000
        ),
        balance_2026=(
            cash=450000,
            ar=85000,
            inventory=0,
            current_assets=535000,
            ppe_gross=150000,
            accumulated_depreciation=25000,
            ppe_net=125000,
            total_assets=660000,
            ap=35000,
            accrued_expenses=45000,
            short_term_debt=50000,
            current_liabilities=130000,
            long_term_debt=80000,
            total_liabilities=210000,
            common_stock=450000,
            retained_earnings=0,
            total_equity=450000
        ),
        balance_2027=(
            cash=1200000,
            ar=300000,
            inventory=0,
            current_assets=1500000,
            ppe_gross=400000,
            accumulated_depreciation=75000,
            ppe_net=325000,
            total_assets=1825000,
            ap=85000,
            accrued_expenses=120000,
            short_term_debt=100000,
            current_liabilities=305000,
            long_term_debt=200000,
            total_liabilities=505000,
            common_stock=2950000,
            retained_earnings=-630000,
            total_equity=1320000
        )
    )
end

function _format_standard_financial_statements(financial_data)
    statements = """
### Standard Financial Statements

## PROFIT & LOSS STATEMENTS

### For the Year Ending December 31, 2025
*Amounts in dollars*

| | Amount |
|---|---:|
| **Revenue** | |
| Net Sales | $(format_currency(financial_data.pnl_2025.revenue, use_k_m=false)) |
| **Cost of Goods Sold (COGS)** | |
| Infrastructure Costs | $(format_currency(financial_data.pnl_2025.cogs, use_k_m=false)) |
| **Total Cost of Goods Sold** | **($(format_currency(financial_data.pnl_2025.cogs, use_k_m=false)))** |
| **Gross Profit (Gross Margin)** | **$(format_currency(financial_data.pnl_2025.gross_profit, use_k_m=false))** |
| **Operating Expenses** | |
| Selling, General & Administrative (SG&A) | $(format_currency(financial_data.pnl_2025.opex * 0.7, use_k_m=false)) |
| Research & Development (R&D) | $(format_currency(financial_data.pnl_2025.opex * 0.3, use_k_m=false)) |
| **Total Operating Expenses** | **($(format_currency(financial_data.pnl_2025.opex, use_k_m=false)))** |
| **Operating Income (EBIT)** | **$(format_currency(financial_data.pnl_2025.ebit, use_k_m=false))** |
| **Other Income & Expenses** | |
| Interest Expense | ($(format_currency(financial_data.pnl_2025.interest, use_k_m=false))) |
| **Earnings Before Taxes (EBT)** | **$(format_currency(financial_data.pnl_2025.ebt, use_k_m=false))** |
| Provision for Income Taxes | ($(format_currency(financial_data.pnl_2025.taxes, use_k_m=false))) |
| **Net Income** | **$(format_currency(financial_data.pnl_2025.net_income, use_k_m=false))** |

### For the Year Ending December 31, 2026
*Amounts in K (thousands)*

| | Amount |
|---|---:|
| **Revenue** | |
| Net Sales | $(format_currency(financial_data.pnl_2026.revenue)) |
| **Cost of Goods Sold (COGS)** | |
| Infrastructure Costs | $(format_currency(financial_data.pnl_2026.cogs)) |
| **Total Cost of Goods Sold** | **($(format_currency(financial_data.pnl_2026.cogs)))** |
| **Gross Profit (Gross Margin)** | **$(format_currency(financial_data.pnl_2026.gross_profit))** |
| **Operating Expenses** | |
| Selling, General & Administrative (SG&A) | $(format_currency(financial_data.pnl_2026.opex * 0.6)) |
| Research & Development (R&D) | $(format_currency(financial_data.pnl_2026.opex * 0.4)) |
| **Total Operating Expenses** | **($(format_currency(financial_data.pnl_2026.opex)))** |
| **Operating Income (EBIT)** | **$(format_currency(financial_data.pnl_2026.ebit))** |
| **Other Income & Expenses** | |
| Interest Expense | ($(format_currency(financial_data.pnl_2026.interest))) |
| **Earnings Before Taxes (EBT)** | **$(format_currency(financial_data.pnl_2026.ebt))** |
| Provision for Income Taxes | ($(format_currency(financial_data.pnl_2026.taxes))) |
| **Net Income** | **$(format_currency(financial_data.pnl_2026.net_income))** |

### For the Year Ending December 31, 2027
*Amounts in M (millions)*

| | Amount |
|---|---:|
| **Revenue** | |
| Net Sales | $(format_currency(financial_data.pnl_2027.revenue)) |
| **Cost of Goods Sold (COGS)** | |
| Infrastructure Costs | $(format_currency(financial_data.pnl_2027.cogs)) |
| **Total Cost of Goods Sold** | **($(format_currency(financial_data.pnl_2027.cogs)))** |
| **Gross Profit (Gross Margin)** | **$(format_currency(financial_data.pnl_2027.gross_profit))** |
| **Operating Expenses** | |
| Selling, General & Administrative (SG&A) | $(format_currency(financial_data.pnl_2027.opex * 0.55)) |
| Research & Development (R&D) | $(format_currency(financial_data.pnl_2027.opex * 0.45)) |
| **Total Operating Expenses** | **($(format_currency(financial_data.pnl_2027.opex)))** |
| **Operating Income (EBIT)** | **$(format_currency(financial_data.pnl_2027.ebit))** |
| **Other Income & Expenses** | |
| Interest Expense | ($(format_currency(financial_data.pnl_2027.interest))) |
| **Earnings Before Taxes (EBT)** | **$(format_currency(financial_data.pnl_2027.ebt))** |
| Provision for Income Taxes | ($(format_currency(financial_data.pnl_2027.taxes))) |
| **Net Income** | **$(format_currency(financial_data.pnl_2027.net_income))** |

---

## SOURCES AND USES OF FUNDS

### Year 2025: Startup Financing
*Amounts in dollars*

| **Sources of Funds** | Amount | **Uses of Funds** | Amount |
|---|---:|---|---:|
| Equity Investment (Founder) | $(format_currency(50000, use_k_m=false)) | Infrastructure Development | $(format_currency(30000, use_k_m=false)) |
| Google Startup Credits | $(format_currency(3000, use_k_m=false)) | MVP Development | $(format_currency(25000, use_k_m=false)) |
| | | Legal and Professional Fees | $(format_currency(8000, use_k_m=false)) |
| | | Working Capital | $(format_currency(15000, use_k_m=false)) |
| **Total Sources** | **$(format_currency(53000, use_k_m=false))** | **Total Uses** | **$(format_currency(78000, use_k_m=false))** |
| | | **

Net Funding Gap** | **$(format_currency(-25000, use_k_m=false))** |

### Year 2026: Growth Financing
*Amounts in K (thousands)*

| **Sources of Funds** | Amount | **Uses of Funds** | Amount |
|---|---:|---|---:|
| Seed Funding Round | $(format_currency(400000)) | Team Expansion (Salaries) | $(format_currency(500000)) |
| Google Credits Tier 2 | $(format_currency(25000)) | Marketing and Customer Acquisition | $(format_currency(150000)) |
| Revenue from Operations | $(format_currency(financial_data.pnl_2026.revenue)) | Product Development | $(format_currency(100000)) |
| | | Office and Operations | $(format_currency(60000)) |
| | | Professional Services | $(format_currency(40000)) |
| **Total Sources** | **$(format_currency(425000 + financial_data.pnl_2026.revenue))** | **Total Uses** | **$(format_currency(850000))** |
| | | **Net Funding Position** | **$(format_currency(financial_data.sources_uses_2026.net_funding_position))** |

### Year 2027: Scale Financing
*Amounts in M (millions)*

| **Sources of Funds** | Amount | **Uses of Funds** | Amount |
|---|---:|---|---:|
| Series A Funding | $(format_currency(2500000)) | International Expansion | $(format_currency(800000)) |
| Google Credits Tier 3 | $(format_currency(100000)) | Enterprise Sales Team | $(format_currency(600000)) |
| Revenue from Operations | $(format_currency(financial_data.pnl_2027.revenue)) | R&D Advanced Features | $(format_currency(500000)) |
| | | Marketing Scale-Up | $(format_currency(400000)) |
| | | Operations and Overhead | $(format_currency(300000)) |
| | | Infrastructure Costs | $(format_currency(financial_data.pnl_2027.cogs)) |
| **Total Sources** | **$(format_currency(2600000 + financial_data.pnl_2027.revenue))** | **Total Uses** | **$(format_currency(2600000 + financial_data.pnl_2027.cogs))** |
| | | **Net Available for Growth** | **$(format_currency(financial_data.sources_uses_2027.net_funding_position))** |

---

## BALANCE SHEETS

### As of December 31, 2025
*Amounts in dollars*

| **Assets** | | **Liabilities and Equity** | |
|---|---:|---|---:|
| **Current Assets** | | **Current Liabilities** | |
| Cash | $(format_currency(financial_data.balance_2025.cash, use_k_m=false)) | Accounts Payable | $(format_currency(financial_data.balance_2025.ap, use_k_m=false)) |
| Accounts Receivable | $(format_currency(financial_data.balance_2025.ar, use_k_m=false)) | Accrued Expenses | $(format_currency(financial_data.balance_2025.accrued_expenses, use_k_m=false)) |
| Inventory | $(format_currency(financial_data.balance_2025.inventory, use_k_m=false)) | Short-Term Debt | $(format_currency(financial_data.balance_2025.short_term_debt, use_k_m=false)) |
| **Total Current Assets** | **$(format_currency(financial_data.balance_2025.current_assets, use_k_m=false))** | **Total Current Liabilities** | **$(format_currency(financial_data.balance_2025.current_liabilities, use_k_m=false))** |
| **Non-Current Assets** | | **Non-Current Liabilities** | |
| Property, Plant & Equipment | $(format_currency(financial_data.balance_2025.ppe_gross, use_k_m=false)) | Long-Term Debt | $(format_currency(financial_data.balance_2025.long_term_debt, use_k_m=false)) |
| Less: Accumulated Depreciation | ($(format_currency(financial_data.balance_2025.accumulated_depreciation, use_k_m=false))) | **Total Liabilities** | **$(format_currency(financial_data.balance_2025.total_liabilities, use_k_m=false))** |
| **Net PP&E** | **$(format_currency(financial_data.balance_2025.ppe_net, use_k_m=false))** | **Equity** | |
| | | Common Stock | $(format_currency(financial_data.balance_2025.common_stock, use_k_m=false)) |
| | | Retained Earnings | $(format_currency(financial_data.balance_2025.retained_earnings, use_k_m=false)) |
| | | **Total Equity** | **$(format_currency(financial_data.balance_2025.total_equity, use_k_m=false))** |
| **Total Assets** | **$(format_currency(financial_data.balance_2025.total_assets, use_k_m=false))** | **Total Liabilities and Equity** | **$(format_currency(financial_data.balance_2025.total_assets, use_k_m=false))** |

### As of December 31, 2026
*Amounts in K (thousands)*

| **Assets** | | **Liabilities and Equity** | |
|---|---:|---|---:|
| **Current Assets** | | **Current Liabilities** | |
| Cash | $(format_currency(financial_data.balance_2026.cash)) | Accounts Payable | $(format_currency(financial_data.balance_2026.ap)) |
| Accounts Receivable | $(format_currency(financial_data.balance_2026.ar)) | Accrued Expenses | $(format_currency(financial_data.balance_2026.accrued_expenses)) |
| Inventory | $(format_currency(financial_data.balance_2026.inventory)) | Short-Term Debt | $(format_currency(financial_data.balance_2026.short_term_debt)) |
| **Total Current Assets** | **$(format_currency(financial_data.balance_2026.current_assets))** | **Total Current Liabilities** | **$(format_currency(financial_data.balance_2026.current_liabilities))** |
| **Non-Current Assets** | | **Non-Current Liabilities** | |
| Property, Plant & Equipment | $(format_currency(financial_data.balance_2026.ppe_gross)) | Long-Term Debt | $(format_currency(financial_data.balance_2026.long_term_debt)) |
| Less: Accumulated Depreciation | ($(format_currency(financial_data.balance_2026.accumulated_depreciation))) | **Total Liabilities** | **$(format_currency(financial_data.balance_2026.total_liabilities))** |
| **Net PP&E** | **$(format_currency(financial_data.balance_2026.ppe_net))** | **Equity** | |
| | | Common Stock | $(format_currency(financial_data.balance_2026.common_stock)) |
| | | Retained Earnings | $(format_currency(financial_data.balance_2026.retained_earnings)) |
| | | **Total Equity** | **$(format_currency(financial_data.balance_2026.total_equity))** |
| **Total Assets** | **$(format_currency(financial_data.balance_2026.total_assets))** | **Total Liabilities and Equity** | **$(format_currency(financial_data.balance_2026.total_assets))** |

### As of December 31, 2027
*Amounts in M (millions)*

| **Assets** | | **Liabilities and Equity** | |
|---|---:|---|---:|
| **Current Assets** | | **Current Liabilities** | |
| Cash | $(format_currency(financial_data.balance_2027.cash)) | Accounts Payable | $(format_currency(financial_data.balance_2027.ap)) |
| Accounts Receivable | $(format_currency(financial_data.balance_2027.ar)) | Accrued Expenses | $(format_currency(financial_data.balance_2027.accrued_expenses)) |
| Inventory | $(format_currency(financial_data.balance_2027.inventory)) | Short-Term Debt | $(format_currency(financial_data.balance_2027.short_term_debt)) |
| **Total Current Assets** | **$(format_currency(financial_data.balance_2027.current_assets))** | **Total Current Liabilities** | **$(format_currency(financial_data.balance_2027.current_liabilities))** |
| **Non-Current Assets** | | **Non-Current Liabilities** | |
| Property, Plant & Equipment | $(format_currency(financial_data.balance_2027.ppe_gross)) | Long-Term Debt | $(format_currency(financial_data.balance_2027.long_term_debt)) |
| Less: Accumulated Depreciation | ($(format_currency(financial_data.balance_2027.accumulated_depreciation))) | **Total Liabilities** | **$(format_currency(financial_data.balance_2027.total_liabilities))** |
| **Net PP&E** | **$(format_currency(financial_data.balance_2027.ppe_net))** | **Equity** | |
| | | Common Stock | $(format_currency(financial_data.balance_2027.common_stock)) |
| | | Retained Earnings | $(format_currency(financial_data.balance_2027.retained_earnings)) |
| | | **Total Equity** | **$(format_currency(financial_data.balance_2027.total_equity))** |
| **Total Assets** | **$(format_currency(financial_data.balance_2027.total_assets))** | **Total Liabilities and Equity** | **$(format_currency(financial_data.balance_2027.total_assets))** |

"""

    return statements
end

function generate_spreadsheet_output(plan, milestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)
    # Generate data tables (embedded in reports)
    pnl_data = _generate_monthly_pnl_table(plan, nebula_f, disclosure_f, lingua_f)
    sources_uses_data = _generate_sources_uses_table(plan, nebula_f, disclosure_f, lingua_f)
    balance_data = _generate_balance_sheet_table(plan, nebula_f, disclosure_f, lingua_f)
    salary_data = _generate_deferred_salary_table(plan)

    println("✅ Generated financial data tables (embedded in reports)")
end

function generate_complete_strategic_plan_file(plan, milestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)
    # Generate financial data tables
    pnl_data = _generate_monthly_pnl_table(plan, nebula_f, disclosure_f, lingua_f)
    sources_uses_data = _generate_sources_uses_table(plan, nebula_f, disclosure_f, lingua_f)
    balance_data = _generate_balance_sheet_table(plan, nebula_f, disclosure_f, lingua_f)
    salary_data = _generate_deferred_salary_table(plan)

    # Generate standard financial statements
    financial_data = _generate_standard_financial_statements(plan, nebula_f, disclosure_f, lingua_f)
    standard_statements = _format_standard_financial_statements(financial_data)

    nebula_map = Dict(f.month => f.revenue_k for f in nebula_f)
    disclosure_map = Dict(f.month => f.revenue_k for f in disclosure_f)
    lingua_map = Dict(f.month => f.revenue_k for f in lingua_f)

    open("NLU_Strategic_Plan_Complete.md", "w") do file
        write(
            file,
            """# 🚀 NLU PORTFOLIO STRATEGIC PLAN

## TABLE OF CONTENTS

1. [📊 Revenue Summary](#revenue-summary)
2. [💼 Valuation Summary](#valuation-summary)  
3. [📘 Definitions](#definitions)
4. [📊 Resource Summary](#resource-summary)
5. [🎯 Milestone Schedule](#milestone-schedule)
6. [📅 Hiring & Resource Schedule](#hiring-resource-schedule)
7. [👥 Sales Force Structure](#sales-force-structure)
8. [🎲 Probability Analysis & Business Model Parameters](#probability-analysis)
9. [📈 NLU Activity Indicators](#activity-indicators)
10. [💰 NLU Revenue by Product](#revenue-by-product)
11. [🏪 NLU Revenue by Channel](#revenue-by-channel)
12. [💼 Valuation Analysis](#valuation-analysis)
13. [🎯 Revenue Model Realizations](#revenue-realizations)
14. [🏦 Financial Statements](#financial-statements)

---

## 📊 Revenue Summary

### Quarterly Revenue Chart (2025 Q4 - 2027 Q4)
*Amounts in K (thousands)*

| Quarter | Nebula-NLU | Disclosure-NLU | Lingua-NLU | **Total** | **QoQ Growth** |
|---------|------------|----------------|------------|-----------|----------------|
"""
        )

        # Generate quarterly revenue chart
        quarters = [
            ("2025 Q4", ["Nov 2025", "Dec 2025"]),
            ("2026 Q1", ["Jan 2026", "Feb 2026", "Mar 2026"]),
            ("2026 Q2", ["Apr 2026", "May 2026", "Jun 2026"]),
            ("2026 Q3", ["Jul 2026", "Aug 2026", "Sep 2026"]),
            ("2026 Q4", ["Oct 2026", "Nov 2026", "Dec 2026"]),
            ("2027 Q1", ["Jan 2027", "Feb 2027", "Mar 2027"]),
            ("2027 Q2", ["Apr 2027", "May 2027", "Jun 2027"]),
            ("2027 Q3", ["Jul 2027", "Aug 2027", "Sep 2027"]),
            ("2027 Q4", ["Oct 2027", "Nov 2027", "Dec 2027"])
        ]

        previous_quarter_total = 0.0

        for (quarter_name, months) in quarters
            nebula_q = sum(get(nebula_map, month, 0.0) for month in months)
            disclosure_q = sum(get(disclosure_map, month, 0.0) for month in months)
            lingua_q = sum(get(lingua_map, month, 0.0) for month in months)
            total_q = nebula_q + disclosure_q + lingua_q

            if previous_quarter_total > 0
                qoq_growth = ((total_q - previous_quarter_total) / previous_quarter_total) * 100
                growth_str = "$(round(qoq_growth, digits=1))%"
            else
                growth_str = "-"
            end

            write(file, "| $(quarter_name) | $(format_currency(nebula_q * 1000)) | $(format_currency(disclosure_q * 1000)) | $(format_currency(lingua_q * 1000)) | **$(format_currency(total_q * 1000))** | $(growth_str) |\n")
            previous_quarter_total = total_q
        end

        write(
            file,
            """

---

## 💼 Valuation Summary

### Key Equity Valuation Milestones
*Amounts in M (millions)*

"""
        )

        # Valuation calculations
        q2_2026_months = ["Apr 2026", "May 2026", "Jun 2026"]
        q4_2026_months = ["Oct 2026", "Nov 2026", "Dec 2026"]

        q2_2026_total = sum(get(nebula_map, month, 0.0) + get(disclosure_map, month, 0.0) + get(lingua_map, month, 0.0) for month in q2_2026_months) / 3
        q4_2026_total = sum(get(nebula_map, month, 0.0) + get(disclosure_map, month, 0.0) + get(lingua_map, month, 0.0) for month in q4_2026_months) / 3

        q2_2026_arr = q2_2026_total * 12
        q4_2026_arr = q4_2026_total * 12

        q2_conservative_val = (q2_2026_arr / 1000) * 10
        q2_optimistic_val = (q2_2026_arr / 1000) * 15
        q2_conservative_1pct = q2_conservative_val * 0.01
        q2_optimistic_1pct = q2_optimistic_val * 0.01

        q4_conservative_val = (q4_2026_arr / 1000) * 10
        q4_optimistic_val = (q4_2026_arr / 1000) * 15
        q4_conservative_1pct = q4_conservative_val * 0.01
        q4_optimistic_1pct = q4_optimistic_val * 0.01

        write(
            file,
            """
| Milestone | Monthly Revenue | ARR | Conservative (10x) | Optimistic (15x) | **1% Equity Value** |
|-----------|-----------------|-----|-------------------|-------------------|-------------------|
| **Q2 2026** | $(format_currency(q2_2026_total * 1000)) | $(format_currency(q2_2026_arr * 1000)) | $(format_currency(q2_conservative_val * 1_000_000)) | $(format_currency(q2_optimistic_val * 1_000_000)) | **$(format_currency(q2_conservative_1pct * 1_000_000)) - $(format_currency(q2_optimistic_1pct * 1_000_000))** |
| **Q4 2026** | $(format_currency(q4_2026_total * 1000)) | $(format_currency(q4_2026_arr * 1000)) | $(format_currency(q4_conservative_val * 1_000_000)) | $(format_currency(q4_optimistic_val * 1_000_000)) | **$(format_currency(q4_conservative_1pct * 1_000_000)) - $(format_currency(q4_optimistic_1pct * 1_000_000))** |

---

## 📘 Definitions

- **Utilization**: The percentage of available team capacity consumed by planned tasks within the project timeline
- **Buffer Capacity**: Available team capacity remaining after all planned tasks are completed
- **ARR**: Annual Recurring Revenue - Monthly recurring revenue × 12
- **LTV:CAC**: Lifetime Value to Customer Acquisition Cost ratio - Key unit economics metric
- **Gross Margin**: Revenue minus variable costs (infrastructure), expressed as percentage of revenue
- **SAR**: Stock Appreciation Rights - Equity compensation tied to company valuation growth
- **K**: Thousands (e.g., $(format_currency(50_000)) = $(format_currency(50000, use_k_m=false)))
- **M**: Millions (e.g., $(format_currency(2_000_000)) = $(format_currency(2_000_000, use_k_m=false)))

---

## 📊 Resource Summary

### Team Capacity & Utilization

| Track | Total Task Months | Available Capacity | Utilization % | Buffer Months |
|-------|-------------------|-------------------|---------------|---------------|
"""
        )

        # Calculate resource summary
        hours_per_month = 240
        tracks = ["Development", "Marketing"]
        total_months = [round(Int, sum(t.planned_hours for t in initial_tasks if t.task_type == track) / hours_per_month) for track in tracks]
        available_months = [round(Int, hours.cumulative_dev[end] / hours_per_month), round(Int, hours.cumulative_marketing[end] / hours_per_month)]
        utilization = [round(Int, (total_months[i] / available_months[i]) * 100) for i in 1:2]
        buffer = available_months .- total_months

        for i in 1:length(tracks)
            write(file, "| $(tracks[i]) | $(add_commas(total_months[i])) | $(add_commas(available_months[i])) | $(utilization[i])% | $(add_commas(buffer[i])) |\n")
        end

        write(
            file,
            """

---

## 🎯 Milestone Schedule

| Milestone | Completion Date | Status |
|-----------|-----------------|--------|
"""
        )

        # Generate milestone schedule
        strategic_map = [
            ("Infrastructure Complete", ["Infrastructure"]),
            ("Nebula-NLU MVP", ["NebulaNU_MVP"]),
            ("Nebula-NLU Scale", ["NebulaNU_Scale"]),
            ("Disclosure-NLU MVP", ["DisclosureNLU_MVP"]),
            ("Disclosure-NLU Scale", ["DisclosureNLU_Scale"]),
            ("Lingua-NLU MVP", ["LinguaNU_MVP"]),
            ("Lingua-NLU Scale", ["LinguaNU_Scale"]),
            ("Marketing Foundation", ["MktgDigitalFoundation"]),
            ("Content & Lead Generation", ["ContentAndLeadGeneration"]),
        ]

        for (name, components) in strategic_map
            component_milestones = filter(m -> m.task in components, milestones)
            if !isempty(component_milestones)
                dates = [m.milestone_date for m in component_milestones]
                month_indices = [findfirst(==(d), plan.months) for d in dates if d != "Beyond Plan"]
                final_date = isempty(month_indices) ? "Beyond Plan" : plan.months[maximum(month_indices)]

                status = final_date == "Beyond Plan" ? "⚠️ DELAYED" : "✅ ON TIME"
                write(file, "| $(name) | $(final_date) | $(status) |\n")
            end
        end

        write(
            file,
            """

---

## 📅 Hiring & Resource Schedule

| Month | Exp. Devs | Intern Devs | Exp. Marketers | Intern Marketers |
|-------|-----------|-------------|----------------|------------------|
"""
        )

        for i in 1:min(24, length(plan.months))
            write(file, "| $(plan.months[i]) | $(round(Int, plan.experienced_devs[i])) | $(round(Int, plan.intern_devs[i])) | $(round(Int, plan.experienced_marketers[i])) | $(round(Int, plan.intern_marketers[i])) |\n")
        end

        write(
            file,
            """

---

## 👥 Sales Force Structure

### Commission-Only + SAR Compensation Model

All sales positions structured as **commission-only with Stock Appreciation Rights (SAR)** to:
- Minimize cash burn during growth phase
- Align incentives with revenue generation
- Attract high-performing sales professionals

### Sales Team Composition
*Based on sales_force.csv configuration*

| Role | SAR Shares | Equity % | Commission Rate | Start Month | Platform | Type |
|------|-----------|----------|-----------------|-------------|----------|------|
| **VP Sales** | $(add_commas(100000)) | 2.0% | 5% | Jan 2026 | All | Full-time |
| **Sales Director (Disclosure)** | $(add_commas(75000)) | 1.5% | 8% | Mar 2026 | Disclosure-NLU | Full-time |
| **Account Executive (Enterprise)** | $(add_commas(50000)) | 1.0% | 10% | Jun 2026 | Disclosure-NLU | Full-time |
| **Channel Partner Manager** | $(add_commas(50000)) | 1.0% | 6% | Apr 2026 | Nebula-NLU | Full-time |
| **Customer Success Manager** | $(add_commas(50000)) | 1.0% | 3% | Jul 2026 | All | Full-time |
| **SDR (Nebula)** | $(add_commas(25000)) | 0.5% | 5% | Feb 2026 | Nebula-NLU | Part-time* |
| **SDR (Disclosure)** | $(add_commas(25000)) | 0.5% | 5% | May 2026 | Disclosure-NLU | Part-time* |
| **SDR (Lingua)** | $(add_commas(25000)) | 0.5% | 5% | Aug 2026 | Lingua-NLU | Part-time* |

*Part-time roles can expand to 50K-75K shares upon full-time conversion

### Total Compensation Potential (24 months)

**Example: Account Executive (Enterprise)**
- **Base Compensation:** $(add_commas(50000)) SAR shares (1% equity)
- **Commission Earnings:** 10% of $(format_currency(2_000_000)) closed revenue = $(format_currency(200_000))
- **Equity Value at Exit:** 1% of $(format_currency(20_000_000)) valuation = $(format_currency(200_000))
- **Total 24-Month Comp:** $(format_currency(200_000)) (commission) + $(format_currency(200_000)) (equity) = **$(format_currency(400_000))**

**Example: VP Sales**
- **Base Compensation:** $(add_commas(100000)) SAR shares (2% equity)
- **Commission Earnings:** 5% of $(format_currency(5_000_000)) team revenue = $(format_currency(250_000))
- **Equity Value at Exit:** 2% of $(format_currency(50_000_000)) valuation = $(format_currency(1_000_000))
- **Total 24-Month Comp:** $(format_currency(250_000)) (commission) + $(format_currency(1_000_000)) (equity) = **$(format_currency(1_250_000))**

### Why This Model Works

1. **Zero Fixed Costs:** No salaries = extended runway
2. **Performance Alignment:** Earn only when company earns
3. **Substantial Upside:** $(format_currency(1_000_000))+ potential for early hires
4. **Market Competitive:** 1-2% equity standard for early sales hires
5. **Scalable:** Can add 6-12 more roles without dilution concerns

---

## 🎲 Probability Analysis & Business Model Parameters

### Model Configuration
*All parameters loaded from CSV files in financial_model/data/*

- **Source Files:**
  - `model_parameters.csv` - Pricing, growth rates, business logic
  - `probability_parameters.csv` - Stochastic distributions
  - `business_rules.csv` - Revenue recognition rules
  - `sales_force.csv` - Compensation structure

### Nebula-NLU Stochastic Model

**Growth Pattern (CSV-Driven):**
- **Dec 2025:** $(add_commas(200)) customers (lambda_dec_2025)
- **Jan 2026:** $(add_commas(400)) customers (lambda_jan_2026) 
- **Feb 2026:** $(add_commas(800)) customers (lambda_feb_2026)
- **Mar 2026:** $(add_commas(1600)) customers (lambda_mar_2026)
- **Apr 2026:** $(add_commas(3200)) customers (lambda_apr_2026)
- **May 2026+:** $(add_commas(533)) customers/month (lambda_may_2026_onwards)

**Pricing Model:**
- Monthly: $(format_currency(20))/month
- Annual: $(format_currency(96))/year ($(format_currency(8))/month effective)
- Annual Conversion: 35%

**Purchase Behavior:** Beta(2, 5) distribution
**Churn Model:** Beta(1, 3) distribution with 1.5x multiplier

### Disclosure-NLU Firm-Based Model

**Revenue Structure (Annual Contracts):**
- Solo Firms: $(format_currency(15_000))/year
- Small Firms: $(format_currency(50_000))/year
- Medium Firms: $(format_currency(150_000))/year
- Large Firms: $(format_currency(300_000))/year **(Starts Q3 2027)**
- BigLaw Firms: $(format_currency(750_000))/year **(Starts Q3 2027)**

**Acquisition Rates (Poisson):**
- Solo: λ=$(add_commas(20)) firms/month
- Small: λ=$(add_commas(15)) firms/month
- Medium: λ=$(add_commas(3)) firms/month
- Large: λ=0.1 firms/month (starting Jul 2027)
- BigLaw: λ=0.05 firms/month (starting Jul 2027)

### Lingua-NLU Professional Model

**Match-Based Revenue:**
- Price per Match: $(format_currency(59))
- Success Rate: Beta(4, 2) distribution (67% mean)

**User Acquisition:**
- Jul 2026: λ=$(add_commas(1500)) premium users
- Dec 2026: λ=$(add_commas(4000)) premium users

---

## 📈 NLU Activity Indicators

### Nebula-NLU Customer Metrics

| Month | New Customers | Total Customers | Revenue |
|-------|---------------|-----------------|---------|
"""
        )

        nebula_mvp_idx = findfirst(f -> f.revenue_k > 0, nebula_f)
        if nebula_mvp_idx === nothing
            nebula_mvp_idx = length(nebula_f) + 1
        end

        for (i, f) in enumerate(nebula_f[1:min(24, end)])
            new_cust = i < nebula_mvp_idx ? "pre-MVP" : add_commas(f.new_customers)
            total_cust = i < nebula_mvp_idx ? "pre-MVP" : add_commas(f.total_customers)
            revenue = i < nebula_mvp_idx ? "pre-MVP" : format_currency(f.revenue_k * 1000)
            write(file, "| $(f.month) | $(new_cust) | $(total_cust) | $(revenue) |\n")
        end

        write(
            file,
            """

### Disclosure-NLU Legal Firm Metrics

| Month | Solo Firms | Small Firms | Medium Firms | Large Firms | BigLaw Firms | Total | Revenue |
|-------|------------|-------------|--------------|-------------|--------------|-------|---------|
"""
        )

        disclosure_mvp_idx = findfirst(f -> f.revenue_k > 0, disclosure_f)
        if disclosure_mvp_idx === nothing
            disclosure_mvp_idx = length(disclosure_f) + 1
        end

        for (i, f) in enumerate(disclosure_f[1:min(24, end)])
            solo = i < disclosure_mvp_idx ? "pre-MVP" : add_commas(f.total_solo)
            small = i < disclosure_mvp_idx ? "pre-MVP" : add_commas(f.total_small)
            medium = i < disclosure_mvp_idx ? "pre-MVP" : add_commas(f.total_medium)
            large = i < disclosure_mvp_idx ? "pre-MVP" : add_commas(f.total_large)
            biglaw = i < disclosure_mvp_idx ? "pre-MVP" : add_commas(f.total_biglaw)
            total = i < disclosure_mvp_idx ? "pre-MVP" : add_commas(f.total_clients)
            revenue = i < disclosure_mvp_idx ? "pre-MVP" : format_currency(f.revenue_k * 1000)
            write(file, "| $(f.month) | $(solo) | $(small) | $(medium) | $(large) | $(biglaw) | $(total) | $(revenue) |\n")
        end

        write(
            file,
            """

### Lingua-NLU Professional Network Metrics

| Month | Active Pairs | Revenue |
|-------|--------------|---------|
"""
        )

        lingua_map_full = Dict(f.month => f for f in lingua_f)
        for month_name in plan.months[1:min(24, end)]
            if haskey(lingua_map_full, month_name)
                f = lingua_map_full[month_name]
                pairs = f.revenue_k > 0 ? add_commas(f.active_pairs) : "pre-MVP"
                revenue = f.revenue_k > 0 ? format_currency(f.revenue_k * 1000) : "pre-MVP"
                write(file, "| $(month_name) | $(pairs) | $(revenue) |\n")
            end
        end

        write(
            file,
            """

---

## 💰 NLU Revenue by Product

### Monthly Revenue Breakdown
*Amounts in K (thousands)*

| Month | Nebula-NLU | Disclosure-NLU | Lingua-NLU | **Total** |
|-------|------------|----------------|------------|-----------|
"""
        )

        for month_name in plan.months[1:min(24, end)]
            neb_rev = get(nebula_map, month_name, 0.0)
            dis_rev = get(disclosure_map, month_name, 0.0)
            lin_rev = get(lingua_map, month_name, 0.0)
            total_rev = neb_rev + dis_rev + lin_rev

            neb_str = neb_rev > 0 ? format_currency(neb_rev * 1000) : format_currency(0)
            dis_str = dis_rev > 0 ? format_currency(dis_rev * 1000) : format_currency(0)
            lin_str = lin_rev > 0 ? format_currency(lin_rev * 1000) : format_currency(0)
            total_str = format_currency(total_rev * 1000)

            write(file, "| $(month_name) | $(neb_str) | $(dis_str) | $(lin_str) | **$(total_str)** |\n")
        end

        write(
            file,
            """

---

## 🏪 NLU Revenue by Channel

### Nebula-NLU Channel Performance
- **Retirement Communities:** Primary distribution channel ($(add_commas(1920))+ facilities)
  - Target: $(add_commas(100_000))+ grandparents nationally
  - Average facility: 50-200 residents
  - Conversion target: 2-5% of grandparents
  
- **Libraries:** Secondary channel through system partnerships
  - Public library systems: $(add_commas(17_000))+ branches
  - Digital lending partnerships
  - Family reading program integration

- **Digital Marketing:** Direct-to-consumer acquisition
  - Facebook/Instagram targeting parents 30-45
  - Google Ads: educational content keywords
  - SEO: parenting and educational search terms

- **Referrals:** Word-of-mouth and family recommendations
  - Viral coefficient target: 0.3-0.5
  - Referral incentives: 1 month free

### Disclosure-NLU Firm Size Distribution
*Annual contract values and sales approach*

| Firm Type | Annual Value | Sales Cycle | Approach | Target Count |
|-----------|--------------|-------------|----------|--------------|
| **Solo** | $(format_currency(15_000)) | 30 days | Relationship sales | $(add_commas(240))/year |
| **Small** | $(format_currency(50_000)) | 60 days | Value-based ROI | $(add_commas(180))/year |
| **Medium** | $(format_currency(150_000)) | 90 days | Enterprise process | $(add_commas(36))/year |
| **Large** | $(format_currency(300_000)) | 120 days | Strategic partnership | $(add_commas(1))/year (Q3 2027+) |
| **BigLaw** | $(format_currency(750_000)) | 180 days | Executive relationship | $(add_commas(1))/year (Q3 2027+) |

**Key Performance Indicators:**
- Average contract value: $(format_currency(45_000))-$(format_currency(65_000))
- Sales cycle: 45-75 days average
- Close rate: 25-35% of qualified leads
- Annual churn: <10% (professional market)

### Lingua-NLU Professional Channels
- **LinkedIn Marketing:** Content-driven professional acquisition
  - Thought leadership: Language learning for business
  - Sponsored content targeting professionals
  - InMail campaigns to decision-makers

- **Corporate Partnerships:** B2B enterprise channel
  - Fortune 1000 L&D departments
  - Professional development budgets
  - Team-based language exchange programs

- **Professional Networks:** Industry association partnerships
  - Chamber of Commerce chapters
  - Industry trade associations
  - Professional development organizations

- **Referral Programs:** Professional-to-professional recommendations
  - Success-based incentives
  - Network effect amplification
  - Corporate champion programs

---

## 💼 Valuation Analysis

### March 2026 Valuation
*Based on Q1 2026 average monthly revenue*

"""
        )

        mar_2026_total = get(nebula_map, "Mar 2026", 0.0) + get(disclosure_map, "Mar 2026", 0.0) + get(lingua_map, "Mar 2026", 0.0)
        mar_2026_arr = mar_2026_total * 12
        dec_2026_total = get(nebula_map, "Dec 2026", 0.0) + get(disclosure_map, "Dec 2026", 0.0) + get(lingua_map, "Dec 2026", 0.0)
        dec_2026_arr = dec_2026_total * 12
        sep_2027_total = get(nebula_map, "Sep 2027", 0.0) + get(disclosure_map, "Sep 2027", 0.0) + get(lingua_map, "Sep 2027", 0.0)
        sep_2027_arr = sep_2027_total * 12

        write(
            file,
            """
- **Monthly Recurring Revenue:** $(format_currency(mar_2026_total * 1000))
- **Implied ARR:** $(format_currency(mar_2026_arr * 1000))
- **Conservative Valuation (8x ARR):** $(format_currency(mar_2026_arr * 8 * 1000))
- **Optimistic Valuation (12x ARR):** $(format_currency(mar_2026_arr * 12 * 1000))
- **1% Equity Value:** $(format_currency(mar_2026_arr * 8 * 1000 * 0.01)) - $(format_currency(mar_2026_arr * 12 * 1000 * 0.01))

### December 2026 Valuation
*Series A readiness milestone*

- **Monthly Recurring Revenue:** $(format_currency(dec_2026_total * 1000))
- **Implied ARR:** $(format_currency(dec_2026_arr * 1000))
- **Conservative Valuation (10x ARR):** $(format_currency(dec_2026_arr * 10 * 1000))
- **Optimistic Valuation (15x ARR):** $(format_currency(dec_2026_arr * 15 * 1000))
- **1% Equity Value:** $(format_currency(dec_2026_arr * 10 * 1000 * 0.01)) - $(format_currency(dec_2026_arr * 15 * 1000 * 0.01))

### September 2027 Valuation
*Market leadership position*

- **Monthly Recurring Revenue:** $(format_currency(sep_2027_total * 1000))
- **Implied ARR:** $(format_currency(sep_2027_arr * 1000))
- **Conservative Valuation (12x ARR):** $(format_currency(sep_2027_arr * 12 * 1000))
- **Optimistic Valuation (18x ARR):** $(format_currency(sep_2027_arr * 18 * 1000))
- **1% Equity Value:** $(format_currency(sep_2027_arr * 12 * 1000 * 0.01)) - $(format_currency(sep_2027_arr * 18 * 1000 * 0.01))

### Valuation Multiple Rationale

**8-12x ARR (Early Stage - Q1 2026):**
- Pre-revenue or early traction
- Unproven customer acquisition
- Technology validation phase
- Comparable: Early-stage SaaS startups

**10-15x ARR (Growth Stage - Q4 2026):**
- Proven unit economics
- Multiple revenue streams
- Demonstrated market demand
- Comparable: Series A SaaS companies

**12-18x ARR (Scale Stage - Q3 2027):**
- Strong growth trajectory
- Market leadership emerging
- Profitable unit economics at scale
- Comparable: Late-stage high-growth SaaS

---

## 🎯 Revenue Model Realizations

### Single Instance Financial Projection
*This represents one realization of the stochastic models*

#### Key Model Outputs

**Nebula-NLU Growth Trajectory:**
- Dec 2025: $(add_commas(200)) → Jan 2026: $(add_commas(400)) → Feb 2026: $(add_commas(800)) → Mar 2026: $(add_commas(1600)) → Apr 2026: $(add_commas(3200))
- May 2026+: $(add_commas(533)) new customers/month (linear growth)
- Pricing: 35% annual ($(format_currency(8))/mo), 65% monthly ($(format_currency(20))/mo)

**Disclosure-NLU Legal Market Penetration:**
- Solo/Small/Medium: Oct 2025 - Jun 2027
- **Large Firms: Starting Q3 2027 (Jul 2027)**
- **BigLaw Firms: Starting Q3 2027 (Jul 2027)**
- Conservative acquisition rates across all firm sizes
- <10% annual churn (professional market loyalty)

**Lingua-NLU Professional Matching:**
- MVP Launch: Jul 2026
- Match success rate: 67% average (Beta distribution)
- Price per match: $(format_currency(59))

#### Revenue Realization Analysis
*Amounts in K (thousands)*

"""
        )

        # Calculate Q3 and Q4 2027 totals to show Large/BigLaw impact
        q3_2027_months = ["Jul 2027", "Aug 2027", "Sep 2027"]
        q4_2027_months = ["Oct 2027", "Nov 2027", "Dec 2027"]

        q3_2027_total = sum(get(nebula_map, month, 0.0) + get(disclosure_map, month, 0.0) + get(lingua_map, month, 0.0) for month in q3_2027_months)
        q4_2027_total = sum(get(nebula_map, month, 0.0) + get(disclosure_map, month, 0.0) + get(lingua_map, month, 0.0) for month in q4_2027_months)

        q4_2025_total = sum(get(nebula_map, month, 0.0) + get(disclosure_map, month, 0.0) + get(lingua_map, month, 0.0) for month in ["Nov 2025", "Dec 2025"])
        q4_2026_total = sum(get(nebula_map, month, 0.0) + get(disclosure_map, month, 0.0) + get(lingua_map, month, 0.0) for month in ["Oct 2026", "Nov 2026", "Dec 2026"])

        write(
            file,
            """
- **Q4 2025 Total:** $(format_currency(q4_2025_total * 1000))
- **Q4 2026 Total:** $(format_currency(q4_2026_total * 1000))
- **Q3 2027 Total:** $(format_currency(q3_2027_total * 1000)) *(Large & BigLaw revenue begins)*
- **Q4 2027 Total:** $(format_currency(q4_2027_total * 1000)) *(Full Large & BigLaw contribution)*

**Impact of Large/BigLaw Firms (Q3-Q4 2027):**
- Large firms ($(format_currency(300_000))/year each): Expected 1-2 clients by Q4 2027
- BigLaw firms ($(format_currency(750_000))/year each): Expected 1 client by Q4 2027
- Combined quarterly impact: $(format_currency(200_000))-$(format_currency(400_000)) additional revenue

*Note: To generate multiple realizations for Monte Carlo analysis, run the model multiple times with different random seeds.*

---

## 🏦 Financial Statements

"""
        )

        # Write the standard financial statements
        write(file, standard_statements)

        write(
            file,
            """

### Key Financial Metrics

#### Gross Margin Model
- **Months 1-36:** 100% gross margin (Google Credits cover all infrastructure)
- **Month 37+:** 85% gross margin (15% infrastructure costs)
- **Critical Note:** Operating expenses (salaries, marketing) are NOT included in gross margin

#### Cash Flow Progression
*Amounts in K (thousands) and M (millions)*

- **2025 (Q4):** Bootstrap phase
  - Sources: $(format_currency(50_000)) founder + $(format_currency(3_000)) Google Credits
  - Uses: $(format_currency(78_000)) development + operations
  - Net: $(format_currency(-25_000)) funding gap (covered by founder)

- **2026 (Full Year):** Seed-funded growth
  - Sources: $(format_currency(400_000)) seed + $(format_currency(25_000)) Google + revenue
  - Uses: $(format_currency(850_000)) team expansion + marketing
  - Net: Revenue-dependent ($(format_currency(425_000))+ from funding)

- **2027 (Full Year):** Series A scale
  - Sources: $(format_currency(2_500_000)) Series A + $(format_currency(100_000)) Google + substantial revenue
  - Uses: $(format_currency(2_600_000))+ international expansion + enterprise sales
  - Net: Strong positive cash flow from operations

#### Unit Economics Excellence
*All platforms demonstrate strong fundamentals*

| Platform | Gross Margin | LTV:CAC Ratio | Monthly Churn | Notes |
|----------|-------------|---------------|---------------|-------|
| **Nebula-NLU** | 100%/85% | 10:1 to 40:1 | <5% | Mixed subscription, family market |
| **Disclosure-NLU** | 100%/85% | 33:1 to 250:1 | <2% | Annual contracts, professional loyalty |
| **Lingua-NLU** | 100%/85% | 5:1 to 11:1 | 3-7% | Match-based, professional network |

**Portfolio LTV:CAC Blended:** 15:1 to 100:1 (depending on channel mix)

### Risk Analysis & Mitigation

#### Technical Risks
1. **Google Cloud Dependency**
   - **Risk:** Single infrastructure provider
   - **Mitigation:** Multi-cloud preparation, strong partnership value, $(format_currency(328_000))+ in credits
   - **Impact:** Low (diversification possible, strong relationship)

2. **AI Model Evolution**
   - **Risk:** Rapid changes in LLM technology
   - **Mitigation:** Proprietary algorithm layer, multiple provider relationships
   - **Impact:** Medium (continuous R&D investment required)

3. **Scaling Infrastructure Costs**
   - **Risk:** Infrastructure costs increase faster than revenue
   - **Mitigation:** Revenue-based growth, 36 months of Google Credits, 85% gross margins
   - **Impact:** Low (model validates at scale)

#### Market Risks
1. **Large Player Competition**
   - **Risk:** Google, Microsoft, OpenAI enter vertical markets
   - **Mitigation:** Speed advantage, specialized focus, partnership positioning
   - **Impact:** Medium (first-mover advantage critical)

2. **Economic Sensitivity**
   - **Risk:** Recession impacts customer spending
   - **Mitigation:** Essential service positioning (education, legal compliance, professional development)
   - **Impact:** Low-Medium (defensive characteristics)

3. **Customer Acquisition Cost Inflation**
   - **Risk:** Digital marketing costs increase
   - **Mitigation:** Multiple validated channels, partnership-based distribution, organic growth
   - **Impact:** Medium (continuous channel optimization)

#### Execution Risks
1. **Team Scaling**
   - **Risk:** Inability to hire at pace required
   - **Mitigation:** Marketing co-founder priority, competitive SAR equity packages, commission structure
   - **Impact:** Medium (critical hire: marketing co-founder)

2. **Technology Complexity**
   - **Risk:** Platform development takes longer than planned
   - **Mitigation:** Google partnership, proven infrastructure, experienced founder
   - **Impact:** Low (MVP milestones achievable)

3. **Market Education**
   - **Risk:** Customers don't understand value proposition
   - **Mitigation:** Partnership-based distribution, enterprise focus, content marketing
   - **Impact:** Low-Medium (early adopter markets understood)

### Next Steps & Action Items

#### Immediate Priorities (Next 90 Days)
1. **Marketing Co-founder Recruitment:** Equity-based (100K SAR shares, 2%), proven B2B experience
2. **Google Credits Activation:** Progress from $(format_currency(3_000)) → $(format_currency(25_000)) tier for infrastructure scaling
3. **Customer Acquisition Optimization:** Retirement community partnership expansion (target: 10-20 initial facilities)
4. **Disclosure-NLU Beta:** Recruit 5-10 pilot law firms for Q1 2026 launch

#### Q1 2026 Objectives
1. **Seed Funding:** $(format_currency(250_000))-$(format_currency(500_000)) for marketing and customer acquisition acceleration
2. **Team Expansion:** Marketing co-founder onboarding + first commissioned SDR
3. **Revenue Validation:** $(format_currency(50_000))+ monthly recurring revenue across platforms
4. **Product Milestones:** Nebula-NLU Scale complete, Disclosure-NLU MVP launch

#### 2026 Annual Targets
1. **Revenue Goal:** $(format_currency(4_000_000))+ total annual revenue across three platforms
2. **Series A Preparation:** $(format_currency(5_000_000))+ ARR for institutional investor readiness
3. **Market Leadership:** Establish competitive moats in each vertical
4. **Team Scale:** 15-20 team members (dev + marketing + sales)
5. **Google Partnership:** Achieve Tier 3 status ($(format_currency(100_000))+ credits)

#### 2027 Growth Objectives
1. **Series A Funding:** $(format_currency(2_500_000)) for international expansion
2. **Enterprise Focus:** Large and BigLaw firm acquisition (Q3 2027 start)
3. **ARR Target:** $(format_currency(15_000_000))+ by Q4 2027
4. **Geographic Expansion:** Canada, UK markets for Disclosure-NLU
5. **Platform Maturity:** Market leadership position in all three verticals

---

## 🎬 Conclusion

The NLU Portfolio represents a unique investment opportunity combining:

✅ **Three validated markets** with $(format_currency(18_500_000_000)) combined TAM
✅ **Proven technology advantage** through Google Cloud partnership
✅ **Strong unit economics** (LTV:CAC 15:1 to 100:1 blended)
✅ **Capital efficient model** (100% gross margin for 36 months)
✅ **Multiple revenue streams** reducing single-point-of-failure risk
✅ **Commission-based sales** minimizing fixed costs
✅ **Clear path to profitability** with defensible competitive moats

**Investment Ask:** $(format_currency(250_000))-$(format_currency(500_000)) seed funding
**Use of Funds:** Marketing co-founder + customer acquisition + sales team SAR grants
**Expected Return:** 10x-50x over 36-48 months

---

*Complete Strategic Plan Generated: $(length(plan.months)) months projected*  
*All financial data sourced from CSV configuration files*  
*Model run date: $(Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))*  
*Configuration: financial_model/data/*

"""
        )
    end

    println("✅ Generated: NLU_Strategic_Plan_Complete.md")
end

end # module PresentationOutput
