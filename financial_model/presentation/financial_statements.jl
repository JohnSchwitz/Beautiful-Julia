module FinancialStatements

using ..Formatting
using Dates

export generate_monthly_pnl_table, generate_sources_uses_table, generate_balance_sheet_table, generate_standard_financial_statements, format_standard_financial_statements

function generate_monthly_pnl_table(months::Vector{String}, nebula_f, disclosure_f, lingua_f, cost_factors_df, salaries_df)
    pnl_data = []

    # Create a dictionary for efficient lookup of cost factors
    cost_factors = Dict(row[1] => row[2] for row in eachrow(cost_factors_df))
    gemini_rate = cost_factors["Gemini_LLM"]
    infra_rate = cost_factors["Google_Cloud_Infrastructure"]
    total_credits = 277000.0
    remaining_credits = total_credits

    # Build salary lookup dictionary: month -> (dev, devops, ga)
    salary_lookup = Dict{String,Tuple{Float64,Float64,Float64}}()
    for row in eachrow(salaries_df)
        month_key = row.Month
        dev = Float64(row.Development)
        devops = Float64(row.DevOps)
        ga = Float64(row.GA)
        salary_lookup[month_key] = (dev, devops, ga)
    end

    for (i, month) in enumerate(months)
        nebula_rev = i <= length(nebula_f) ? nebula_f[i].revenue_k * 1000 : 0.0
        disclosure_rev = i <= length(disclosure_f) ? disclosure_f[i].revenue_k * 1000 : 0.0
        lingua_rev = i <= length(lingua_f) ? lingua_f[i].revenue_k * 1000 : 0.0
        total_rev = nebula_rev + disclosure_rev + lingua_rev

        # COGS calculation with Google Credits
        gemini_cost = total_rev * gemini_rate
        infra_cost = total_rev * infra_rate
        gross_cogs = gemini_cost + infra_cost

        credits_consumed_this_month = min(remaining_credits, gross_cogs)
        remaining_credits -= credits_consumed_this_month
        cogs = gross_cogs - credits_consumed_this_month

        gross_profit = total_rev - cogs

        # Get salaries for this month (default to 0 if not found)
        dev_salary, dev_ops_salary, ga_salary = get(salary_lookup, month, (0.0, 0.0, 0.0))

        # Marketing is commission-based
        commission = total_rev * 0.25

        opex = dev_salary + dev_ops_salary + ga_salary + commission

        ebitda = gross_profit - opex
        net_income = ebitda

        push!(pnl_data, (
            month=month,
            nebula_rev=round(Int, nebula_rev),
            disclosure_rev=round(Int, disclosure_rev),
            lingua_rev=round(Int, lingua_rev),
            total_rev=round(Int, total_rev),
            gemini_cost=round(Int, gemini_cost),
            infra_cost=round(Int, infra_cost),
            google_credits=round(Int, credits_consumed_this_month),
            cogs=round(Int, cogs),
            gross_profit=round(Int, gross_profit),
            commission=round(Int, commission),
            dev_salary=round(Int, dev_salary),
            devops_salary=round(Int, dev_ops_salary),
            ga_salary=round(Int, ga_salary),
            opex=round(Int, opex),
            ebitda=round(Int, ebitda),
            net_income=round(Int, net_income)
        ))
    end

    return pnl_data
end

function generate_sources_uses_table(months::Vector{String}, nebula_f, disclosure_f, lingua_f, financing_df, pnl_data)
    # Dynamically group months by year from the timeline
    months_by_year = Dict{Int,Vector{String}}()
    for month_str in months
        year = parse(Int, split(month_str, " ")[2])
        if !haskey(months_by_year, year)
            months_by_year[year] = []
        end
        push!(months_by_year[year], month_str)
    end

    # Calculate actual financials from pnl_data
    financing_2025 = 0.0
    financing_2026 = 0.0
    financing_2027 = 0.0

    for row in eachrow(financing_df)
        year_of_financing = tryparse(Int, split(string(row.Month), " ")[2])
        if year_of_financing === nothing
            continue
        end

        if year_of_financing == 2025
            financing_2025 += row.Amount
        elseif year_of_financing == 2026
            financing_2026 += row.Amount
        elseif year_of_financing == 2027
            financing_2027 += row.Amount
        end
    end

    # Calculate EBIT and OpEx from pnl_data
    ebit_2025 = sum(p.ebitda for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2025; init=0.0)
    ebit_2026 = sum(p.ebitda for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2026; init=0.0)
    ebit_2027 = sum(p.ebitda for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2027; init=0.0)

    total_opex_2025 = sum(p.opex for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2025; init=0.0)
    total_opex_2026 = sum(p.opex for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2026; init=0.0)
    total_opex_2027 = sum(p.opex for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2027; init=0.0)

    # Interest & Taxes
    interest_2025 = 0
    interest_2026 = 5000
    interest_2027 = 15000

    taxes_2025 = 0
    taxes_2026 = 0
    taxes_2027 = max(0, (ebit_2027 - interest_2027) * 0.25)

    # ========================================
    # 2025 SOURCES & USES
    # ========================================
    sources_2025 = []
    push!(sources_2025, ("Founder Investment (IP)", round(Int, financing_2025)))
    total_sources_2025 = round(Int, financing_2025)
    push!(sources_2025, ("**Total Sources**", total_sources_2025))

    uses_2025 = []
    push!(uses_2025, ("Operating Expenses", round(Int, total_opex_2025)))
    push!(uses_2025, ("Interest", round(Int, interest_2025)))
    push!(uses_2025, ("Taxes", round(Int, taxes_2025)))
    total_uses_2025 = round(Int, total_opex_2025 + interest_2025 + taxes_2025)
    push!(uses_2025, ("**Total Uses**", total_uses_2025))
    push!(uses_2025, ("**Change in Nebula Valuation**", total_sources_2025 - total_uses_2025))

    # ========================================
    # 2026 SOURCES & USES
    # ========================================
    sources_2026 = []
    push!(sources_2026, ("EBIT", round(Int, ebit_2026)))
    if financing_2026 > 0
        push!(sources_2026, ("Angel Financing", round(Int, financing_2026)))
    end
    total_sources_2026 = round(Int, ebit_2026 + financing_2026)
    push!(sources_2026, ("**Total Sources**", total_sources_2026))

    uses_2026 = []
    push!(uses_2026, ("Interest", round(Int, interest_2026)))
    push!(uses_2026, ("Taxes", round(Int, taxes_2026)))
    total_uses_2026 = round(Int, interest_2026 + taxes_2026)
    push!(uses_2026, ("**Total Uses**", total_uses_2026))
    push!(uses_2026, ("**Change in Nebula Valuation**", total_sources_2026 - total_uses_2026))

    # ========================================
    # 2027 SOURCES & USES
    # ========================================
    sources_2027 = []
    push!(sources_2027, ("EBIT", round(Int, ebit_2027)))
    if financing_2027 > 0
        push!(sources_2027, ("Series A Financing", round(Int, financing_2027)))
    end
    total_sources_2027 = round(Int, ebit_2027 + financing_2027)
    push!(sources_2027, ("**Total Sources**", total_sources_2027))

    uses_2027 = []
    push!(uses_2027, ("Interest", round(Int, interest_2027)))
    push!(uses_2027, ("Taxes", round(Int, taxes_2027)))
    total_uses_2027 = round(Int, interest_2027 + taxes_2027)
    push!(uses_2027, ("**Total Uses**", total_uses_2027))
    push!(uses_2027, ("**Change in Nebula Valuation**", total_sources_2027 - total_uses_2027))

    return (
        year_2025=Dict("sources" => sources_2025, "uses" => uses_2025),
        year_2026=Dict("sources" => sources_2026, "uses" => uses_2026),
        year_2027=Dict("sources" => sources_2027, "uses" => uses_2027)
    )
end

function generate_balance_sheet_table(months::Vector{String}, pnl_data, financing_df)
    # Dynamically group months by year from the timeline
    months_by_year = Dict{Int,Vector{String}}()
    for month_str in months
        year = parse(Int, split(month_str, " ")[2])
        if !haskey(months_by_year, year)
            months_by_year[year] = []
        end
        push!(months_by_year[year], month_str)
    end

    balance_data = []
    ip_assets = 650000  # Fixed - founder IP contribution
    cumulative_cash = 0.0

    for year in sort(collect(keys(months_by_year)))
        year_months = months_by_year[year]

        # Calculate year financials
        year_revenue = sum(p.total_rev for p in pnl_data if p.month in year_months)
        year_opex = sum(p.opex for p in pnl_data if p.month in year_months)
        year_ebit = year_revenue - year_opex

        # Get financing
        year_financing = 0
        for row in eachrow(financing_df)
            if row.Month in year_months
                year_financing += row.Amount
            end
        end

        # Calculate cash flow components
        year_gemini = year_revenue * 0.20
        year_infra = year_revenue * 0.15
        year_google_credits = year_gemini + year_infra

        year_interest = year == 2025 ? 0 : (year == 2026 ? 5000 : 15000)
        year_taxes = year == 2027 ? max(0, (year_ebit - year_interest) * 0.25) : 0

        # Calculate change in cash (from Sources & Uses)
        if year == 2025
            # Sources: Founder ($650K) + Google Credits
            # Uses: COGS + OpEx + Interest + Taxes
            total_sources = year_financing + year_google_credits
            total_uses = year_gemini + year_infra + year_opex + year_interest + year_taxes
            change_in_cash = total_sources - total_uses
        else
            # Sources: EBIT + Financing + Google Credits
            # Uses: COGS + OpEx + Interest + Taxes
            total_sources = year_ebit + year_financing + year_google_credits
            total_uses = year_gemini + year_infra + year_opex + year_interest + year_taxes
            change_in_cash = total_sources - total_uses
        end

        cumulative_cash += change_in_cash

        # Assets
        cash_and_investments = round(Int, cumulative_cash)
        total_assets = ip_assets + cash_and_investments

        # Liabilities
        year_ap = year == 2025 ? 32000 : round(Int, year_opex / 12)
        deferred_revenue = 0
        total_liabilities = year_ap + deferred_revenue

        # Equity (must balance)
        nebula_valuation = total_assets - total_liabilities
        total_equity = nebula_valuation

        push!(balance_data, (
            date="Dec $year",
            cash=cash_and_investments,
            ip_assets=ip_assets,
            total_assets=total_assets,
            ap=year_ap,
            deferred_revenue=deferred_revenue,
            total_liabilities=total_liabilities,
            nebula_valuation=nebula_valuation,
            total_equity=total_equity
        ))
    end

    return balance_data
end

function generate_standard_financial_statements(months::Vector{String}, nebula_f, disclosure_f, lingua_f, financing_df, cost_factors_df, salaries_df)
    # Dynamically group months by year from the timeline
    months_by_year = Dict{Int,Vector{String}}()
    for month_str in months
        year = parse(Int, split(month_str, " ")[2])
        if !haskey(months_by_year, year)
            months_by_year[year] = []
        end
        push!(months_by_year[year], month_str)
    end

    revenue_2025 = 0.0
    revenue_2026 = 0.0
    revenue_2027 = 0.0
    for f in vcat(nebula_f, disclosure_f, lingua_f)
        year_of_rev = tryparse(Int, split(string(f.month), " ")[2])
        if year_of_rev !== nothing && haskey(months_by_year, year_of_rev)
            if year_of_rev == 2025
                revenue_2025 += f.revenue_k * 1000
            elseif year_of_rev == 2026
                revenue_2026 += f.revenue_k * 1000
            elseif year_of_rev == 2027
                revenue_2027 += f.revenue_k * 1000
            end
        end
    end

    # COGS
    gemini_2025 = revenue_2025 * 0.20
    infra_2025 = revenue_2025 * 0.15
    google_credits_2025 = gemini_2025 + infra_2025
    cogs_2025 = 0

    gemini_2026 = revenue_2026 * 0.20
    infra_2026 = revenue_2026 * 0.15
    google_credits_2026 = gemini_2026 + infra_2026
    cogs_2026 = 0

    gemini_2027 = revenue_2027 * 0.20
    infra_2027 = revenue_2027 * 0.15
    google_credits_2027 = gemini_2027 + infra_2027
    cogs_2027 = 0

    # Generate monthly P&L data FIRST - before anything else needs it
    pnl_data = generate_monthly_pnl_table(months, nebula_f, disclosure_f, lingua_f, cost_factors_df, salaries_df)

    # Calculate detailed OpEx breakdowns from pnl_data for R&D tax credits
    commission_2025 = sum(p.commission for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2025; init=0.0)
    commission_2026 = sum(p.commission for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2026; init=0.0)
    commission_2027 = sum(p.commission for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2027; init=0.0)

    dev_2025 = sum(p.dev_salary for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2025; init=0.0)
    dev_2026 = sum(p.dev_salary for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2026; init=0.0)
    dev_2027 = sum(p.dev_salary for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2027; init=0.0)

    devops_2025 = sum(p.devops_salary for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2025; init=0.0)
    devops_2026 = sum(p.devops_salary for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2026; init=0.0)
    devops_2027 = sum(p.devops_salary for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2027; init=0.0)

    ga_2025 = sum(p.ga_salary for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2025; init=0.0)
    ga_2026 = sum(p.ga_salary for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2026; init=0.0)
    ga_2027 = sum(p.ga_salary for p in pnl_data if parse(Int, split(p.month, " ")[2]) == 2027; init=0.0)

    # Total OpEx
    opex_2025 = commission_2025 + dev_2025 + devops_2025 + ga_2025
    opex_2026 = commission_2026 + dev_2026 + devops_2026 + ga_2026
    opex_2027 = commission_2027 + dev_2027 + devops_2027 + ga_2027

    # Generate supporting tables - NOW pnl_data exists
    sources_uses = generate_sources_uses_table(months, nebula_f, disclosure_f, lingua_f, financing_df, pnl_data)
    balance_sheets = generate_balance_sheet_table(months, pnl_data, financing_df)

    return (
        pnl_2025=(
            revenue=revenue_2025,
            gemini=gemini_2025,
            infrastructure=infra_2025,
            google_credits=google_credits_2025,
            cogs=cogs_2025,
            gross_profit=revenue_2025,
            commission=commission_2025,
            dev=dev_2025,
            devops=devops_2025,
            ga=ga_2025,
            opex=opex_2025,
            ebit=revenue_2025 - opex_2025,
            interest=0,
            ebt=revenue_2025 - opex_2025,
            taxes=0,
            net_income=revenue_2025 - opex_2025
        ),
        pnl_2026=(
            revenue=revenue_2026,
            gemini=gemini_2026,
            infrastructure=infra_2026,
            google_credits=google_credits_2026,
            cogs=cogs_2026,
            gross_profit=revenue_2026,
            commission=commission_2026,
            dev=dev_2026,
            devops=devops_2026,
            ga=ga_2026,
            opex=opex_2026,
            ebit=revenue_2026 - opex_2026,
            interest=5000,
            ebt=revenue_2026 - opex_2026 - 5000,
            taxes=0,
            net_income=revenue_2026 - opex_2026 - 5000
        ),
        pnl_2027=(
            revenue=revenue_2027,
            gemini=gemini_2027,
            infrastructure=infra_2027,
            google_credits=google_credits_2027,
            cogs=cogs_2027,
            gross_profit=revenue_2027,
            commission=commission_2027,
            dev=dev_2027,
            devops=devops_2027,
            ga=ga_2027,
            opex=opex_2027,
            ebit=revenue_2027 - opex_2027,
            interest=15000,
            ebt=revenue_2027 - opex_2027 - 15000,
            taxes=max(0, (revenue_2027 - opex_2027 - 15000) * 0.25),
            net_income=(revenue_2027 - opex_2027 - 15000) * 0.75
        ),
        sources_uses_2025=sources_uses.year_2025,
        sources_uses_2026=sources_uses.year_2026,
        sources_uses_2027=sources_uses.year_2027,
        balance_2025=balance_sheets[1],
        balance_2026=balance_sheets[2],
        balance_2027=balance_sheets[3]
    )
end

function format_standard_financial_statements(financial_data)
    return "Financial statements formatting placeholder"
end

end # module FinancialStatements