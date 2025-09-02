module FinancialAnalysis

using DataFrames, CSV, Random
using ..LoadFactors, ..StochasticModel, ..PresentationOutput

export generate_financial_statements, FinancialResults

struct FinancialResults
    pnl_statement::DataFrame
    sources_uses_2025::DataFrame
    sources_uses_2026::DataFrame
    sources_uses_2027::DataFrame
    balance_sheet::DataFrame
end

function calculate_salary_costs(plan::ResourcePlan)
    """
    Calculate monthly salary costs from resource plan
    Only experienced developers and marketers at 8k per month
    """
    monthly_salaries = Dict{String,Float64}()

    exp_rate = 8.0  # 8k per month per experienced person
    intern_rate = 0.0  # Interns are not paid in this model

    for (i, month) in enumerate(plan.months)
        dev_salaries = plan.experienced_devs[i] * exp_rate + plan.intern_devs[i] * intern_rate
        marketing_salaries = plan.experienced_marketers[i] * exp_rate + plan.intern_marketers[i] * intern_rate

        monthly_salaries[month] = dev_salaries + marketing_salaries
    end

    return monthly_salaries
end

function calculate_deferred_salaries(pnl_data, salary_costs::Dict{String,Float64}, cost_factors::DataFrame)
    """
    Track deferred salaries based on cash flow availability
    """
    deferred_balance = 0.0
    monthly_deferred = Dict{String,Float64}()

    for row in pnl_data
        month = row["Month"]
        monthly_cash_flow = row["PnL"]
        total_salary_need = get(salary_costs, month, 0.0)

        if monthly_cash_flow >= total_salary_need
            # Can pay current salaries and reduce deferred balance
            cash_after_salaries = monthly_cash_flow - total_salary_need
            payment_to_deferred = min(deferred_balance, cash_after_salaries)
            deferred_balance = deferred_balance - payment_to_deferred
        else
            # Cannot cover all salaries, defer the difference
            salary_deficit = total_salary_need - max(monthly_cash_flow, 0.0)
            deferred_balance += salary_deficit
        end

        monthly_deferred[month] = deferred_balance
    end

    return monthly_deferred
end

function calculate_monthly_pnl(plan::ResourcePlan, nebula_f, disclosure_f, lingua_f, cost_factors::DataFrame, salary_costs::Dict{String,Float64})
    """
    Calculate monthly P&L with operating salaries as separate line item
    """

    # Get cost factor lookup with error handling
    cost_lookup = Dict()
    for row in eachrow(cost_factors)
        try
            pct_revenue = parse(Float64, string(row.Percentage_of_Revenue))
            fixed_amount = parse(Float64, string(row.Fixed_Monthly_Amount))
            cost_lookup[row.Cost_Factor] = (pct_revenue, fixed_amount)
        catch e
            println("ERROR parsing row: $(row.Cost_Factor)")
            # Use defaults from business logic
            if row.Cost_Factor == "Gemini_LLM"
                cost_lookup[row.Cost_Factor] = (0.20, 0.0)
            elseif row.Cost_Factor == "Google_Cloud_Infrastructure"
                cost_lookup[row.Cost_Factor] = (0.15, 0.0)
            elseif row.Cost_Factor == "Subsidiary_Costs"
                cost_lookup[row.Cost_Factor] = (0.0, 8.0)
            elseif row.Cost_Factor == "Administration_Salaries"
                cost_lookup[row.Cost_Factor] = (0.0, 8.0)
            else
                cost_lookup[row.Cost_Factor] = (0.0, 0.0)
            end
        end
    end

    # Force subsidiary costs if parsing failed
    if !haskey(cost_lookup, "Subsidiary_Costs") || cost_lookup["Subsidiary_Costs"][2] == 0.0
        cost_lookup["Subsidiary_Costs"] = (0.0, 8.0)
        println("FIXED: Hardcoded subsidiary costs to \$8k")
    end

    pnl_data = []

    # Create revenue maps
    nebula_map = Dict(f.month => f.revenue_k for f in nebula_f)
    disclosure_map = Dict(f.month => f.revenue_k for f in disclosure_f)
    lingua_map = Dict(f.month => f.revenue_k for f in lingua_f)

    for month in plan.months
        # Revenue calculations (no multipliers)
        nebula_rev = get(nebula_map, month, 0.0)
        disclosure_rev = get(disclosure_map, month, 0.0)
        lingua_rev = get(lingua_map, month, 0.0)
        total_revenue = nebula_rev + disclosure_rev + lingua_rev

        # Variable costs (only infrastructure)
        gemini_cost = total_revenue * cost_lookup["Gemini_LLM"][1]  # 20% * revenue
        cloud_cost = total_revenue * cost_lookup["Google_Cloud_Infrastructure"][1]  # 15% * revenue
        total_infrastructure = gemini_cost + cloud_cost

        # Fixed costs (non-salary)
        subsidiary_costs = cost_lookup["Subsidiary_Costs"][2]  # Fixed $8k

        # Google Credits offset infrastructure costs (100% gross margin)
        google_startup_credits = -total_infrastructure  # Exact offset

        # GROSS MARGIN (Revenue - Variable Costs, excluding salaries)
        gross_margin = total_revenue - total_infrastructure - google_startup_credits
        gross_margin_pct = total_revenue > 0 ? (gross_margin / total_revenue) * 100 : 100.0

        # OPERATING EXPENSES (separate line item)
        operating_salaries = get(salary_costs, month, 0.0)
        total_operating_expenses = operating_salaries + subsidiary_costs

        # NET OPERATING INCOME
        net_operating_income = gross_margin - total_operating_expenses

        push!(pnl_data, Dict(
            "Month" => month,
            "NebulaRevenue" => nebula_rev,
            "DisclosureRevenue" => disclosure_rev,
            "LinguaRevenue" => lingua_rev,
            "TotalRevenue" => total_revenue,
            "GeminiLLM" => gemini_cost,
            "GoogleCloudInfrastructure" => cloud_cost,
            "TotalInfrastructure" => total_infrastructure,
            "GoogleStartupCredits" => google_startup_credits,
            "GrossMargin" => gross_margin,
            "GrossMarginPct" => gross_margin_pct,
            "OperatingSalaries" => operating_salaries,
            "SubsidiaryCosts" => subsidiary_costs,
            "TotalOperatingExpenses" => total_operating_expenses,
            "NetOperatingIncome" => net_operating_income,
            "PnL" => net_operating_income
        ))
    end

    return pnl_data
end

function calculate_period_aggregates(pnl_data)
    """
    Calculate quarterly and annual aggregates for extended P&L reporting
    """
    aggregates = Dict()

    # Define period mappings
    quarters = Dict(
        "2026_Q1" => ["Jan 2026", "Feb 2026", "Mar 2026"],
        "2026_Q2" => ["Apr 2026", "May 2026", "Jun 2026"],
        "2026_Q3" => ["Jul 2026", "Aug 2026", "Sep 2026"],
        "2026_Q4" => ["Oct 2026", "Nov 2026", "Dec 2026"]
    )

    # 2027 full year (all 12 months)
    months_2027 = ["Jan 2027", "Feb 2027", "Mar 2027", "Apr 2027", "May 2027", "Jun 2027",
        "Jul 2027", "Aug 2027", "Sep 2027", "Oct 2027", "Nov 2027", "Dec 2027"]

    # Calculate quarterly aggregates for 2026
    for (quarter_name, months) in quarters
        quarter_data = filter(row -> row["Month"] in months, pnl_data)

        if !isempty(quarter_data)
            aggregates[quarter_name] = Dict()
            for key in keys(quarter_data[1])
                if key != "Month" && key != "GrossMarginPct"
                    aggregates[quarter_name][key] = sum(row[key] for row in quarter_data)
                end
            end

            # Calculate quarter gross margin percentage
            total_rev = aggregates[quarter_name]["TotalRevenue"]
            total_margin = aggregates[quarter_name]["GrossMargin"]
            aggregates[quarter_name]["GrossMarginPct"] = total_rev > 0 ? (total_margin / total_rev) * 100 : 100.0
        end
    end

    # Calculate 2027 full year aggregate
    year_2027_data = filter(row -> row["Month"] in months_2027, pnl_data)

    if !isempty(year_2027_data)
        aggregates["2027_Full"] = Dict()
        for key in keys(year_2027_data[1])
            if key != "Month" && key != "GrossMarginPct"
                aggregates["2027_Full"][key] = sum(row[key] for row in year_2027_data)
            end
        end

        # Calculate annual gross margin percentage
        total_rev = aggregates["2027_Full"]["TotalRevenue"]
        total_margin = aggregates["2027_Full"]["GrossMargin"]
        aggregates["2027_Full"]["GrossMarginPct"] = total_rev > 0 ? (total_margin / total_rev) * 100 : 100.0
    end

    return aggregates
end

function aggregate_periods(pnl_data)
    """
    Aggregate monthly data into required periods - Updated for 2027
    """
    aggregates = Dict()

    # 2025: Sep, Oct, Nov, Dec only
    months_2025 = ["Sep 2025", "Oct 2025", "Nov 2025", "Dec 2025"]
    data_2025 = filter(row -> row["Month"] in months_2025, pnl_data)

    if !isempty(data_2025)
        aggregates["Total_2025"] = Dict()
        for key in keys(data_2025[1])
            if key != "Month" && key != "GrossMarginPct"
                aggregates["Total_2025"][key] = sum(row[key] for row in data_2025)
            end
        end
        # Calculate aggregate margin percentage
        total_rev = aggregates["Total_2025"]["TotalRevenue"]
        total_margin = aggregates["Total_2025"]["GrossMargin"]
        aggregates["Total_2025"]["GrossMarginPct"] = total_rev > 0 ? (total_margin / total_rev) * 100 : 100.0
    end

    # 2026: All 12 months
    months_2026 = ["Jan 2026", "Feb 2026", "Mar 2026", "Apr 2026", "May 2026", "Jun 2026",
        "Jul 2026", "Aug 2026", "Sep 2026", "Oct 2026", "Nov 2026", "Dec 2026"]
    data_2026 = filter(row -> row["Month"] in months_2026, pnl_data)

    if !isempty(data_2026)
        aggregates["Total_2026"] = Dict()
        for key in keys(data_2026[1])
            if key != "Month" && key != "GrossMarginPct"
                aggregates["Total_2026"][key] = sum(row[key] for row in data_2026)
            end
        end
        # Calculate aggregate margin percentage
        total_rev = aggregates["Total_2026"]["TotalRevenue"]
        total_margin = aggregates["Total_2026"]["GrossMargin"]
        aggregates["Total_2026"]["GrossMarginPct"] = total_rev > 0 ? (total_margin / total_rev) * 100 : 100.0
    end

    # 2027: All 12 months
    months_2027 = ["Jan 2027", "Feb 2027", "Mar 2027", "Apr 2027", "May 2027", "Jun 2027",
        "Jul 2027", "Aug 2027", "Sep 2027", "Oct 2027", "Nov 2027", "Dec 2027"]
    data_2027 = filter(row -> row["Month"] in months_2027, pnl_data)

    if !isempty(data_2027)
        aggregates["Total_2027"] = Dict()
        for key in keys(data_2027[1])
            if key != "Month" && key != "GrossMarginPct"
                aggregates["Total_2027"][key] = sum(row[key] for row in data_2027)
            end
        end
        # Calculate aggregate margin percentage
        total_rev = aggregates["Total_2027"]["TotalRevenue"]
        total_margin = aggregates["Total_2027"]["GrossMargin"]
        aggregates["Total_2027"]["GrossMarginPct"] = total_rev > 0 ? (total_margin / total_rev) * 100 : 100.0
    end

    return aggregates
end

function create_sources_uses_statements(pnl_aggregates)
    """
    Create Sources & Uses statements for 2025, 2026, and 2027
    """

    # 2025 Sources & Uses
    pnl_2025 = get(pnl_aggregates, "Total_2025", Dict("PnL" => 0.0))["PnL"]

    sources_2025 = DataFrame(
        Sources_of_Funds=["2025 P&L", "Founder Opportunity Cost", "Founder Cash Contribution",
            "Google Credits", "Rainforest", "TOTAL"],
        Amount_k=[pnl_2025, 303, 58, 25, 10, pnl_2025 + 303 + 58 + 25 + 10]
    )

    uses_2025 = DataFrame(
        Uses_of_Funds=["Operations", "NLU MVP Development", "Working Capital", "Infrastructure", "Marketing", "TOTAL"],
        Amount_k=[pnl_2025, 303, 58, 25, 10, pnl_2025 + 303 + 58 + 25 + 10]
    )

    # 2026 Sources & Uses  
    pnl_2026 = get(pnl_aggregates, "Total_2026", Dict("PnL" => 0.0))["PnL"]

    sources_2026 = DataFrame(
        Sources_of_Funds=["2026 P&L", "Seed Capital", "Series A", "Founder Opportunity Cost",
            "Founder Cash Contribution", "Google Credits", "TOTAL"],
        Amount_k=[pnl_2026, 250, 1000, 63, 20, 350, pnl_2026 + 250 + 1000 + 63 + 20 + 350]
    )

    uses_2026 = DataFrame(
        Uses_of_Funds=["Operations", "Expansion & Development", "Cash Reserve", "Product Development",
            "Marketing Scale", "Infrastructure", "TOTAL"],
        Amount_k=[pnl_2026, 250, 1000, 63, 20, 350, pnl_2026 + 250 + 1000 + 63 + 20 + 350]
    )

    # 2027 Sources & Uses
    pnl_2027 = get(pnl_aggregates, "Total_2027", Dict("PnL" => 0.0))["PnL"]

    sources_2027 = DataFrame(
        Sources_of_Funds=["2027 P&L", "Series B", "Strategic Partnerships", "Founder Opportunity Cost",
            "Founder Cash Contribution", "Google Credits", "TOTAL"],
        Amount_k=[pnl_2027, 5000, 2000, 75, 25, 500, pnl_2027 + 5000 + 2000 + 75 + 25 + 500]
    )

    uses_2027 = DataFrame(
        Uses_of_Funds=["Operations", "International Expansion", "Acquisition Fund", "R&D Investment",
            "Marketing & Sales", "Infrastructure Scale", "TOTAL"],
        Amount_k=[pnl_2027, 5000, 2000, 75, 25, 500, pnl_2027 + 5000 + 2000 + 75 + 25 + 500]
    )

    return sources_2025, uses_2025, sources_2026, uses_2026, sources_2027, uses_2027
end

function create_balance_sheet(sources_2025, sources_2026, sources_2027, deferred_salaries_end_2025, deferred_salaries_end_2026, deferred_salaries_end_2027, pnl_aggregates)
    """
    Create consolidated Balance Sheet with 2027 data and updated valuations
    """

    # Calculate cumulative cash positions
    net_sources_2025 = sum(sources_2025.Amount_k[1:end-1])  # Exclude total row
    net_sources_2026 = sum(sources_2026.Amount_k[1:end-1])
    net_sources_2027 = sum(sources_2027.Amount_k[1:end-1])

    # Progressive cash management strategy
    # 2025: Conservative
    cash_2025 = min(net_sources_2025, 100.0)  # Keep $100k in operating cash
    short_term_inv_2025 = max(net_sources_2025 - 100.0, 0.0)
    investment_yield_2025 = short_term_inv_2025 * 0.05  # 5% annual yield

    # 2026: Growth phase
    total_available_2026 = net_sources_2025 + net_sources_2026 + investment_yield_2025
    cash_2026 = min(total_available_2026, 500.0)  # Keep $500k for operations
    short_term_inv_2026 = max(total_available_2026 - 500.0, 0.0)
    investment_yield_2026 = short_term_inv_2026 * 0.06  # 6% yield on larger amounts

    # 2027: Scale phase
    total_available_2027 = total_available_2026 + net_sources_2027 + investment_yield_2026
    cash_2027 = min(total_available_2027, 1000.0)  # Keep $1M for operations
    short_term_inv_2027 = max(total_available_2027 - 1000.0, 0.0)
    strategic_investments_2027 = short_term_inv_2027 * 0.3  # 30% in strategic investments
    safe_investments_2027 = short_term_inv_2027 * 0.7  # 70% in safe investments

    total_assets_2025 = cash_2025 + short_term_inv_2025
    total_assets_2026 = cash_2026 + short_term_inv_2026
    total_assets_2027 = cash_2027 + strategic_investments_2027 + safe_investments_2027

    # Calculate company valuations based on performance
    pnl_2026 = get(pnl_aggregates, "Total_2026", Dict("PnL" => 0.0))["PnL"]
    pnl_2027 = get(pnl_aggregates, "Total_2027", Dict("PnL" => 0.0))["PnL"]

    # Valuation multiples increase with scale
    company_valuation_2026 = pnl_2026 * 10.0  # 10x earnings multiple
    company_valuation_2027 = pnl_2027 * 15.0  # 15x earnings multiple (mature SaaS)

    # 1% ownership values
    ownership_value_2026 = company_valuation_2026 * 0.01
    ownership_value_2027 = company_valuation_2027 * 0.01

    # Cumulative founder contributions
    founder_opportunity_cost_total = 303 + 63 + 75  # 2025 + 2026 + 2027
    founder_cash_total = 58 + 20 + 25  # 2025 + 2026 + 2027

    # Calculate retained earnings
    retained_earnings_2025 = total_assets_2025 - deferred_salaries_end_2025 - founder_opportunity_cost_total - founder_cash_total
    retained_earnings_2026 = total_assets_2026 - deferred_salaries_end_2026 - founder_opportunity_cost_total - founder_cash_total
    retained_earnings_2027 = total_assets_2027 - deferred_salaries_end_2027 - founder_opportunity_cost_total - founder_cash_total

    balance_sheet = DataFrame(
        Account=[
            "ASSETS", "Cash", "Short-term Investments", "Strategic Investments", "Total Assets", "",
            "LIABILITIES", "Accrued Liabilities (Deferred Salaries)", "Total Liabilities", "",
            "EQUITY", "Founder Opportunity Cost", "Founder Cash Contributions", "Retained Earnings", "Total Equity", "",
            "TOTAL LIABILITIES + EQUITY", "",
            "VALUATION ANALYSIS", "Annual Earnings", "Valuation Multiple", "Company Valuation", "1% Ownership Value"
        ],
        End_2025_k=[
            "", cash_2025, short_term_inv_2025, 0.0, total_assets_2025, "",
            "", deferred_salaries_end_2025, deferred_salaries_end_2025, "",
            "", founder_opportunity_cost_total, founder_cash_total, retained_earnings_2025, total_assets_2025 - deferred_salaries_end_2025, "",
            total_assets_2025, "",
            "", "N/A", "N/A", "N/A", "N/A"
        ],
        End_2026_k=[
            "", cash_2026, short_term_inv_2026, 0.0, total_assets_2026, "",
            "", deferred_salaries_end_2026, deferred_salaries_end_2026, "",
            "", founder_opportunity_cost_total, founder_cash_total, retained_earnings_2026, total_assets_2026 - deferred_salaries_end_2026, "",
            total_assets_2026, "",
            "", pnl_2026, "10x", company_valuation_2026, ownership_value_2026
        ],
        End_2027_k=[
            "", cash_2027, safe_investments_2027, strategic_investments_2027, total_assets_2027, "",
            "", deferred_salaries_end_2027, deferred_salaries_end_2027, "",
            "", founder_opportunity_cost_total, founder_cash_total, retained_earnings_2027, total_assets_2027 - deferred_salaries_end_2027, "",
            total_assets_2027, "",
            "", pnl_2027, "15x", company_valuation_2027, ownership_value_2027
        ]
    )

    return balance_sheet
end

function generate_financial_statements(plan::ResourcePlan, nebula_f, disclosure_f, lingua_f)
    # Ensure output directory exists
    if !isdir("output")
        mkdir("output")
        println("📁 Created output directory")
    end

    # Load cost factors using the LoadFactors module function
    cost_factors = load_cost_factors()

    # Calculate salary costs from resource plan
    salary_costs = calculate_salary_costs(plan)

    # Calculate monthly P&L with updated pricing
    pnl_data = calculate_monthly_pnl(plan, nebula_f, disclosure_f, lingua_f, cost_factors, salary_costs)

    # Calculate deferred salaries tracking
    deferred_salaries = calculate_deferred_salaries(pnl_data, salary_costs, cost_factors)

    # Aggregate into periods (including 2027)
    pnl_aggregates = aggregate_periods(pnl_data)

    # Get deferred salary balances for balance sheet
    deferred_end_2025 = get(deferred_salaries, "Dec 2025", 0.0)
    deferred_end_2026 = get(deferred_salaries, "Dec 2026", 0.0)
    deferred_end_2027 = get(deferred_salaries, "Dec 2027", 0.0)

    println("\n\n💰 PROFIT & LOSS STATEMENT")
    println("="^50)
    println("(Updated pricing: Nebula \$20/\$60, Disclosure firm-based)")
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")

    # UPDATED HEADER: 2025 months + 2026 quarters + 2027 full year
    selected_periods = ["Oct 2025", "Nov 2025", "Dec 2025", "2026 Q1", "2026 Q2", "2026 Q3", "2026 Q4", "2027 Full Year"]
    header = "Component\t" * join(selected_periods, "\t")
    println(header)

    # Calculate quarterly and annual aggregates
    period_aggregates = calculate_period_aggregates(pnl_data)

    # Print revenue components
    revenue_components = ["NebulaRevenue", "DisclosureRevenue", "LinguaRevenue", "TotalRevenue"]
    for component in revenue_components
        values = []

        # 2025 months (Oct, Nov, Dec)
        for month in ["Oct 2025", "Nov 2025", "Dec 2025"]
            month_data = findfirst(row -> row["Month"] == month, pnl_data)
            if month_data !== nothing
                push!(values, round(pnl_data[month_data][component], digits=1))
            else
                push!(values, 0.0)
            end
        end

        # 2026 quarters
        for quarter in ["2026_Q1", "2026_Q2", "2026_Q3", "2026_Q4"]
            if haskey(period_aggregates, quarter)
                push!(values, round(period_aggregates[quarter][component], digits=1))
            else
                push!(values, 0.0)
            end
        end

        # 2027 full year
        if haskey(period_aggregates, "2027_Full")
            push!(values, round(period_aggregates["2027_Full"][component], digits=1))
        else
            push!(values, 0.0)
        end

        values_str = join(values, "\t")
        println("$component\t$values_str")
    end

    println("")  # Blank line
    println("Variable Costs")

    # Variable cost components
    cost_components = ["GeminiLLM", "GoogleCloudInfrastructure", "TotalInfrastructure",
        "GoogleStartupCredits", "GrossMargin", "GrossMarginPct"]

    for component in cost_components
        values = []

        # 2025 months
        for month in ["Oct 2025", "Nov 2025", "Dec 2025"]
            month_data = findfirst(row -> row["Month"] == month, pnl_data)
            if month_data !== nothing
                val = pnl_data[month_data][component]
                if component == "GrossMarginPct"
                    push!(values, string(round(val, digits=1)) * "%")
                else
                    push!(values, round(val, digits=1))
                end
            else
                push!(values, component == "GrossMarginPct" ? "100.0%" : 0.0)
            end
        end

        # 2026 quarters
        for quarter in ["2026_Q1", "2026_Q2", "2026_Q3", "2026_Q4"]
            if haskey(period_aggregates, quarter)
                val = period_aggregates[quarter][component]
                if component == "GrossMarginPct"
                    push!(values, string(round(val, digits=1)) * "%")
                else
                    push!(values, round(val, digits=1))
                end
            else
                push!(values, component == "GrossMarginPct" ? "100.0%" : 0.0)
            end
        end

        # 2027 full year
        if haskey(period_aggregates, "2027_Full")
            val = period_aggregates["2027_Full"][component]
            if component == "GrossMarginPct"
                push!(values, string(round(val, digits=1)) * "%")
            else
                push!(values, round(val, digits=1))
            end
        else
            push!(values, component == "GrossMarginPct" ? "100.0%" : 0.0)
        end

        values_str = join(values, "\t")
        println("$component\t$values_str")
    end

    println("")  # Blank line
    println("Operating Expenses")

    # Operating expense components
    operating_components = ["OperatingSalaries", "SubsidiaryCosts", "TotalOperatingExpenses",
        "NetOperatingIncome", "PnL"]

    for component in operating_components
        values = []

        # 2025 months
        for month in ["Oct 2025", "Nov 2025", "Dec 2025"]
            month_data = findfirst(row -> row["Month"] == month, pnl_data)
            if month_data !== nothing
                push!(values, round(pnl_data[month_data][component], digits=1))
            else
                push!(values, 0.0)
            end
        end

        # 2026 quarters
        for quarter in ["2026_Q1", "2026_Q2", "2026_Q3", "2026_Q4"]
            if haskey(period_aggregates, quarter)
                push!(values, round(period_aggregates[quarter][component], digits=1))
            else
                push!(values, 0.0)
            end
        end

        # 2027 full year
        if haskey(period_aggregates, "2027_Full")
            push!(values, round(period_aggregates["2027_Full"][component], digits=1))
        else
            push!(values, 0.0)
        end

        values_str = join(values, "\t")
        println("$component\t$values_str")
    end

    println("```")

    # Generate Sources & Uses (now includes 2027)
    sources_2025, uses_2025, sources_2026, uses_2026, sources_2027, uses_2027 = create_sources_uses_statements(pnl_aggregates)

    println("\n\n💼 SOURCES & USES OF FUNDS")
    println("="^40)

    println("\n📊 2025 SOURCES & USES")
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")
    println("Sources of Funds\tAmount (k\$)\tUses of Funds\tAmount (k\$)")
    for i in 1:nrow(sources_2025)
        println("$(sources_2025.Sources_of_Funds[i])\t$(round(sources_2025.Amount_k[i], digits=1))\t$(uses_2025.Uses_of_Funds[i])\t$(round(uses_2025.Amount_k[i], digits=1))")
    end
    println("```")

    println("\n📊 2026 SOURCES & USES")
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")
    println("Sources of Funds\tAmount (k\$)\tUses of Funds\tAmount (k\$)")
    for i in 1:nrow(sources_2026)
        println("$(sources_2026.Sources_of_Funds[i])\t$(round(sources_2026.Amount_k[i], digits=1))\t$(uses_2026.Uses_of_Funds[i])\t$(round(uses_2026.Amount_k[i], digits=1))")
    end
    println("```")

    println("\n📊 2027 SOURCES & USES")
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")
    println("Sources of Funds\tAmount (k\$)\tUses of Funds\tAmount (k\$)")
    for i in 1:nrow(sources_2027)
        println("$(sources_2027.Sources_of_Funds[i])\t$(round(sources_2027.Amount_k[i], digits=1))\t$(uses_2027.Uses_of_Funds[i])\t$(round(uses_2027.Amount_k[i], digits=1))")
    end
    println("```")

    # Generate Balance Sheet (now includes 2027)
    balance_sheet = create_balance_sheet(sources_2025, sources_2026, sources_2027, deferred_end_2025, deferred_end_2026, deferred_end_2027, pnl_aggregates)

    println("\n\n🏛️ BALANCE SHEET")
    println("="^30)
    println("(Three-year progression with strategic investments)")
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")
    println("Account\tEnd 2025 (k\$)\tEnd 2026 (k\$)\tEnd 2027 (k\$)")
    for i in 1:nrow(balance_sheet)
        end_2025_val = balance_sheet.End_2025_k[i]
        end_2026_val = balance_sheet.End_2026_k[i]
        end_2027_val = balance_sheet.End_2027_k[i]

        # Format numeric values
        vals = [end_2025_val, end_2026_val, end_2027_val]
        formatted_vals = []

        for val in vals
            if isa(val, Number) && val != 0
                push!(formatted_vals, string(round(val, digits=1)))
            else
                push!(formatted_vals, string(val))
            end
        end

        println("$(balance_sheet.Account[i])\t$(formatted_vals[1])\t$(formatted_vals[2])\t$(formatted_vals[3])")
    end
    println("```")

    # Print extended deferred salary summary
    println("\n\n📋 DEFERRED SALARY TRACKING")
    println("="^30)
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")
    println("Month\tDeferred Balance (k\$)")
    selected_deferred_months = ["Dec 2025", "Jun 2026", "Dec 2026", "Jun 2027", "Dec 2027"]
    for month in selected_deferred_months
        if haskey(deferred_salaries, month)
            println("$month\t$(round(deferred_salaries[month], digits=1))")
        end
    end
    println("```")

    # Save outputs (updated structure)
    pnl_df = DataFrame(pnl_data)
    CSV.write("output/monthly_pnl_with_deferred_salaries.csv", pnl_df)
    CSV.write("output/sources_uses_2025.csv", hcat(sources_2025, uses_2025, makeunique=true))
    CSV.write("output/sources_uses_2026.csv", hcat(sources_2026, uses_2026, makeunique=true))
    CSV.write("output/sources_uses_2027.csv", hcat(sources_2027, uses_2027, makeunique=true))
    CSV.write("output/balance_sheet_three_year.csv", balance_sheet)

    # Save deferred salary tracking
    deferred_df = DataFrame(Month=collect(keys(deferred_salaries)), Deferred_Balance_k=collect(values(deferred_salaries)))
    CSV.write("output/deferred_salary_tracking.csv", deferred_df)

    println("\n✅ Comprehensive three-year financial statements generated:")
    println("   • output/monthly_pnl_with_deferred_salaries.csv")
    println("   • output/sources_uses_2025.csv")
    println("   • output/sources_uses_2026.csv")
    println("   • output/sources_uses_2027.csv (NEW)")
    println("   • output/balance_sheet_three_year.csv")
    println("   • output/deferred_salary_tracking.csv")

    # FIXED: Return statement with correct number of parameters (5 not 4)
    return FinancialResults(
        pnl_df,
        hcat(sources_2025, uses_2025, makeunique=true),
        hcat(sources_2026, uses_2026, makeunique=true),
        hcat(sources_2027, uses_2027, makeunique=true),  # NEW: 2027 sources & uses
        balance_sheet
    )
end

end # module FinancialAnalysis