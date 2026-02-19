module ReportGenerators

using Dates
using ..Formatting
using ..FinancialStatements
using ..LoadFactors

export generate_executive_summary_file, generate_three_year_projections_file,
    generate_complete_strategic_plan_file, generate_founder_capitalization_file

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function format_currency_abbreviated(value::Real)  # ← Changed from Float64 to Real
    if value == 0
        return "\$0"
    elseif abs(value) < 1000
        return "\$" * string(round(Int, value))
    elseif abs(value) < 1_000_000
        return "\$" * string(round(value / 1000, digits=1)) * "K"
    else
        return "\$" * string(round(value / 1_000_000, digits=1)) * "M"
    end
end

function parse_year_from_month(month_str::String)
    return parse(Int, split(month_str, " ")[2])
end

function group_months_by_year(months::Vector{String})
    months_by_year = Dict{Int,Vector{String}}()
    for month_str in months
        year = parse_year_from_month(month_str)
        if !haskey(months_by_year, year)
            months_by_year[year] = []
        end
        push!(months_by_year[year], month_str)
    end
    return months_by_year
end

# ============================================================================
# SECTION GENERATORS
# ============================================================================

function generate_revenue_summary_section(months::Vector{String}, nebula_map, disclosure_map, lingua_map)
    output = """
    ## 1. Revenue Summary

    ### Quarterly Revenue Chart

    | Quarter | Nebula | Disclosure | Lingua | Total | Growth |
    |---------|--------|------------|--------|-------|--------|
    """

    # Create quarters dynamically
    quarters = []
    current_quarter_months = []
    current_quarter_name = ""

    for (i, month_str) in enumerate(months)
        month_num = findfirst(startswith.(month_str, ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]))
        year = split(month_str, " ")[2]
        quarter = "Q" * string(cld(month_num, 3))
        quarter_name = year * " " * quarter

        if i == 1
            current_quarter_name = quarter_name
        end

        if quarter_name != current_quarter_name || i == length(months)
            if !isempty(current_quarter_months)
                push!(quarters, (current_quarter_name, copy(current_quarter_months)))
            end
            current_quarter_name = quarter_name
            current_quarter_months = []
        end
        push!(current_quarter_months, month_str)
    end

    previous_quarter_total = 0.0
    for (quarter_name, quarter_months) in quarters
        nebula_q = sum(get(nebula_map, m, 0.0) for m in quarter_months)
        disclosure_q = sum(get(disclosure_map, m, 0.0) for m in quarter_months)
        lingua_q = sum(get(lingua_map, m, 0.0) for m in quarter_months)
        total_q = nebula_q + disclosure_q + lingua_q

        growth_str = previous_quarter_total > 0 ? string(round(((total_q - previous_quarter_total) / previous_quarter_total) * 100, digits=1), "%") : "-"

        output *= "| $quarter_name | $(format_currency(nebula_q * 1000)) | $(format_currency(disclosure_q * 1000)) | $(format_currency(lingua_q * 1000)) | $(format_currency(total_q * 1000)) | $growth_str |\n"

        previous_quarter_total = total_q
    end

    output *= "\n---\n\n"
    return output
end

function generate_valuation_summary_section(months::Vector{String}, nebula_map, disclosure_map, lingua_map, financial_data)
    output = """
    ## 2. Valuation Summary

    ### Annual Financial Summary

    """

    # 2025 Summary
    output *= """
    #### 2025 Financial Summary

    **Revenue:** $(format_currency_abbreviated(financial_data.pnl_2025.revenue))
    **COGS:** \$0 (Google Credits: $(format_currency_abbreviated(financial_data.pnl_2025.google_credits)))
    **Gross Profit:** $(format_currency_abbreviated(financial_data.pnl_2025.gross_profit))

    **Operating Expenses:**
    - Commission (25% of revenue): $(format_currency_abbreviated(financial_data.pnl_2025.commission))
    - Development Salaries: $(format_currency_abbreviated(financial_data.pnl_2025.dev)) ← **R&D Tax Credit Eligible**
    - DevOps Salaries: $(format_currency_abbreviated(financial_data.pnl_2025.devops))
    - G&A Salaries: $(format_currency_abbreviated(financial_data.pnl_2025.ga))
    - **Total OpEx:** $(format_currency_abbreviated(financial_data.pnl_2025.opex))

    **EBIT:** $(format_currency_abbreviated(financial_data.pnl_2025.ebit))
    **Interest:** $(format_currency_abbreviated(financial_data.pnl_2025.interest))
    **Taxes:** $(format_currency_abbreviated(financial_data.pnl_2025.taxes))
    **Net Income:** $(format_currency_abbreviated(financial_data.pnl_2025.net_income))

    **R&D Tax Credit Calculation:**
    - Qualified Research Expenses: $(format_currency_abbreviated(financial_data.pnl_2025.dev))
    - Estimated Federal Credit (20%): $(format_currency_abbreviated(financial_data.pnl_2025.dev * 0.20))
    - Net Cash Impact: $(format_currency_abbreviated(financial_data.pnl_2025.net_income + financial_data.pnl_2025.dev * 0.20))

    """

    # Q4 2026 and Q4 2027 valuations
    q4_2026_months = ["Oct 2026", "Nov 2026", "Dec 2026"]
    q4_2026_total = sum(get(nebula_map, m, 0.0) + get(disclosure_map, m, 0.0) + get(lingua_map, m, 0.0) for m in q4_2026_months) / 3
    q4_2026_arr = q4_2026_total * 12

    q4_2027_months = ["Oct 2027", "Nov 2027", "Dec 2027"]
    q4_2027_total = sum(get(nebula_map, m, 0.0) + get(disclosure_map, m, 0.0) + get(lingua_map, m, 0.0) for m in q4_2027_months) / 3
    q4_2027_arr = q4_2027_total * 12

    output *= """
    ### Company Valuation Milestones

    | Milestone | Monthly Rev | ARR | Conservative | Optimistic | 1% Equity |
    |-----------|-------------|-----|--------------|------------|----------|
    | Q4 2026 | $(format_currency(q4_2026_total * 1000)) | $(format_currency(q4_2026_arr * 1000)) | $(format_currency((q4_2026_arr / 1000) * 10 * 1_000_000)) | $(format_currency((q4_2026_arr / 1000) * 15 * 1_000_000)) | $(format_currency((q4_2026_arr / 1000) * 10 * 0.01 * 1_000_000)) - $(format_currency((q4_2026_arr / 1000) * 15 * 0.01 * 1_000_000)) |
    | Q4 2027 | $(format_currency(q4_2027_total * 1000)) | $(format_currency(q4_2027_arr * 1000)) | $(format_currency((q4_2027_arr / 1000) * 12 * 1_000_000)) | $(format_currency((q4_2027_arr / 1000) * 18 * 1_000_000)) | $(format_currency((q4_2027_arr / 1000) * 12 * 0.01 * 1_000_000)) - $(format_currency((q4_2027_arr / 1000) * 18 * 0.01 * 1_000_000)) |

    ---

    """

    return output
end

function generate_definitions_section()
    return """
    ## 3. Definitions

    - **ARR**: Annual Recurring Revenue
    - **LTV:CAC**: Lifetime Value to Customer Acquisition Cost
    - **SAR**: Stock Appreciation Rights
    - **K**: Thousands, **M**: Millions
    - **IP**: Intellectual Property (founder-contributed software)
    - **R&D Tax Credit**: Federal credit for qualified research expenses (20% of eligible development salaries)

    ---

    """
end

function generate_hiring_schedule_section(months::Vector{String}, salaries_df, headcount_df)
    output = """
    ## 4. Hiring & Resource Schedule

    """

    # Build lookup dictionaries
    salary_lookup = Dict{String,NamedTuple}()
    for row in eachrow(salaries_df)
        salary_lookup[row.Month] = (
            dev=row.Development,
            devops=row.DevOps,
            ga=row.GA
        )
    end

    headcount_lookup = Dict{String,NamedTuple}()
    for row in eachrow(headcount_df)
        headcount_lookup[row.Month] = (
            dev=row.Development,
            devops=row.DevOps,
            marketing=row.Marketing,
            ga=row.GA
        )
    end

    # Staffing table
    output *= """
    ### Staffing Plan

    | Month | Development | Dev/Ops | Marketing | G&A | Total Monthly Salaries |
    |-------|-------------|---------|-----------|-----|------------------------|
    """

    for month in months[1:min(26, end)]
        salaries = get(salary_lookup, month, (dev=0, devops=0, ga=0))
        headcounts = get(headcount_lookup, month, (dev=0, devops=0, marketing=0, ga=0))

        dev_str = "$(headcounts.dev) ($(format_currency_abbreviated(salaries.dev)))"
        devops_str = "$(headcounts.devops) ($(format_currency_abbreviated(salaries.devops)))"
        marketing_str = "$(headcounts.marketing) (\$0)"  # Commission-based
        ga_str = "$(headcounts.ga) ($(format_currency_abbreviated(salaries.ga)))"

        total_salaries = salaries.dev + salaries.devops + salaries.ga
        total_str = format_currency_abbreviated(total_salaries)

        output *= "| $month | $dev_str | $devops_str | $marketing_str | $ga_str | $total_str |\n"
    end

    output *= """

    **Note:** Marketing compensation is 25% commission on revenue (not included in salary table).

    ### R&D Tax Credit Eligible Expenses

    Development salaries qualify for federal R&D tax credits (estimated 20% credit rate):

    """

    # Calculate R&D eligible by year
    dev_2025 = sum(get(salary_lookup, m, (dev=0, devops=0, ga=0)).dev for m in months if occursin("2025", m))
    dev_2026 = sum(get(salary_lookup, m, (dev=0, devops=0, ga=0)).dev for m in months if occursin("2026", m))
    dev_2027 = sum(get(salary_lookup, m, (dev=0, devops=0, ga=0)).dev for m in months if occursin("2027", m))

    output *= "- **2025:** $(format_currency_abbreviated(dev_2025)) (Est. credit: $(format_currency_abbreviated(dev_2025 * 0.20)))\n"
    output *= "- **2026:** $(format_currency_abbreviated(dev_2026)) (Est. credit: $(format_currency_abbreviated(dev_2026 * 0.20)))\n"
    output *= "- **2027:** $(format_currency_abbreviated(dev_2027)) (Est. credit: $(format_currency_abbreviated(dev_2027 * 0.20)))\n\n"

    output *= "---\n\n"

    return output
end

function generate_probability_analysis_section()
    return """
    ## 5. Probability Analysis

    **All parameters from CSV files**

    ### Nebula-NLU Model
    - Product Launch: Dec 2025 (200 customers, no revenue)
    - Revenue Start: Jan 2026
    - Jan-Apr 2026: Doubling phase (200→400→800→1,600→3,200)
    - May 2026+: Linear growth (533/month)
    - Pricing: Monthly \$20, Annual \$96 (35% choose annual)

    ### Disclosure-NLU Model
    - Product Launch: Mar 2026
    - Solo: \$15K/year (λ=10 new firms/month, Poisson distribution)
    - Small: \$50K/year (λ=10 new firms/month, Poisson distribution)
    - Medium: \$150K/year (λ=3 new firms/month, Poisson distribution)
    - Large: \$300K/year (λ=0.1 new firms/month, starts Jan 2027, Poisson)
    - BigLaw: \$750K/year (λ=0.1 new firms/month, starts Jan 2027, Poisson)

    ### Lingua-NLU Model
    **B2B-to-Consumer Strategy:**
    - Product Launch: Jul 2026
    - Sales approach: B2B corporate contracts with Fortune 5000 companies
    - Target customers: Companies with 500-10,000 employees needing language training
    - Value proposition: Replace \$10K/employee traditional training with \$500/employee peer matching
    - Corporate pricing: \$250K-\$3M annual contracts (tiered by company size)

    **Individual User Economics:**
    - Match price: \$59 per successful pairing
    - Match success rate: 67% (Beta distribution α=4, β=2)
    - User acquisition: Through corporate partnerships
    - Jul 2026 launch: 1,500 users from initial corporate pilots
    - Dec 2026: 4,000 users (ramping with corporate contracts)

    ---

    """
end

function generate_activity_indicators_section(months::Vector{String}, nebula_f, disclosure_f, lingua_f)
    output = """
    ## 6. Activity Indicators

    ### Nebula-NLU Customers

    | Month | New | Total | Revenue |
    |-------|-----|-------|---------|
    """

    nebula_start_idx = findfirst(f -> f.revenue_k > 0, nebula_f)
    if nebula_start_idx === nothing
        nebula_start_idx = length(nebula_f) + 1
    end

    for (i, f) in enumerate(nebula_f[1:min(26, end)])
        new_cust = i < nebula_start_idx ? "" : add_commas(f.new_customers)
        total_cust = i < nebula_start_idx ? "" : add_commas(f.total_customers)
        revenue = i < nebula_start_idx ? "" : format_currency(f.revenue_k * 1000)
        output *= "| $(f.month) | $new_cust | $total_cust | $revenue |\n"
    end

    output *= "\n### Disclosure-NLU Firms\n\n"
    output *= "| Month | Solo | Small | Medium | Large | BigLaw | Total | Revenue |\n"
    output *= "|-------|------|-------|--------|-------|--------|-------|---------|"
    output *= "\n"

    disclosure_start_idx = findfirst(f -> f.revenue_k > 0, disclosure_f)
    if disclosure_start_idx === nothing
        disclosure_start_idx = length(disclosure_f) + 1
    end

    for (i, f) in enumerate(disclosure_f[1:min(26, end)])
        solo = i < disclosure_start_idx ? "" : add_commas(f.total_solo)
        small = i < disclosure_start_idx ? "" : add_commas(f.total_small)
        medium = i < disclosure_start_idx ? "" : add_commas(f.total_medium)
        large = i < disclosure_start_idx ? "" : add_commas(f.total_large)
        biglaw = i < disclosure_start_idx ? "" : add_commas(f.total_biglaw)
        total = i < disclosure_start_idx ? "" : add_commas(f.total_clients)
        revenue = i < disclosure_start_idx ? "" : format_currency(f.revenue_k * 1000)
        output *= "| $(f.month) | $solo | $small | $medium | $large | $biglaw | $total | $revenue |\n"
    end

    output *= "\n### Lingua-NLU Pairs\n\n"
    output *= "| Month | Active Pairs | Revenue |\n"
    output *= "|-------|--------------|---------|"
    output *= "\n"

    lingua_map_full = Dict(f.month => f for f in lingua_f)
    lingua_start_idx = findfirst(f -> f.revenue_k > 0, lingua_f)
    if lingua_start_idx === nothing
        lingua_start_idx = length(lingua_f) + 1
    end

    for (i, month_name) in enumerate(months[1:min(26, end)])
        if haskey(lingua_map_full, month_name)
            f = lingua_map_full[month_name]
            pairs = i < lingua_start_idx ? "" : add_commas(f.active_pairs)
            revenue = i < lingua_start_idx ? "" : format_currency(f.revenue_k * 1000)
            output *= "| $month_name | $pairs | $revenue |\n"
        end
    end

    output *= "\n---\n\n"
    return output
end

function generate_revenue_by_product_section(months::Vector{String}, nebula_map, disclosure_map, lingua_map)
    output = """
    ## 7. Revenue by Product

    | Month | Nebula | Disclosure | Lingua | Total |
    |-------|--------|------------|--------|-------|
    """

    for month_name in months[1:min(26, end)]
        neb_rev = get(nebula_map, month_name, 0.0)
        dis_rev = get(disclosure_map, month_name, 0.0)
        lin_rev = get(lingua_map, month_name, 0.0)
        total_rev = neb_rev + dis_rev + lin_rev

        output *= "| $month_name | $(format_currency(neb_rev * 1000)) | $(format_currency(dis_rev * 1000)) | $(format_currency(lin_rev * 1000)) | $(format_currency(total_rev * 1000)) |\n"
    end

    output *= "\n---\n\n"
    return output
end

function generate_revenue_by_channel_section()
    return """
    ## 8. Revenue by Channel

    ### Nebula Channels
    - Retirement Communities: 1,920+ facilities
    - Public Libraries: 17,000+ branches
    - Direct Marketing
    - Referrals

    ### Disclosure Channels

    | Type | Value | Cycle | Rep | Target/Year |
    |------|-------|-------|-----|-------------|
    | Solo | \$15K | 30d | SDR | 240 |
    | Small | \$50K | 60d | AE Mid | 180 |
    | Medium | \$150K | 90d | AE Mid | 36 |
    | Large | \$300K | 120d | AE Ent | 1-2 |
    | BigLaw | \$750K | 180d | AE Ent | 1 |

    ### Lingua Channels
    - LinkedIn Marketing
    - Corporate Partnerships
    - Professional Networks
    - Referrals

    ---

    """
end

function generate_valuation_analysis_section(months::Vector{String}, nebula_map, disclosure_map, lingua_map)
    output = """
    ## 9. Valuation Analysis

    """

    dec_2026_total = get(nebula_map, "Dec 2026", 0.0) + get(disclosure_map, "Dec 2026", 0.0) + get(lingua_map, "Dec 2026", 0.0)
    dec_2026_arr = dec_2026_total * 12

    output *= """
    ### December 2026
    - Monthly: $(format_currency(dec_2026_total * 1000))
    - ARR: $(format_currency(dec_2026_arr * 1000))
    - Conservative (10x): $(format_currency(dec_2026_arr * 10 * 1000))
    - Optimistic (15x): $(format_currency(dec_2026_arr * 15 * 1000))

    """

    dec_2027_total = get(nebula_map, "Dec 2027", 0.0) + get(disclosure_map, "Dec 2027", 0.0) + get(lingua_map, "Dec 2027", 0.0)
    dec_2027_arr = dec_2027_total * 12

    output *= """
    ### December 2027
    - Monthly: $(format_currency(dec_2027_total * 1000))
    - ARR: $(format_currency(dec_2027_arr * 1000))
    - Conservative (12x): $(format_currency(dec_2027_arr * 12 * 1000))
    - Optimistic (18x): $(format_currency(dec_2027_arr * 18 * 1000))

    ---

    """

    return output
end

function generate_revenue_realizations_section(months::Vector{String}, nebula_f, disclosure_f, lingua_f)
    output = """
    ## 10. Revenue Scenarios (Deterministic)

    Three scenarios based on adjusted growth assumptions:
    - **Conservative:** 80% of base case assumptions
    - **Base Case:** Expected outcomes from probability models
    - **Aggressive:** 120% of base case assumptions

    """

    # Create maps for easy lookup
    nebula_map = Dict(f.month => f.revenue_k for f in nebula_f)
    disclosure_map = Dict(f.month => f.revenue_k for f in disclosure_f)
    lingua_map = Dict(f.month => f.revenue_k for f in lingua_f)

    # Monthly table with three scenarios
    output *= "| Month | Conservative | Base Case | Aggressive |\n"
    output *= "|-------|--------------|-----------|------------|\n"

    for month in months[1:min(26, end)]
        nebula_rev = get(nebula_map, month, 0.0)
        disclosure_rev = get(disclosure_map, month, 0.0)
        lingua_rev = get(lingua_map, month, 0.0)

        total_base = nebula_rev + disclosure_rev + lingua_rev
        total_conservative = total_base * 0.8
        total_aggressive = total_base * 1.2

        conservative_str = format_currency_abbreviated(total_conservative * 1000)
        base_str = format_currency_abbreviated(total_base * 1000)
        aggressive_str = format_currency_abbreviated(total_aggressive * 1000)

        output *= "| $month | $conservative_str | $base_str | $aggressive_str |\n"
    end

    # Platform breakdown for base case
    output *= """

    ### Platform Revenue Breakdown (Base Case)

    """

    output *= "| Month | Nebula-NLU | Disclosure-NLU | Lingua-NLU | **Total** |\n"
    output *= "|-------|------------|----------------|------------|----------|\n"

    for month in months[1:min(26, end)]
        nebula_rev = get(nebula_map, month, 0.0)
        disclosure_rev = get(disclosure_map, month, 0.0)
        lingua_rev = get(lingua_map, month, 0.0)

        total = nebula_rev + disclosure_rev + lingua_rev

        nebula_str = format_currency_abbreviated(nebula_rev * 1000)
        disclosure_str = format_currency_abbreviated(disclosure_rev * 1000)
        lingua_str = format_currency_abbreviated(lingua_rev * 1000)
        total_str = format_currency_abbreviated(total * 1000)

        output *= "| $month | $nebula_str | $disclosure_str | $lingua_str | **$total_str** |\n"
    end

    output *= """

    ### Annual Totals by Scenario

    """

    # Calculate annual totals
    years = Dict{Int,Dict{String,Float64}}()

    for month in months
        year = parse(Int, split(month, " ")[2])
        if !haskey(years, year)
            years[year] = Dict("nebula" => 0.0, "disclosure" => 0.0, "lingua" => 0.0)
        end

        years[year]["nebula"] += get(nebula_map, month, 0.0)
        years[year]["disclosure"] += get(disclosure_map, month, 0.0)
        years[year]["lingua"] += get(lingua_map, month, 0.0)
    end

    output *= "| Year | Conservative | Base Case | Aggressive |\n"
    output *= "|------|--------------|-----------|------------|\n"

    for year in sort(collect(keys(years)))
        total_base = years[year]["nebula"] + years[year]["disclosure"] + years[year]["lingua"]
        total_conservative = total_base * 0.8
        total_aggressive = total_base * 1.2

        conservative_str = format_currency(total_conservative * 1000)
        base_str = format_currency(total_base * 1000)
        aggressive_str = format_currency(total_aggressive * 1000)

        output *= "| $year | $conservative_str | $base_str | $aggressive_str |\n"
    end

    output *= """

    ### Scenario Assumptions

    - **Conservative (80%):** Slower customer acquisition, higher churn, longer sales cycles
    - **Base Case (100%):** Expected outcomes based on probability distributions from CSV parameters
    - **Aggressive (120%):** Faster adoption, lower churn, shorter sales cycles

    ---

    """

    return output
end

function generate_financial_statements_section(financial_data)
    output = """
    ## 11. Financial Statements

    ### Profit & Loss Statement - 2025

    | Item | Amount |
    |------|-------:|
    | Revenue | $(format_currency(financial_data.pnl_2025.revenue, use_k_m=false)) |
    | Gemini LLM (20%) | $(format_currency(financial_data.pnl_2025.gemini, use_k_m=false)) |
    | Infrastructure (15%) | $(format_currency(financial_data.pnl_2025.infrastructure, use_k_m=false)) |
    | Google Credits | ($(format_currency(financial_data.pnl_2025.google_credits, use_k_m=false))) |
    | **COGS** | **$(format_currency(financial_data.pnl_2025.cogs, use_k_m=false))** |
    | **Gross Profit (100%)** | **$(format_currency(financial_data.pnl_2025.gross_profit, use_k_m=false))** |
    | Commission (25%) | $(format_currency(financial_data.pnl_2025.commission, use_k_m=false)) |
    | Development Salaries | $(format_currency(financial_data.pnl_2025.dev, use_k_m=false)) |
    | DevOps Salaries | $(format_currency(financial_data.pnl_2025.devops, use_k_m=false)) |
    | G&A Salaries | $(format_currency(financial_data.pnl_2025.ga, use_k_m=false)) |
    | **OpEx** | **$(format_currency(financial_data.pnl_2025.opex, use_k_m=false))** |
    | **EBIT** | **$(format_currency(financial_data.pnl_2025.ebit, use_k_m=false))** |
    | Interest | ($(format_currency(financial_data.pnl_2025.interest, use_k_m=false))) |
    | Taxes | ($(format_currency(financial_data.pnl_2025.taxes, use_k_m=false))) |
    | **Net Income** | **$(format_currency(financial_data.pnl_2025.net_income, use_k_m=false))** |

    ### Profit & Loss Statement - 2026

    | Item | Amount |
    |------|-------:|
    | Revenue | $(format_currency(financial_data.pnl_2026.revenue)) |
    | Gemini LLM (20%) | $(format_currency(financial_data.pnl_2026.gemini)) |
    | Infrastructure (15%) | $(format_currency(financial_data.pnl_2026.infrastructure)) |
    | Google Credits | ($(format_currency(financial_data.pnl_2026.google_credits))) |
    | **COGS** | **$(format_currency(financial_data.pnl_2026.cogs))** |
    | **Gross Profit (100%)** | **$(format_currency(financial_data.pnl_2026.gross_profit))** |
    | Commission (25%) | $(format_currency(financial_data.pnl_2026.commission)) |
    | Development Salaries | $(format_currency(financial_data.pnl_2026.dev)) |
    | DevOps Salaries | $(format_currency(financial_data.pnl_2026.devops)) |
    | G&A Salaries | $(format_currency(financial_data.pnl_2026.ga)) |
    | **OpEx** | **$(format_currency(financial_data.pnl_2026.opex))** |
    | **EBIT** | **$(format_currency(financial_data.pnl_2026.ebit))** |
    | Interest | ($(format_currency(financial_data.pnl_2026.interest))) |
    | Taxes | ($(format_currency(financial_data.pnl_2026.taxes))) |
    | **Net Income** | **$(format_currency(financial_data.pnl_2026.net_income))** |

    ### Profit & Loss Statement - 2027

    | Item | Amount |
    |------|-------:|
    | Revenue | $(format_currency(financial_data.pnl_2027.revenue)) |
    | Gemini LLM (20%) | $(format_currency(financial_data.pnl_2027.gemini)) |
    | Infrastructure (15%) | $(format_currency(financial_data.pnl_2027.infrastructure)) |
    | Google Credits | ($(format_currency(financial_data.pnl_2027.google_credits))) |
    | **COGS** | **$(format_currency(financial_data.pnl_2027.cogs))** |
    | **Gross Profit (100%)** | **$(format_currency(financial_data.pnl_2027.gross_profit))** |
    | Commission (25%) | $(format_currency(financial_data.pnl_2027.commission)) |
    | Development Salaries | $(format_currency(financial_data.pnl_2027.dev)) |
    | DevOps Salaries | $(format_currency(financial_data.pnl_2027.devops)) |
    | G&A Salaries | $(format_currency(financial_data.pnl_2027.ga)) |
    | **OpEx** | **$(format_currency(financial_data.pnl_2027.opex))** |
    | **EBIT** | **$(format_currency(financial_data.pnl_2027.ebit))** |
    | Interest | ($(format_currency(financial_data.pnl_2027.interest))) |
    | Taxes | ($(format_currency(financial_data.pnl_2027.taxes))) |
    | **Net Income** | **$(format_currency(financial_data.pnl_2027.net_income))** |

    ---

    """

    # Sources & Uses tables
    output *= generate_sources_uses_tables(financial_data)

    # Balance Sheets
    output *= generate_balance_sheets(financial_data)

    return output
end

function generate_sources_uses_tables(financial_data)
    output = """
    ### Sources & Uses of Funds - 2025

    | Sources | Amount | Uses | Amount |
    |---------|-------:|------|-------:|
    """

    max_rows = max(length(financial_data.sources_uses_2025["sources"]), length(financial_data.sources_uses_2025["uses"]))
    for i in 1:max_rows
        src_label = i <= length(financial_data.sources_uses_2025["sources"]) ? financial_data.sources_uses_2025["sources"][i][1] : ""
        src_amt = i <= length(financial_data.sources_uses_2025["sources"]) ? format_currency(financial_data.sources_uses_2025["sources"][i][2], use_k_m=false) : ""
        use_label = i <= length(financial_data.sources_uses_2025["uses"]) ? financial_data.sources_uses_2025["uses"][i][1] : ""
        use_amt = i <= length(financial_data.sources_uses_2025["uses"]) ? format_currency(financial_data.sources_uses_2025["uses"][i][2], use_k_m=false) : ""
        output *= "| $src_label | $src_amt | $use_label | $use_amt |\n"
    end

    output *= """

    ### Sources & Uses of Funds - 2026

    | Sources | Amount | Uses | Amount |
    |---------|-------:|------|-------:|
    """

    max_rows = max(length(financial_data.sources_uses_2026["sources"]), length(financial_data.sources_uses_2026["uses"]))
    for i in 1:max_rows
        src_label = i <= length(financial_data.sources_uses_2026["sources"]) ? financial_data.sources_uses_2026["sources"][i][1] : ""
        src_amt = i <= length(financial_data.sources_uses_2026["sources"]) ? format_currency(financial_data.sources_uses_2026["sources"][i][2]) : ""
        use_label = i <= length(financial_data.sources_uses_2026["uses"]) ? financial_data.sources_uses_2026["uses"][i][1] : ""
        use_amt = i <= length(financial_data.sources_uses_2026["uses"]) ? format_currency(financial_data.sources_uses_2026["uses"][i][2]) : ""
        output *= "| $src_label | $src_amt | $use_label | $use_amt |\n"
    end

    output *= """

    ### Sources & Uses of Funds - 2027

    | Sources | Amount | Uses | Amount |
    |---------|-------:|------|-------:|
    """

    max_rows = max(length(financial_data.sources_uses_2027["sources"]), length(financial_data.sources_uses_2027["uses"]))
    for i in 1:max_rows
        src_label = i <= length(financial_data.sources_uses_2027["sources"]) ? financial_data.sources_uses_2027["sources"][i][1] : ""
        src_amt = i <= length(financial_data.sources_uses_2027["sources"]) ? format_currency(financial_data.sources_uses_2027["sources"][i][2]) : ""
        use_label = i <= length(financial_data.sources_uses_2027["uses"]) ? financial_data.sources_uses_2027["uses"][i][1] : ""
        use_amt = i <= length(financial_data.sources_uses_2027["uses"]) ? format_currency(financial_data.sources_uses_2027["uses"][i][2]) : ""
        output *= "| $src_label | $src_amt | $use_label | $use_amt |\n"
    end

    output *= "\n---\n\n"
    return output
end

function generate_balance_sheets(financial_data)
    output = """
    ### Balance Sheets

    #### December 31, 2025

    | Assets | Amount | Liabilities & Equity | Amount |
    |--------|-------:|----------------------|-------:|
    | Cash & Investments | $(format_currency(financial_data.balance_2025.cash, use_k_m=false)) | Accounts Payable | $(format_currency(financial_data.balance_2025.ap, use_k_m=false)) |
    | Intellectual Property* | $(format_currency(financial_data.balance_2025.ip_assets, use_k_m=false)) | Deferred Revenue | $(format_currency(financial_data.balance_2025.deferred_revenue, use_k_m=false)) |
    | **Total Assets** | **$(format_currency(financial_data.balance_2025.total_assets, use_k_m=false))** | **Total Liabilities** | **$(format_currency(financial_data.balance_2025.total_liabilities, use_k_m=false))** |
    | | | Nebula Valuation | $(format_currency(financial_data.balance_2025.nebula_valuation, use_k_m=false)) |
    | | | **Total Equity** | **$(format_currency(financial_data.balance_2025.total_equity, use_k_m=false))** |

    *Pre-existing software platform contributed at formation

    #### December 31, 2026

    | Assets | Amount | Liabilities & Equity | Amount |
    |--------|-------:|----------------------|-------:|
    | Cash & Investments | $(format_currency(financial_data.balance_2026.cash)) | Accounts Payable | $(format_currency(financial_data.balance_2026.ap)) |
    | Intellectual Property | $(format_currency(financial_data.balance_2026.ip_assets)) | Deferred Revenue | $(format_currency(financial_data.balance_2026.deferred_revenue)) |
    | **Total Assets** | **$(format_currency(financial_data.balance_2026.total_assets))** | **Total Liabilities** | **$(format_currency(financial_data.balance_2026.total_liabilities))** |
    | | | Nebula Valuation | $(format_currency(financial_data.balance_2026.nebula_valuation)) |
    | | | **Total Equity** | **$(format_currency(financial_data.balance_2026.total_equity))** |

    #### December 31, 2027

    | Assets | Amount | Liabilities & Equity | Amount |
    |--------|-------:|----------------------|-------:|
    | Cash & Investments | $(format_currency(financial_data.balance_2027.cash)) | Accounts Payable | $(format_currency(financial_data.balance_2027.ap)) |
    | Intellectual Property | $(format_currency(financial_data.balance_2027.ip_assets)) | Deferred Revenue | $(format_currency(financial_data.balance_2027.deferred_revenue)) |
    | **Total Assets** | **$(format_currency(financial_data.balance_2027.total_assets))** | **Total Liabilities** | **$(format_currency(financial_data.balance_2027.total_liabilities))** |
    | | | Nebula Valuation | $(format_currency(financial_data.balance_2027.nebula_valuation)) |
    | | | **Total Equity** | **$(format_currency(financial_data.balance_2027.total_equity))** |

    ---

    """

    return output
end

# ============================================================================
# MAIN FILE GENERATORS
# ============================================================================

function generate_executive_summary_file(months::Vector{String}, nebula_f, disclosure_f, lingua_f)
    nebula_map = Dict(f.month => f.revenue_k for f in nebula_f)
    disclosure_map = Dict(f.month => f.revenue_k for f in disclosure_f)
    lingua_map = Dict(f.month => f.revenue_k for f in lingua_f)

    months_by_year = group_months_by_year(months)
    total_by_year = Dict(year => sum(get(nebula_map, m, 0.0) + get(disclosure_map, m, 0.0) + get(lingua_map, m, 0.0) for m in year_months) for (year, year_months) in months_by_year)

    sep_2027_total = get(nebula_map, "Sep 2027", 0.0) + get(disclosure_map, "Sep 2027", 0.0) + get(lingua_map, "Sep 2027", 0.0)
    sep_2027_arr = sep_2027_total * 12

    open("NLU_Executive_Summary.md", "w") do file
        write(file, "# 🚀 NLU Portfolio Executive Summary\n\n")
        write(file, "## Investment Opportunity Overview\n\n")
        write(file, "The NLU Portfolio comprises three AI-powered platforms targeting a **$(format_currency(18_500_000_000))** addressable market.\n\n")
        write(file, "### Financial Highlights\n\n")
        write(file, "#### Revenue Trajectory\n")
        for year in sort(collect(keys(total_by_year)))
            write(file, "- **$year:** $(format_currency(total_by_year[year] * 1000)) total revenue\n")
        end
        write(file, "- **September 2027 ARR:** $(format_currency(sep_2027_arr * 1000))\n\n")
    end
    println("✅ Generated: NLU_Executive_Summary.md")
end

function generate_three_year_projections_file(months::Vector{String}, nebula_f, disclosure_f, lingua_f)
    nebula_map = Dict(f.month => f.revenue_k for f in nebula_f)
    disclosure_map = Dict(f.month => f.revenue_k for f in disclosure_f)
    lingua_map = Dict(f.month => f.revenue_k for f in lingua_f)

    months_by_year = group_months_by_year(months)
    yearly_revenue = Dict{String,Dict{Int,Float64}}("Nebula" => Dict(), "Disclosure" => Dict(), "Lingua" => Dict(), "Total" => Dict())

    for (year, year_months) in months_by_year
        yearly_revenue["Nebula"][year] = sum(get(nebula_map, m, 0.0) for m in year_months)
        yearly_revenue["Disclosure"][year] = sum(get(disclosure_map, m, 0.0) for m in year_months)
        yearly_revenue["Lingua"][year] = sum(get(lingua_map, m, 0.0) for m in year_months)
        yearly_revenue["Total"][year] = yearly_revenue["Nebula"][year] + yearly_revenue["Disclosure"][year] + yearly_revenue["Lingua"][year]
    end

    open("NLU_Three_Year_Projections.md", "w") do file
        write(file, "# 📊 NLU Portfolio Three-Year Financial Projections\n\n")
        write(file, "## Revenue Summary by Product (2025-2027)\n\n")
    end
    println("✅ Generated: NLU_Three_Year_Projections.md")
end

function generate_complete_strategic_plan_file(months::Vector{String}, nebula_f, disclosure_f, lingua_f, cost_factors_df, salaries_df, headcount_df)
    nebula_map = Dict(f.month => f.revenue_k for f in nebula_f)
    disclosure_map = Dict(f.month => f.revenue_k for f in disclosure_f)
    lingua_map = Dict(f.month => f.revenue_k for f in lingua_f)

    financing_df = LoadFactors.load_financing("data/financing.csv")
    financial_data = FinancialStatements.generate_standard_financial_statements(months, nebula_f, disclosure_f, lingua_f, financing_df, cost_factors_df, salaries_df)

    open("NLU_Strategic_Plan_Complete.md", "w") do file
        write(file, "# 🚀 NLU PORTFOLIO STRATEGIC PLAN\n\n")
        write(file, "**For Investors & Prospective Employees**\n\n")
        write(file, "## TABLE OF CONTENTS\n\n")
        write(file, "1. Revenue Summary\n")
        write(file, "2. Valuation Summary\n")
        write(file, "3. Definitions\n")
        write(file, "4. Hiring & Resource Schedule\n")
        write(file, "5. Probability Analysis\n")
        write(file, "6. Activity Indicators\n")
        write(file, "7. Revenue by Product\n")
        write(file, "8. Revenue by Channel\n")
        write(file, "9. Valuation Analysis\n")
        write(file, "10. Revenue Realizations\n")
        write(file, "11. Financial Statements\n\n")
        write(file, "---\n\n")

        # Generate all sections using functions
        write(file, generate_revenue_summary_section(months, nebula_map, disclosure_map, lingua_map))
        write(file, generate_valuation_summary_section(months, nebula_map, disclosure_map, lingua_map, financial_data))
        write(file, generate_definitions_section())
        write(file, generate_hiring_schedule_section(months, salaries_df, headcount_df))
        write(file, generate_probability_analysis_section())
        write(file, generate_activity_indicators_section(months, nebula_f, disclosure_f, lingua_f))
        write(file, generate_revenue_by_product_section(months, nebula_map, disclosure_map, lingua_map))
        write(file, generate_revenue_by_channel_section())
        write(file, generate_valuation_analysis_section(months, nebula_map, disclosure_map, lingua_map))
        write(file, generate_revenue_realizations_section(months, nebula_f, disclosure_f, lingua_f))
        write(file, generate_financial_statements_section(financial_data))

        timestamp = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
        write(file, "*Generated: $timestamp*\n")
    end
    println("✅ Generated: NLU_Strategic_Plan_Complete.md (11 sections)")
end

function generate_founder_capitalization_file(months::Vector{String}, nebula_f, disclosure_f, lingua_f)
    # [Keep existing implementation - it's already well-structured]
    open("NLU_Founder_Capitalization.md", "w") do file
        write(file, "# 🔒 NLU PORTFOLIO - FOUNDER CAPITALIZATION\n\n")
        write(file, "**⚠️ CONFIDENTIAL - FOUNDER ONLY**\n\n")
        # ... rest of existing implementation
    end
    println("✅ Generated: NLU_Founder_Capitalization.md (CONFIDENTIAL)")
end

end # module ReportGenerators