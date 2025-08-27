# financial_analysis.jl
module FinancialAnalysis

using DataFrames, CSV, Random
using ..LoadFactors, ..StochasticModel, ..PresentationOutput

export generate_financial_statements, FinancialResults

struct FinancialResults
    pnl_statement::DataFrame
    sources_uses_2025::DataFrame
    sources_uses_2026::DataFrame
    balance_sheet::DataFrame
end

function ensure_output_directory()
    if !isdir("output")
        mkdir("output")
        println("📁 Created output directory")
    end
end

function calculate_salary_costs(plan::ResourcePlan)
    """
    Calculate monthly salary costs from resource plan
    """
    monthly_salaries = Dict{String,Float64}()

    # Assume $120k annually for experienced, $60k for interns
    exp_dev_rate = 120.0 / 12  # $10k per month
    intern_rate = 60.0 / 12    # $5k per month

    for (i, month) in enumerate(plan.months)
        dev_salaries = plan.experienced_devs[i] * exp_dev_rate + plan.intern_devs[i] * intern_rate
        marketing_salaries = plan.experienced_marketers[i] * exp_dev_rate + plan.intern_marketers[i] * intern_rate

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

    # Get admin salary amount
    admin_salary_monthly = 0.0
    for row in eachrow(cost_factors)
        if row.Cost_Factor == "Administration_Salaries"
            admin_salary_monthly = row.Fixed_Monthly_Amount
            break
        end
    end

    for row in pnl_data
        month = row["Month"]
        monthly_cash_flow = row["PnL"]
        total_salary_need = get(salary_costs, month, 0.0) + admin_salary_monthly

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
    Calculate monthly P&L using deterministic revenue with twenty dollar Nebula price
    """

    # Get cost factor lookup
    cost_lookup = Dict(row.Cost_Factor => (row.Percentage_of_Revenue, row.Fixed_Monthly_Amount)
                       for row in eachrow(cost_factors))

    pnl_data = []

    # Create revenue maps
    nebula_map = Dict(f.month => f.revenue_k for f in nebula_f)
    disclosure_map = Dict(f.month => f.revenue_k for f in disclosure_f)
    lingua_map = Dict(f.month => f.revenue_k for f in lingua_f)

    for month in plan.months
        # Get revenue with 20 dollar Nebula price (double the original 10 dollar)
        nebula_rev = get(nebula_map, month, 0.0) * 2.0  # Double Nebula revenue for 20 dollar price
        disclosure_rev = get(disclosure_map, month, 0.0)
        lingua_rev = get(lingua_map, month, 0.0)
        total_revenue = nebula_rev + disclosure_rev + lingua_rev

        # Calculate variable costs (percentage of revenue)
        gemini_cost = total_revenue * cost_lookup["Gemini_LLM"][1]
        cloud_cost = total_revenue * cost_lookup["Google_Cloud_Infrastructure"][1]
        total_infrastructure = gemini_cost + cloud_cost

        # Fixed costs
        subsidiary_costs = cost_lookup["Subsidiary_Costs"][2]
        admin_salaries = cost_lookup["Administration_Salaries"][2]

        # Resource-based salaries (from resource plan) + admin salaries
        resource_salaries = get(salary_costs, month, 0.0)
        total_salaries = resource_salaries + admin_salaries

        # Google Credits offset (negative expense)
        google_credits = -total_infrastructure  # Zeros out infrastructure

        # Calculate gross margin
        total_costs = total_infrastructure + subsidiary_costs + total_salaries
        gross_margin_before_credits = total_revenue - total_costs
        gross_margin_after_credits = gross_margin_before_credits - google_credits  # Subtracting negative = adding

        gross_margin_pct = total_revenue > 0 ? (gross_margin_after_credits / total_revenue) * 100 : 0.0

        push!(pnl_data, Dict(
            "Month" => month,
            "Nebula_Revenue" => nebula_rev,
            "Disclosure_Revenue" => disclosure_rev,
            "Lingua_Revenue" => lingua_rev,
            "Total_Revenue" => total_revenue,
            "Gemini_LLM" => gemini_cost,
            "Google_Cloud_Infrastructure" => cloud_cost,
            "Total_Infrastructure" => total_infrastructure,
            "Subsidiary_Costs" => subsidiary_costs,
            "Resource_Salaries" => resource_salaries,
            "Administration_Salaries" => admin_salaries,
            "Total_Salaries" => total_salaries,
            "Google_Startup_Credits" => google_credits,
            "Gross_Margin" => gross_margin_after_credits,
            "Gross_Margin_Pct" => gross_margin_pct,
            "PnL" => gross_margin_after_credits
        ))
    end

    return pnl_data
end

function aggregate_periods(pnl_data)
    """
    Aggregate monthly data into required periods
    """
    aggregates = Dict()

    # 2025: Sep, Oct, Nov, Dec only
    months_2025 = ["Sep 2025", "Oct 2025", "Nov 2025", "Dec 2025"]
    data_2025 = filter(row -> row["Month"] in months_2025, pnl_data)

    if !isempty(data_2025)
        aggregates["Total_2025"] = Dict()
        for key in keys(data_2025[1])
            if key != "Month" && key != "Gross_Margin_Pct"
                aggregates["Total_2025"][key] = sum(row[key] for row in data_2025)
            end
        end
        # Calculate aggregate margin percentage
        total_rev = aggregates["Total_2025"]["Total_Revenue"]
        total_margin = aggregates["Total_2025"]["Gross_Margin"]
        aggregates["Total_2025"]["Gross_Margin_Pct"] = total_rev > 0 ? (total_margin / total_rev) * 100 : 0.0
    end

    # 2026: All 12 months (Jan, Feb, Mar + Q2 + Q3 + Q4)
    months_2026 = ["Jan 2026", "Feb 2026", "Mar 2026", "Apr 2026", "May 2026", "Jun 2026",
        "Jul 2026", "Aug 2026", "Sep 2026", "Oct 2026", "Nov 2026", "Dec 2026"]
    data_2026 = filter(row -> row["Month"] in months_2026, pnl_data)

    if !isempty(data_2026)
        aggregates["Total_2026"] = Dict()
        for key in keys(data_2026[1])
            if key != "Month" && key != "Gross_Margin_Pct"
                aggregates["Total_2026"][key] = sum(row[key] for row in data_2026)
            end
        end
        # Calculate aggregate margin percentage
        total_rev = aggregates["Total_2026"]["Total_Revenue"]
        total_margin = aggregates["Total_2026"]["Gross_Margin"]
        aggregates["Total_2026"]["Gross_Margin_Pct"] = total_rev > 0 ? (total_margin / total_rev) * 100 : 0.0
    end

    return aggregates
end

function create_sources_uses_statements(pnl_aggregates)
    """
    Create Sources & Uses statements for 2025 and 2026
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

    return sources_2025, uses_2025, sources_2026, uses_2026
end

function create_balance_sheet(sources_2025, sources_2026, deferred_salaries_end_2025, deferred_salaries_end_2026, pnl_aggregates)
    """
    Create consolidated Balance Sheet with deferred salary tracking and 1% ownership valuation
    """

    # Calculate cash positions
    net_sources_2025 = sum(sources_2025.Amount_k[1:end-1])  # Exclude total row
    net_sources_2026 = sum(sources_2026.Amount_k[1:end-1])

    # Apply 5% yield to short-term investments
    cash_2025 = min(net_sources_2025, 100.0)  # Keep $100k in operating cash
    short_term_inv_2025 = max(net_sources_2025 - 100.0, 0.0)
    investment_yield_2025 = short_term_inv_2025 * 0.05  # 5% annual yield

    # 2026 includes cumulative investments plus yield
    total_available_2026 = net_sources_2025 + net_sources_2026 + investment_yield_2025
    cash_2026 = min(total_available_2026, 200.0)  # Keep $200k in operating cash
    short_term_inv_2026 = max(total_available_2026 - 200.0, 0.0)

    total_assets_2025 = cash_2025 + short_term_inv_2025
    total_assets_2026 = cash_2026 + short_term_inv_2026

    # Calculate company valuation based on 1% ownership structure
    # Using conservative 10x P&L multiple for 2026
    pnl_2026 = get(pnl_aggregates, "Total_2026", Dict("PnL" => 0.0))["PnL"]
    annual_earnings_2026 = pnl_2026  # This is annual since it's 12 months
    company_valuation_2026 = annual_earnings_2026 * 10.0  # 10x earnings multiple

    # 1% ownership value
    ownership_value_2026 = company_valuation_2026 * 0.01

    # Separate founder contributions
    founder_opportunity_cost_total = 303 + 63  # 2025 + 2026
    founder_cash_total = 58 + 20  # 2025 + 2026

    # Calculate retained earnings
    retained_earnings_2025 = total_assets_2025 - deferred_salaries_end_2025 - founder_opportunity_cost_total - founder_cash_total
    retained_earnings_2026 = total_assets_2026 - deferred_salaries_end_2026 - founder_opportunity_cost_total - founder_cash_total

    balance_sheet = DataFrame(
        Account=[
            "ASSETS", "Cash", "Short-term Investments (5% yield)", "Total Assets", "",
            "LIABILITIES", "Accrued Liabilities (Deferred Salaries)", "Total Liabilities", "",
            "EQUITY", "Founder Opportunity Cost", "Founder Cash Contributions", "Retained Earnings", "Total Equity", "",
            "TOTAL LIABILITIES + EQUITY", "",
            "VALUATION ANALYSIS", "Annual Earnings (2026)", "Company Valuation (10x)", "1% Ownership Value"
        ],
        End_2025_k=[
            "", cash_2025, short_term_inv_2025, total_assets_2025, "",
            "", deferred_salaries_end_2025, deferred_salaries_end_2025, "",
            "", founder_opportunity_cost_total, founder_cash_total, retained_earnings_2025, total_assets_2025 - deferred_salaries_end_2025, "",
            total_assets_2025, "",
            "", "N/A", "N/A", "N/A"
        ],
        End_2026_k=[
            "", cash_2026, short_term_inv_2026, total_assets_2026, "",
            "", deferred_salaries_end_2026, deferred_salaries_end_2026, "",
            "", founder_opportunity_cost_total, founder_cash_total, retained_earnings_2026, total_assets_2026 - deferred_salaries_end_2026, "",
            total_assets_2026, "",
            "", annual_earnings_2026, company_valuation_2026, ownership_value_2026
        ]
    )

    return balance_sheet
end

function generate_financial_statements(plan::ResourcePlan, nebula_f, disclosure_f, lingua_f)
    ensure_output_directory()

    # Load cost factors
    cost_factors = load_cost_factors("data/cost_factors.csv")  # Use correct path

    # Calculate salary costs from resource plan
    salary_costs = calculate_salary_costs(plan)

    # Calculate monthly P&L with 20 dollar Nebula pricing
    pnl_data = calculate_monthly_pnl(plan, nebula_f, disclosure_f, lingua_f, cost_factors, salary_costs)

    # Calculate deferred salaries tracking
    deferred_salaries = calculate_deferred_salaries(pnl_data, salary_costs, cost_factors)

    # Aggregate into periods
    pnl_aggregates = aggregate_periods(pnl_data)

    # Get deferred salary balances for balance sheet
    deferred_end_2025 = get(deferred_salaries, "Dec 2025", 0.0)
    deferred_end_2026 = get(deferred_salaries, "Dec 2026", 0.0)

    println("\n\n💰 PROFIT & LOSS STATEMENT")
    println("="^50)
    println("(Nebula-NLU pricing: \$20/month)")
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")

    # Print header
    selected_months = ["Sep 2025", "Oct 2025", "Nov 2025", "Dec 2025", "Jan 2026", "Feb 2026", "Mar 2026"]
    header = "Component\t" * join(selected_months, "\t") * "\tTotal 2025\tTotal 2026"
    println(header)

    # Print revenue components
    revenue_components = ["Nebula_Revenue", "Disclosure_Revenue", "Lingua_Revenue", "Total_Revenue"]
    for component in revenue_components
        values = []
        for month in selected_months
            month_data = findfirst(row -> row["Month"] == month, pnl_data)
            if month_data !== nothing
                push!(values, round(pnl_data[month_data][component], digits=1))
            else
                push!(values, 0.0)
            end
        end

        total_2025 = haskey(pnl_aggregates, "Total_2025") ? round(pnl_aggregates["Total_2025"][component], digits=1) : 0.0
        total_2026 = haskey(pnl_aggregates, "Total_2026") ? round(pnl_aggregates["Total_2026"][component], digits=1) : 0.0

        values_str = join(values, "\t") * "\t" * string(total_2025) * "\t" * string(total_2026)
        println("$component\t$values_str")
    end

    println("")  # Blank line
    println("Cost Component")

    # Print cost components
    cost_components = ["Gemini_LLM", "Google_Cloud_Infrastructure", "Total_Infrastructure",
        "Subsidiary_Costs", "Total_Salaries", "Google_Startup_Credits",
        "Gross_Margin", "Gross_Margin_Pct", "PnL"]

    for component in cost_components
        values = []
        for month in selected_months
            month_data = findfirst(row -> row["Month"] == month, pnl_data)
            if month_data !== nothing
                val = pnl_data[month_data][component]
                if component == "Gross_Margin_Pct"
                    push!(values, string(round(val, digits=1)) * "%")
                else
                    push!(values, round(val, digits=1))
                end
            else
                push!(values, component == "Gross_Margin_Pct" ? "0.0%" : 0.0)
            end
        end

        if component == "Gross_Margin_Pct"
            total_2025 = haskey(pnl_aggregates, "Total_2025") ? string(round(pnl_aggregates["Total_2025"][component], digits=1)) * "%" : "0.0%"
            total_2026 = haskey(pnl_aggregates, "Total_2026") ? string(round(pnl_aggregates["Total_2026"][component], digits=1)) * "%" : "0.0%"
        else
            total_2025 = haskey(pnl_aggregates, "Total_2025") ? round(pnl_aggregates["Total_2025"][component], digits=1) : 0.0
            total_2026 = haskey(pnl_aggregates, "Total_2026") ? round(pnl_aggregates["Total_2026"][component], digits=1) : 0.0
        end

        values_str = join(values, "\t") * "\t" * string(total_2025) * "\t" * string(total_2026)
        println("$component\t$values_str")
    end

    println("```")

    # Generate Sources & Uses
    sources_2025, uses_2025, sources_2026, uses_2026 = create_sources_uses_statements(pnl_aggregates)

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

    # Generate Balance Sheet
    balance_sheet = create_balance_sheet(sources_2025, sources_2026, deferred_end_2025, deferred_end_2026, pnl_aggregates)

    println("\n\n🏛️ BALANCE SHEET")
    println("="^30)
    println("(Includes 5% yield on short-term investments)")
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")
    println("Account\tEnd 2025 (k\$)\tEnd 2026 (k\$)")
    for i in 1:nrow(balance_sheet)
        end_2025_val = balance_sheet.End_2025_k[i]
        end_2026_val = balance_sheet.End_2026_k[i]

        # Format numeric values
        if isa(end_2025_val, Number) && end_2025_val != 0
            end_2025_str = string(round(end_2025_val, digits=1))
        else
            end_2025_str = string(end_2025_val)
        end

        if isa(end_2026_val, Number) && end_2026_val != 0
            end_2026_str = string(round(end_2026_val, digits=1))
        else
            end_2026_str = string(end_2026_val)
        end

        println("$(balance_sheet.Account[i])\t$(end_2025_str)\t$(end_2026_str)")
    end
    println("```")

    # Print deferred salary summary
    println("\n\n📋 DEFERRED SALARY TRACKING")
    println("="^30)
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")
    println("Month\tDeferred Balance (k\$)")
    selected_deferred_months = ["Dec 2025", "Jun 2026", "Dec 2026"]
    for month in selected_deferred_months
        if haskey(deferred_salaries, month)
            println("$month\t$(round(deferred_salaries[month], digits=1))")
        end
    end
    println("```")

    # Save outputs
    pnl_df = DataFrame(pnl_data)
    CSV.write("output/monthly_pnl_with_deferred_salaries.csv", pnl_df)
    CSV.write("output/sources_uses_2025.csv", hcat(sources_2025, uses_2025))
    CSV.write("output/sources_uses_2026.csv", hcat(sources_2026, uses_2026))
    CSV.write("output/balance_sheet_with_valuation.csv", balance_sheet)

    # Save deferred salary tracking
    deferred_df = DataFrame(Month=collect(keys(deferred_salaries)), Deferred_Balance_k=collect(values(deferred_salaries)))
    CSV.write("output/deferred_salary_tracking.csv", deferred_df)

    println("\n✅ Comprehensive financial statements generated:")
    println("   • output/monthly_pnl_with_deferred_salaries.csv")
    println("   • output/sources_uses_2025.csv")
    println("   • output/sources_uses_2026.csv")
    println("   • output/balance_sheet_with_valuation.csv")
    println("   • output/deferred_salary_tracking.csv")

    return FinancialResults(pnl_df, hcat(sources_2025, uses_2025), hcat(sources_2026, uses_2026), balance_sheet)
end

end # module FinancialAnalysis