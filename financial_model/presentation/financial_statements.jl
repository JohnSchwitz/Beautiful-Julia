module FinancialStatements

using ..Formatting

export generate_monthly_pnl_table, generate_sources_uses_table,
    generate_balance_sheet_table, generate_deferred_salary_table,
    generate_standard_financial_statements, format_standard_financial_statements

function generate_monthly_pnl_table(plan, nebula_f, disclosure_f, lingua_f)
    pnl_data = []

    no_salary_months = ["Nov 2025", "Dec 2025", "Jan 2026", "Feb 2026", "Mar 2026", "Apr 2026"]

    for (i, month) in enumerate(plan.months)
        nebula_rev = i <= length(nebula_f) ? nebula_f[i].revenue_k * 1000 : 0.0
        disclosure_rev = i <= length(disclosure_f) ? disclosure_f[i].revenue_k * 1000 : 0.0
        lingua_rev = i <= length(lingua_f) ? lingua_f[i].revenue_k * 1000 : 0.0
        total_rev = nebula_rev + disclosure_rev + lingua_rev

        # COGS calculation
        gemini_cost = total_rev * 0.20
        infra_cost = total_rev * 0.15
        google_credits = gemini_cost + infra_cost
        cogs = 0  # Fully offset

        gross_profit = total_rev - cogs

        # Operating expenses - NO SALARIES until May 2026
        if month in no_salary_months
            dev_cost = 0
            marketing_cost = 0
        else
            dev_cost = plan.experienced_devs[i] * 10000 + plan.intern_devs[i] * 4000
            marketing_cost = 0  # Always $0 - covered by commissions
        end

        base_opex = dev_cost
        commission = total_rev * 0.25
        subsidiary_costs = 8000
        admin_salaries = 8000
        opex = base_opex + commission + subsidiary_costs + admin_salaries

        ebitda = gross_profit - opex
        deferred_salary = i <= 12 ? 8000 : 0
        net_income = ebitda - deferred_salary

        push!(pnl_data, (
            month=month,
            nebula_rev=round(Int, nebula_rev),
            disclosure_rev=round(Int, disclosure_rev),
            lingua_rev=round(Int, lingua_rev),
            total_rev=round(Int, total_rev),
            gemini_cost=round(Int, gemini_cost),
            infra_cost=round(Int, infra_cost),
            google_credits=round(Int, google_credits),
            cogs=round(Int, cogs),
            gross_profit=round(Int, gross_profit),
            commission=round(Int, commission),
            subsidiary_costs=round(Int, subsidiary_costs),
            admin_salaries=round(Int, admin_salaries),
            base_opex=round(Int, base_opex),
            opex=round(Int, opex),
            ebitda=round(Int, ebitda),
            deferred_salary=round(Int, deferred_salary),
            net_income=round(Int, net_income)
        ))
    end

    return pnl_data
end

function generate_sources_uses_table(plan, nebula_f, disclosure_f, lingua_f, financing_df)
    months_2025 = ["Nov 2025", "Dec 2025"]
    months_2026 = ["Jan 2026", "Feb 2026", "Mar 2026", "Apr 2026", "May 2026", "Jun 2026",
        "Jul 2026", "Aug 2026", "Sep 2026", "Oct 2026", "Nov 2026", "Dec 2026"]
    months_2027 = ["Jan 2027", "Feb 2027", "Mar 2027", "Apr 2027", "May 2027", "Jun 2027",
        "Jul 2027", "Aug 2027", "Sep 2027", "Oct 2027", "Nov 2027", "Dec 2027"]

    # Calculate revenue by year
    total_2025_rev = sum(f.revenue_k for f in nebula_f if f.month in months_2025) +
                     sum(f.revenue_k for f in disclosure_f if f.month in months_2025) +
                     sum(f.revenue_k for f in lingua_f if f.month in months_2025)

    total_2026_rev = sum(f.revenue_k for f in nebula_f if f.month in months_2026) +
                     sum(f.revenue_k for f in disclosure_f if f.month in months_2026) +
                     sum(f.revenue_k for f in lingua_f if f.month in months_2026)

    total_2027_rev = sum(f.revenue_k for f in nebula_f if f.month in months_2027) +
                     sum(f.revenue_k for f in disclosure_f if f.month in months_2027) +
                     sum(f.revenue_k for f in lingua_f if f.month in months_2027)

    revenue_2025 = total_2025_rev * 1000
    revenue_2026 = total_2026_rev * 1000
    revenue_2027 = total_2027_rev * 1000

    # Calculate OpEx (already includes all operating costs)
    commission_2025 = revenue_2025 * 0.25
    subsidiary_2025 = 8000 * 2
    admin_2025 = 8000 * 2
    dev_2025 = 0

    commission_2026 = revenue_2026 * 0.25
    subsidiary_2026 = 8000 * 12
    admin_2026 = 8000 * 12
    dev_2026 = (4 * 10000 + 2 * 4000) * 8

    commission_2027 = revenue_2027 * 0.25
    subsidiary_2027 = 8000 * 12
    admin_2027 = 8000 * 12
    dev_2027 = (5 * 10000 + 2 * 4000) * 12

    total_opex_2025 = commission_2025 + subsidiary_2025 + admin_2025 + dev_2025
    total_opex_2026 = commission_2026 + subsidiary_2026 + admin_2026 + dev_2026
    total_opex_2027 = commission_2027 + subsidiary_2027 + admin_2027 + dev_2027

    # EBIT
    ebit_2025 = revenue_2025 - total_opex_2025
    ebit_2026 = revenue_2026 - total_opex_2026
    ebit_2027 = revenue_2027 - total_opex_2027

    # Get financing
    financing_2025 = 0
    financing_2026 = 0
    financing_2027 = 0

    for row in eachrow(financing_df)
        if row.Month in months_2025
            financing_2025 += row.Amount
        elseif row.Month in months_2026
            financing_2026 += row.Amount
        elseif row.Month in months_2027
            financing_2027 += row.Amount
        end
    end

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

function generate_balance_sheet_table(plan, pnl_data, financing_df)
    months_by_year = Dict(
        2025 => ["Nov 2025", "Dec 2025"],
        2026 => ["Jan 2026", "Feb 2026", "Mar 2026", "Apr 2026", "May 2026", "Jun 2026",
            "Jul 2026", "Aug 2026", "Sep 2026", "Oct 2026", "Nov 2026", "Dec 2026"],
        2027 => ["Jan 2027", "Feb 2027", "Mar 2027", "Apr 2027", "May 2027", "Jun 2027",
            "Jul 2027", "Aug 2027", "Sep 2027", "Oct 2027", "Nov 2027", "Dec 2027"]
    )

    balance_data = []
    ip_assets = 650000  # Fixed - founder IP contribution
    cumulative_cash = 0.0

    for year in [2025, 2026, 2027]
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

function generate_deferred_salary_table(plan)
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

function generate_standard_financial_statements(plan, nebula_f, disclosure_f, lingua_f, financing_df)
    months_2025 = ["Nov 2025", "Dec 2025"]
    months_2026 = ["Jan 2026", "Feb 2026", "Mar 2026", "Apr 2026", "May 2026", "Jun 2026",
        "Jul 2026", "Aug 2026", "Sep 2026", "Oct 2026", "Nov 2026", "Dec 2026"]
    months_2027 = ["Jan 2027", "Feb 2027", "Mar 2027", "Apr 2027", "May 2027", "Jun 2027",
        "Jul 2027", "Aug 2027", "Sep 2027", "Oct 2027", "Nov 2027", "Dec 2027"]

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

    # Commissions
    commission_2025 = revenue_2025 * 0.25
    commission_2026 = revenue_2026 * 0.25
    commission_2027 = revenue_2027 * 0.25

    # Fixed costs
    subsidiary_2025 = 8000 * 2
    subsidiary_2026 = 8000 * 12
    subsidiary_2027 = 8000 * 12

    admin_2025 = 8000 * 2
    admin_2026 = 8000 * 12
    admin_2027 = 8000 * 12

    # Dev costs
    dev_2025 = 0
    dev_2026 = (4 * 10000 + 2 * 4000) * 8
    dev_2027 = (5 * 10000 + 2 * 4000) * 12

    # Total OpEx
    opex_2025 = commission_2025 + subsidiary_2025 + admin_2025 + dev_2025
    opex_2026 = commission_2026 + subsidiary_2026 + admin_2026 + dev_2026
    opex_2027 = commission_2027 + subsidiary_2027 + admin_2027 + dev_2027

    # Generate supporting tables
    pnl_data = generate_monthly_pnl_table(plan, nebula_f, disclosure_f, lingua_f)
    sources_uses = generate_sources_uses_table(plan, nebula_f, disclosure_f, lingua_f, financing_df)
    balance_sheets = generate_balance_sheet_table(plan, pnl_data, financing_df)

    return (
        pnl_2025=(
            revenue=revenue_2025,
            gemini=gemini_2025,
            infrastructure=infra_2025,
            google_credits=google_credits_2025,
            cogs=cogs_2025,
            gross_profit=revenue_2025,
            commission=commission_2025,
            subsidiary=subsidiary_2025,
            admin=admin_2025,
            dev=dev_2025,
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
            subsidiary=subsidiary_2026,
            admin=admin_2026,
            dev=dev_2026,
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
            subsidiary=subsidiary_2027,
            admin=admin_2027,
            dev=dev_2027,
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