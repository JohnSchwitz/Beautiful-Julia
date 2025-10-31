module ReportGenerators

using Dates
using ..Formatting
using ..FinancialStatements
using ..LoadFactors

export generate_executive_summary_file, generate_three_year_projections_file,
    generate_complete_strategic_plan_file, generate_founder_capitalization_file

function generate_executive_summary_file(plan, milestones, nebula_f, disclosure_f, lingua_f)
    nebula_map = Dict(f.month => f.revenue_k for f in nebula_f)
    disclosure_map = Dict(f.month => f.revenue_k for f in disclosure_f)
    lingua_map = Dict(f.month => f.revenue_k for f in lingua_f)

    months_2025 = ["Nov 2025", "Dec 2025"]
    months_2026 = ["Jan 2026", "Feb 2026", "Mar 2026", "Apr 2026", "May 2026", "Jun 2026",
        "Jul 2026", "Aug 2026", "Sep 2026", "Oct 2026", "Nov 2026", "Dec 2026"]
    months_2027 = ["Jan 2027", "Feb 2027", "Mar 2027", "Apr 2027", "May 2027", "Jun 2027",
        "Jul 2027", "Aug 2027", "Sep 2027", "Oct 2027", "Nov 2027", "Dec 2027"]

    total_2025 = sum(get(nebula_map, month, 0.0) + get(disclosure_map, month, 0.0) + get(lingua_map, month, 0.0) for month in months_2025)
    total_2026 = sum(get(nebula_map, month, 0.0) + get(disclosure_map, month, 0.0) + get(lingua_map, month, 0.0) for month in months_2026)
    total_2027 = sum(get(nebula_map, month, 0.0) + get(disclosure_map, month, 0.0) + get(lingua_map, month, 0.0) for month in months_2027)

    sep_2027_total = get(nebula_map, "Sep 2027", 0.0) + get(disclosure_map, "Sep 2027", 0.0) + get(lingua_map, "Sep 2027", 0.0)
    sep_2027_arr = sep_2027_total * 12

    open("NLU_Executive_Summary.md", "w") do file
        write(file, "# 🚀 NLU Portfolio Executive Summary\n\n")
        write(file, "## Investment Opportunity Overview\n\n")
        write(file, "The NLU Portfolio comprises three AI-powered platforms targeting a **", format_currency(18_500_000_000), "** addressable market.\n\n")
        write(file, "### Financial Highlights\n\n")
        write(file, "#### Revenue Trajectory\n")
        write(file, "- **2025 (2 months):** ", format_currency(total_2025 * 1000), " total revenue\n")
        write(file, "- **2026 (full year):** ", format_currency(total_2026 * 1000), " total revenue\n")
        write(file, "- **2027 (full year):** ", format_currency(total_2027 * 1000), " total revenue\n")
        write(file, "- **September 2027 ARR:** ", format_currency(sep_2027_arr * 1000), "\n\n")
    end
    println("✅ Generated: NLU_Executive_Summary.md")
end

function generate_three_year_projections_file(plan, milestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)
    nebula_map = Dict(f.month => f.revenue_k for f in nebula_f)
    disclosure_map = Dict(f.month => f.revenue_k for f in disclosure_f)
    lingua_map = Dict(f.month => f.revenue_k for f in lingua_f)

    months_2025 = ["Nov 2025", "Dec 2025"]
    months_2026 = ["Jan 2026", "Feb 2026", "Mar 2026", "Apr 2026", "May 2026", "Jun 2026",
        "Jul 2026", "Aug 2026", "Sep 2026", "Oct 2026", "Nov 2026", "Dec 2026"]
    months_2027 = ["Jan 2027", "Feb 2027", "Mar 2027", "Apr 2027", "May 2027", "Jun 2027",
        "Jul 2027", "Aug 2027", "Sep 2027", "Oct 2027", "Nov 2027", "Dec 2027"]

    nebula_2025 = sum(f.revenue_k for f in nebula_f if f.month in months_2025)
    nebula_2026 = sum(f.revenue_k for f in nebula_f if f.month in months_2026)
    nebula_2027 = sum(f.revenue_k for f in nebula_f if f.month in months_2027)

    disclosure_2025 = sum(f.revenue_k for f in disclosure_f if f.month in months_2025)
    disclosure_2026 = sum(f.revenue_k for f in disclosure_f if f.month in months_2026)
    disclosure_2027 = sum(f.revenue_k for f in disclosure_f if f.month in months_2027)

    lingua_2025 = sum(f.revenue_k for f in lingua_f if f.month in months_2025)
    lingua_2026 = sum(f.revenue_k for f in lingua_f if f.month in months_2026)
    lingua_2027 = sum(f.revenue_k for f in lingua_f if f.month in months_2027)

    open("NLU_Three_Year_Projections.md", "w") do file
        write(file, "# 📊 NLU Portfolio Three-Year Financial Projections\n\n")
        write(file, "## Revenue Summary by Product (2025-2027)\n\n")
        write(file, "| Product | 2025 | 2026 | 2027 | Total |\n")
        write(file, "|---------|------|------|------|-------|\n")
        write(file, "| Nebula-NLU | ", format_currency(nebula_2025 * 1000), " | ", format_currency(nebula_2026 * 1000), " | ", format_currency(nebula_2027 * 1000), " | ", format_currency((nebula_2025 + nebula_2026 + nebula_2027) * 1000), " |\n")
        write(file, "| Disclosure-NLU | ", format_currency(disclosure_2025 * 1000), " | ", format_currency(disclosure_2026 * 1000), " | ", format_currency(disclosure_2027 * 1000), " | ", format_currency((disclosure_2025 + disclosure_2026 + disclosure_2027) * 1000), " |\n")
        write(file, "| Lingua-NLU | ", format_currency(lingua_2025 * 1000), " | ", format_currency(lingua_2026 * 1000), " | ", format_currency(lingua_2027 * 1000), " | ", format_currency((lingua_2025 + lingua_2026 + lingua_2027) * 1000), " |\n")
        write(file, "| **TOTAL** | ", format_currency((nebula_2025 + disclosure_2025 + lingua_2025) * 1000), " | ", format_currency((nebula_2026 + disclosure_2026 + lingua_2026) * 1000), " | ", format_currency((nebula_2027 + disclosure_2027 + lingua_2027) * 1000), " | ", format_currency((nebula_2025 + nebula_2026 + nebula_2027 + disclosure_2025 + disclosure_2026 + disclosure_2027 + lingua_2025 + lingua_2026 + lingua_2027) * 1000), " |\n\n")
    end
    println("✅ Generated: NLU_Three_Year_Projections.md")
end

function generate_complete_strategic_plan_file(plan, milestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)
    nebula_map = Dict(f.month => f.revenue_k for f in nebula_f)
    disclosure_map = Dict(f.month => f.revenue_k for f in disclosure_f)
    lingua_map = Dict(f.month => f.revenue_k for f in lingua_f)

    # Load financing data
    financing_df = LoadFactors.load_financing()

    # Generate financial data
    financial_data = FinancialStatements.generate_standard_financial_statements(plan, nebula_f, disclosure_f, lingua_f, financing_df)

    open("NLU_Strategic_Plan_Complete.md", "w") do file
        # Table of Contents - UPDATED TO 13 SECTIONS
        write(file, "# 🚀 NLU PORTFOLIO STRATEGIC PLAN\n\n")
        write(file, "**For Investors & Prospective Employees**\n\n")
        write(file, "## TABLE OF CONTENTS\n\n")
        write(file, "1. Revenue Summary\n")
        write(file, "2. Valuation Summary\n")
        write(file, "3. Definitions\n")
        write(file, "4. Resource Summary\n")
        write(file, "5. Milestone Schedule\n")
        write(file, "6. Hiring & Resource Schedule\n")
        write(file, "7. Probability Analysis\n")
        write(file, "8. Activity Indicators\n")
        write(file, "9. Revenue by Product\n")
        write(file, "10. Revenue by Channel\n")
        write(file, "11. Valuation Analysis\n")
        write(file, "12. Revenue Realizations\n")
        write(file, "13. Financial Statements\n\n")
        write(file, "---\n\n")

        # SECTION 1: Revenue Summary
        write(file, "## 1. Revenue Summary\n\n")
        write(file, "### Quarterly Revenue Chart\n\n")
        write(file, "| Quarter | Nebula | Disclosure | Lingua | Total | Growth |\n")
        write(file, "|---------|--------|------------|--------|-------|--------|\n")

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

            growth_str = previous_quarter_total > 0 ? string(round(((total_q - previous_quarter_total) / previous_quarter_total) * 100, digits=1), "%") : "-"
            write(file, "| ", quarter_name, " | ", format_currency(nebula_q * 1000), " | ", format_currency(disclosure_q * 1000), " | ", format_currency(lingua_q * 1000), " | ", format_currency(total_q * 1000), " | ", growth_str, " |\n")
            previous_quarter_total = total_q
        end
        write(file, "\n---\n\n")

        # SECTION 2: Valuation Summary
        q4_2026_months = ["Oct 2026", "Nov 2026", "Dec 2026"]
        q4_2026_total = sum(get(nebula_map, month, 0.0) + get(disclosure_map, month, 0.0) + get(lingua_map, month, 0.0) for month in q4_2026_months) / 3
        q4_2026_arr = q4_2026_total * 12

        q4_2027_months = ["Oct 2027", "Nov 2027", "Dec 2027"]
        q4_2027_total = sum(get(nebula_map, month, 0.0) + get(disclosure_map, month, 0.0) + get(lingua_map, month, 0.0) for month in q4_2027_months) / 3
        q4_2027_arr = q4_2027_total * 12

        write(file, "## 2. Valuation Summary\n\n")
        write(file, "| Milestone | Monthly Rev | ARR | Conservative | Optimistic | 1% Equity |\n")
        write(file, "|-----------|-------------|-----|--------------|------------|----------|\n")
        write(file, "| Q4 2026 | ", format_currency(q4_2026_total * 1000), " | ", format_currency(q4_2026_arr * 1000), " | ", format_currency((q4_2026_arr / 1000) * 10 * 1_000_000), " | ", format_currency((q4_2026_arr / 1000) * 15 * 1_000_000), " | ", format_currency((q4_2026_arr / 1000) * 10 * 0.01 * 1_000_000), " - ", format_currency((q4_2026_arr / 1000) * 15 * 0.01 * 1_000_000), " |\n")
        write(file, "| Q4 2027 | ", format_currency(q4_2027_total * 1000), " | ", format_currency(q4_2027_arr * 1000), " | ", format_currency((q4_2027_arr / 1000) * 12 * 1_000_000), " | ", format_currency((q4_2027_arr / 1000) * 18 * 1_000_000), " | ", format_currency((q4_2027_arr / 1000) * 12 * 0.01 * 1_000_000), " - ", format_currency((q4_2027_arr / 1000) * 18 * 0.01 * 1_000_000), " |\n\n")
        write(file, "---\n\n")

        # SECTION 3: Definitions
        write(file, "## 3. Definitions\n\n")
        write(file, "- **ARR**: Annual Recurring Revenue\n")
        write(file, "- **LTV:CAC**: Lifetime Value to Customer Acquisition Cost\n")
        write(file, "- **SAR**: Stock Appreciation Rights\n")
        write(file, "- **K**: Thousands, **M**: Millions\n")
        write(file, "- **IP**: Intellectual Property (founder-contributed software)\n\n")
        write(file, "---\n\n")

        # SECTION 4: Resource Summary
        hours_per_month = 240
        tracks = ["Development", "Marketing"]
        total_months = [round(Int, sum(t.planned_hours for t in initial_tasks if t.task_type == track) / hours_per_month) for track in tracks]
        available_months = [round(Int, hours.cumulative_dev[end] / hours_per_month), round(Int, hours.cumulative_marketing[end] / hours_per_month)]
        utilization = [string(round(Int, (total_months[i] / available_months[i]) * 100), "%") for i in 1:2]
        buffer = available_months .- total_months

        write(file, "## 4. Resource Summary\n\n")
        write(file, "| Track | Task Months | Available | Utilization | Buffer |\n")
        write(file, "|-------|-------------|-----------|-------------|--------|\n")
        for i in 1:length(tracks)
            write(file, "| ", tracks[i], " | ", add_commas(total_months[i]), " | ", add_commas(available_months[i]), " | ", utilization[i], " | ", add_commas(buffer[i]), " |\n")
        end
        write(file, "\n---\n\n")

        # SECTION 5: Milestone Schedule
        strategic_map = [
            ("Infrastructure Complete", ["Infrastructure"]),
            ("Nebula-NLU MVP", ["NebulaNU_MVP"]),
            ("Nebula-NLU Scale", ["NebulaNU_Scale"]),
            ("Disclosure-NLU MVP", ["DisclosureNLU_MVP"]),
            ("Disclosure-NLU Scale", ["DisclosureNLU_Scale"]),
            ("Lingua-NLU MVP", ["LinguaNU_MVP"]),
            ("Lingua-NLU Scale", ["LinguaNU_Scale"]),
            ("Marketing Foundation", ["MktgDigitalFoundation"]),
            ("Content & Lead Gen", ["ContentAndLeadGeneration"]),
        ]

        write(file, "## 5. Milestone Schedule\n\n")
        write(file, "| Milestone | Date | Status |\n")
        write(file, "|-----------|------|--------|\n")
        for (name, components) in strategic_map
            component_milestones = filter(m -> m.task in components, milestones)
            if !isempty(component_milestones)
                dates = [m.milestone_date for m in component_milestones]
                month_indices = [findfirst(==(d), plan.months) for d in dates if d != "Beyond Plan"]
                final_date = isempty(month_indices) ? "Beyond Plan" : plan.months[maximum(month_indices)]
                status = final_date == "Beyond Plan" ? "DELAYED" : "ON TIME"
                write(file, "| ", name, " | ", final_date, " | ", status, " |\n")
            end
        end
        write(file, "\n---\n\n")

        # SECTION 6: Hiring & Resource Schedule
        write(file, "## 6. Hiring & Resource Schedule\n\n")
        write(file, "### Staffing Plan\n\n")
        write(file, "| Month | Exp Dev | Intern Dev | Exp Mkt | Intern Mkt |\n")
        write(file, "|-------|---------|------------|---------|------------|\n")

        for i in 1:min(26, length(plan.months))
            exp_dev = string(round(Int, plan.experienced_devs[i]))
            int_dev = string(round(Int, plan.intern_devs[i]))
            exp_mkt = string(round(Int, plan.experienced_marketers[i]))
            int_mkt = string(round(Int, plan.intern_marketers[i]))

            write(file, "| ", plan.months[i], " | ", exp_dev, " | ", int_dev, " | ", exp_mkt, " | ", int_mkt, " |\n")
        end

        write(file, "**Sales Capacity & Expected Targets (λ = Poisson parameter):**\n\n")
        write(file, "**Disclosure-NLU:**\n")
        write(file, "- Solo firms: 10/month capacity per SDR | λ=10 target\n")
        write(file, "- Small firms: 6/month capacity per AE | λ=10 target\n")
        write(file, "- Medium firms: 2/month capacity per AE | λ=3 target\n")
        write(file, "- Large firms: 0.1/month capacity per AE | λ=0.1 target (starts Jul 2027)\n")
        write(file, "- BigLaw firms: 0.1/month capacity per AE | λ=0.1 target (starts Jul 2027)\n\n")
        write(file, "**Nebula-NLU:**\n")
        write(file, "- Direct customer acquisition: 100 customers/month per SDR\n")
        write(file, "- Consumer-facing B2C sales model\n\n")
        write(file, "**Lingua-NLU (B2B Corporate Model):**\n")
        write(file, "- Target: Mid-size to Enterprise companies (500-10,000 employees)\n")
        write(file, raw"- Sales structure: 2 AE Mid-Market + 2 AE Enterprise + 1 VP Sales = **5 people fixed**" * "\n")
        write(file, raw"- AE Mid-Market: 6-8 corporate contracts/year @ $600K avg" * "\n")
        write(file, raw"- AE Enterprise: 3-4 corporate contracts/year @ $1.5M avg" * "\n")
        write(file, raw"- VP Sales: 2-3 global contracts/year @ $3M avg" * "\n")
        write(file, raw"- Ramp: Jul 2026 (1 person) → Nov 2026 (5 people) → Fixed team thereafter" * "\n")
        write(file, raw"- Revenue model: Individual users within corporate accounts pay $59/match" * "\n\n")

        write(file, "| Month | Solo | Small | Med | Large | BigLaw | Nebula | Lingua | Total |\n")
        write(file, "|-------|------|-------|-----|-------|--------|--------|--------|-------|\n")

        for i in 1:min(26, length(plan.months))
            month = plan.months[i]

            # Disclosure needs - ALL from probability_params.csv
            disc_solo = 0.0
            disc_small = 0.0
            disc_med = 0.0
            disc_large = 0.0
            disc_biglaw = 0.0

            if month >= "Mar 2026"
                # Lambda values from probability_params.csv
                lambda_solo = 10.0      # Disclosure-NLU,lambda_solo_firms,10,Poisson
                lambda_small = 10.0     # Disclosure-NLU,lambda_small_firms,10,Poisson
                lambda_medium = 3.0     # Disclosure-NLU,lambda_medium_firms,3,Poisson

                # SDR/AE capacity per person per month
                disc_solo = lambda_solo / 10.0     # 10 firms per SDR capacity = 1.0
                disc_small = lambda_small / 6.0    # 6 firms per AE capacity = 1.67
                disc_med = lambda_medium / 2.0     # 2 firms per AE capacity = 1.5
            end

            # Large and BigLaw start Jan 2027
            if month >= "Jan 2027"
                lambda_large = 0.1      # Disclosure-NLU,lambda_large_firms,0.1,Poisson
                lambda_biglaw = 0.1     # Disclosure-NLU,lambda_biglaw_firms,0.1,Poisson

                disc_large = lambda_large / 0.1    # 0.1 firms per AE (1 deal per 10 months) = 1.0
                disc_biglaw = lambda_biglaw / 0.1  # 0.1 firms per AE (1 deal per 10 months) = 1.0
            end

            # Nebula needs - use actual forecast data
            nebula_need = 0.0
            if i <= length(nebula_f) && nebula_f[i].revenue_k > 0
                new_cust = nebula_f[i].new_customers
                nebula_need = new_cust / 100.0  # 100 customers per SDR capacity
            end

            # Lingua needs - B2B corporate sales model (5-person fixed team)
            lingua_need = 0.0
            if month >= "Jul 2026"
                # Find the index of Jul 2026 (launch month)
                jul_2026_idx = findfirst(==("Jul 2026"), plan.months)

                if jul_2026_idx !== nothing && i >= jul_2026_idx
                    # Ramp-up phase: hire 1 person per month until reaching 5
                    months_since_launch = i - jul_2026_idx + 1

                    if months_since_launch <= 5
                        # Jul 2026: 1, Aug 2026: 2, Sep 2026: 3, Oct 2026: 4, Nov 2026: 5
                        lingua_need = Float64(months_since_launch)
                    else
                        # Dec 2026 onwards: fixed team of 5
                        lingua_need = 5.0
                    end
                end
            end

            total_need = disc_solo + disc_small + disc_med + disc_large + disc_biglaw + nebula_need + lingua_need

            # Format all values
            disc_solo_str = disc_solo == 0.0 ? "0.0" : string(round(disc_solo, digits=1))
            disc_small_str = disc_small == 0.0 ? "0.0" : string(round(disc_small, digits=1))
            disc_med_str = disc_med == 0.0 ? "0.0" : string(round(disc_med, digits=1))
            disc_large_str = disc_large == 0.0 ? "0.0" : string(round(disc_large, digits=1))
            disc_biglaw_str = disc_biglaw == 0.0 ? "0.0" : string(round(disc_biglaw, digits=1))
            nebula_str = nebula_need == 0.0 ? "0.0" : string(round(nebula_need, digits=1))
            lingua_str = lingua_need == 0.0 ? "0.0" : string(round(lingua_need, digits=1))
            total_str = total_need == 0.0 ? "0.0" : string(round(total_need, digits=1))

            write(file, "| ", month, " | ", disc_solo_str, " | ", disc_small_str, " | ",
                disc_med_str, " | ", disc_large_str, " | ", disc_biglaw_str, " | ",
                nebula_str, " | ", lingua_str, " | ", total_str, " |\n")
        end

        write(file, "\n---\n\n")

        # SECTION 7: Probability Analysis (was Section 8)
        write(file, "## 7. Probability Analysis\n\n")
        write(file, "**All parameters from CSV files**\n\n")
        write(file, "### Nebula-NLU Model\n")
        write(file, "- Dec 2025: 200 customers (no revenue - MVP launch)\n")
        write(file, "- Jan 2026: Revenue recognition begins\n")
        write(file, "- Jan-Apr 2026: Doubling phase (200→400→800→1,600→3,200)\n")
        write(file, "- May 2026+: Linear growth (533/month)\n")
        write(file, "- Pricing: Monthly \$20, Annual \$96 (35% choose annual)\n\n")
        write(file, "### Disclosure-NLU Model\n")
        write(file, "- Solo: \$15K/year (λ=10 new firms/month, Poisson distribution)\n")
        write(file, "- Small: \$50K/year (λ=10 new firms/month, Poisson distribution)\n")
        write(file, "- Medium: \$150K/year (λ=3 new firms/month, Poisson distribution)\n")
        write(file, "- Large: \$300K/year (λ=0.1 new firms/month, starts Jul 2027, Poisson)\n")
        write(file, "- BigLaw: \$750K/year (λ=0.1 new firms/month, starts Jul 2027, Poisson)\n\n")
        write(file, "### Lingua-NLU Model\n")
        write(file, "**B2B-to-Consumer Strategy:**\n")
        write(file, "- Sales approach: B2B corporate contracts with Fortune 5000 companies\n")
        write(file, "- Target customers: Companies with 500-10,000 employees needing language training\n")
        write(file, raw"- Value proposition: Replace $10K/employee traditional training with $500/employee peer matching" * "\n")
        write(file, raw"- Corporate pricing: $250K-$3M annual contracts (tiered by company size)" * "\n\n")
        write(file, "**Individual User Economics:**\n")
        write(file, raw"- Match price: $59 per successful pairing" * "\n")
        write(file, "- Match success rate: 67% (Beta distribution α=4, β=2)\n")
        write(file, "- User acquisition: Through corporate partnerships\n")
        write(file, "- Jul 2026 launch: 1,500 users from initial corporate pilots\n")
        write(file, "- Dec 2026: 4,000 users (ramping with corporate contracts)\n\n")
        write(file, "---\n\n")

        # SECTION 8: Activity Indicators (was Section 9)
        write(file, "## 8. Activity Indicators\n\n")
        write(file, "### Nebula-NLU Customers\n\n")
        write(file, "| Month | New | Total | Revenue |\n")
        write(file, "|-------|-----|-------|---------|")
        write(file, "\n")

        nebula_mvp_idx = findfirst(f -> f.revenue_k > 0, nebula_f)
        if nebula_mvp_idx === nothing
            nebula_mvp_idx = length(nebula_f) + 1
        end

        for (i, f) in enumerate(nebula_f[1:min(26, end)])
            new_cust = i < nebula_mvp_idx ? "pre-MVP" : add_commas(f.new_customers)
            total_cust = i < nebula_mvp_idx ? "pre-MVP" : add_commas(f.total_customers)
            revenue = i < nebula_mvp_idx ? "pre-MVP" : format_currency(f.revenue_k * 1000)
            write(file, "| ", f.month, " | ", new_cust, " | ", total_cust, " | ", revenue, " |\n")
        end

        write(file, "\n### Disclosure-NLU Firms\n\n")
        write(file, "| Month | Solo | Small | Medium | Large | BigLaw | Total | Revenue |\n")
        write(file, "|-------|------|-------|--------|-------|--------|-------|---------|")
        write(file, "\n")

        disclosure_mvp_idx = findfirst(f -> f.revenue_k > 0, disclosure_f)
        if disclosure_mvp_idx === nothing
            disclosure_mvp_idx = length(disclosure_f) + 1
        end

        for (i, f) in enumerate(disclosure_f[1:min(26, end)])
            solo = i < disclosure_mvp_idx ? "pre-MVP" : add_commas(f.total_solo)
            small = i < disclosure_mvp_idx ? "pre-MVP" : add_commas(f.total_small)
            medium = i < disclosure_mvp_idx ? "pre-MVP" : add_commas(f.total_medium)
            large = i < disclosure_mvp_idx ? "pre-MVP" : add_commas(f.total_large)
            biglaw = i < disclosure_mvp_idx ? "pre-MVP" : add_commas(f.total_biglaw)
            total = i < disclosure_mvp_idx ? "pre-MVP" : add_commas(f.total_clients)
            revenue = i < disclosure_mvp_idx ? "pre-MVP" : format_currency(f.revenue_k * 1000)
            write(file, "| ", f.month, " | ", solo, " | ", small, " | ", medium, " | ", large, " | ", biglaw, " | ", total, " | ", revenue, " |\n")
        end

        write(file, "\n### Lingua-NLU Pairs\n\n")
        write(file, "| Month | Active Pairs | Revenue |\n")
        write(file, "|-------|--------------|---------|")
        write(file, "\n")

        lingua_map_full = Dict(f.month => f for f in lingua_f)
        for month_name in plan.months[1:min(26, end)]
            if haskey(lingua_map_full, month_name)
                f = lingua_map_full[month_name]
                pairs = f.revenue_k > 0 ? add_commas(f.active_pairs) : "pre-MVP"
                revenue = f.revenue_k > 0 ? format_currency(f.revenue_k * 1000) : "pre-MVP"
                write(file, "| ", month_name, " | ", pairs, " | ", revenue, " |\n")
            end
        end
        write(file, "\n---\n\n")

        # SECTION 9: Revenue by Product (was Section 10)
        write(file, "## 9. Revenue by Product\n\n")
        write(file, "| Month | Nebula | Disclosure | Lingua | Total |\n")
        write(file, "|-------|--------|------------|--------|-------|")
        write(file, "\n")

        for month_name in plan.months[1:min(26, end)]
            neb_rev = get(nebula_map, month_name, 0.0)
            dis_rev = get(disclosure_map, month_name, 0.0)
            lin_rev = get(lingua_map, month_name, 0.0)
            total_rev = neb_rev + dis_rev + lin_rev

            write(file, "| ", month_name, " | ", format_currency(neb_rev * 1000), " | ", format_currency(dis_rev * 1000), " | ", format_currency(lin_rev * 1000), " | ", format_currency(total_rev * 1000), " |\n")
        end
        write(file, "\n---\n\n")

        # SECTION 10: Revenue by Channel (was Section 11)
        write(file, "## 10. Revenue by Channel\n\n")
        write(file, "### Nebula Channels\n")
        write(file, "- Retirement Communities: 1,920+ facilities\n")
        write(file, "- Public Libraries: 17,000+ branches\n")
        write(file, "- Direct Marketing\n")
        write(file, "- Referrals\n\n")
        write(file, "### Disclosure Channels\n\n")
        write(file, "| Type | Value | Cycle | Rep | Target/Year |\n")
        write(file, "|------|-------|-------|-----|-------------|\n")
        write(file, "| Solo | \$15K | 30d | SDR | 240 |\n")
        write(file, "| Small | \$50K | 60d | AE Mid | 180 |\n")
        write(file, "| Medium | \$150K | 90d | AE Mid | 36 |\n")
        write(file, "| Large | \$300K | 120d | AE Ent | 1-2 |\n")
        write(file, "| BigLaw | \$750K | 180d | AE Ent | 1 |\n\n")
        write(file, "### Lingua Channels\n")
        write(file, "- LinkedIn Marketing\n")
        write(file, "- Corporate Partnerships\n")
        write(file, "- Professional Networks\n")
        write(file, "- Referrals\n\n")
        write(file, "---\n\n")

        # SECTION 11: Valuation Analysis (was Section 12)
        write(file, "## 11. Valuation Analysis\n\n")

        dec_2026_total = get(nebula_map, "Dec 2026", 0.0) + get(disclosure_map, "Dec 2026", 0.0) + get(lingua_map, "Dec 2026", 0.0)
        dec_2026_arr = dec_2026_total * 12

        write(file, "### December 2026\n")
        write(file, "- Monthly: ", format_currency(dec_2026_total * 1000), "\n")
        write(file, "- ARR: ", format_currency(dec_2026_arr * 1000), "\n")
        write(file, "- Conservative (10x): ", format_currency(dec_2026_arr * 10 * 1000), "\n")
        write(file, "- Optimistic (15x): ", format_currency(dec_2026_arr * 15 * 1000), "\n\n")

        dec_2027_total = get(nebula_map, "Dec 2027", 0.0) + get(disclosure_map, "Dec 2027", 0.0) + get(lingua_map, "Dec 2027", 0.0)
        dec_2027_arr = dec_2027_total * 12

        write(file, "### December 2027\n")
        write(file, "- Monthly: ", format_currency(dec_2027_total * 1000), "\n")
        write(file, "- ARR: ", format_currency(dec_2027_arr * 1000), "\n")
        write(file, "- Conservative (12x): ", format_currency(dec_2027_arr * 12 * 1000), "\n")
        write(file, "- Optimistic (18x): ", format_currency(dec_2027_arr * 18 * 1000), "\n\n")
        write(file, "---\n\n")

        # SECTION 12: Revenue Realizations (was Section 13)
        write(file, "## 12. Revenue Realizations\n\n")
        write(file, "Single stochastic realization showing actual revenue trajectory.\n\n")
        write(file, "- Nebula: Dec 2025 MVP (no revenue) → Jan 2026 (200) → Apr 2026 (3,200) → May+ (533/mo)\n")
        write(file, "- Disclosure: Mar 2026 MVP, Large/BigLaw start Q3 2027\n")
        write(file, "- Lingua: Jul 2026 MVP, 67% match rate\n\n")
        write(file, "---\n\n")

        # SECTION 13: Financial Statements (was Section 14)
        write(file, "## 13. Financial Statements\n\n")

        # P&L Statements
        write(file, "### Profit & Loss Statement - 2025\n\n")
        write(file, "| Item | Amount |\n")
        write(file, "|------|-------:|\n")
        write(file, "| Revenue | ", format_currency(financial_data.pnl_2025.revenue, use_k_m=false), " |\n")
        write(file, "| Gemini LLM (20%) | ", format_currency(financial_data.pnl_2025.gemini, use_k_m=false), " |\n")
        write(file, "| Infrastructure (15%) | ", format_currency(financial_data.pnl_2025.infrastructure, use_k_m=false), " |\n")
        write(file, "| Google Credits | (", format_currency(financial_data.pnl_2025.google_credits, use_k_m=false), ") |\n")
        write(file, "| **COGS** | **", format_currency(financial_data.pnl_2025.cogs, use_k_m=false), "** |\n")
        write(file, "| **Gross Profit (100%)** | **", format_currency(financial_data.pnl_2025.gross_profit, use_k_m=false), "** |\n")
        write(file, "| Commission (25%) | ", format_currency(financial_data.pnl_2025.commission, use_k_m=false), " |\n")
        write(file, "| Subsidiary Costs | ", format_currency(financial_data.pnl_2025.subsidiary, use_k_m=false), " |\n")
        write(file, "| Administration Salaries | ", format_currency(financial_data.pnl_2025.admin, use_k_m=false), " |\n")
        write(file, "| Development (SAR only) | ", format_currency(financial_data.pnl_2025.dev, use_k_m=false), " |\n")
        write(file, "| **OpEx** | **", format_currency(financial_data.pnl_2025.opex, use_k_m=false), "** |\n")
        write(file, "| **EBIT** | **", format_currency(financial_data.pnl_2025.ebit, use_k_m=false), "** |\n")
        write(file, "| Interest | (", format_currency(financial_data.pnl_2025.interest, use_k_m=false), ") |\n")
        write(file, "| Taxes | (", format_currency(financial_data.pnl_2025.taxes, use_k_m=false), ") |\n")
        write(file, "| **Net Income** | **", format_currency(financial_data.pnl_2025.net_income, use_k_m=false), "** |\n\n")

        write(file, "### Profit & Loss Statement - 2026\n\n")
        write(file, "| Item | Amount |\n")
        write(file, "|------|-------:|\n")
        write(file, "| Revenue | ", format_currency(financial_data.pnl_2026.revenue), " |\n")
        write(file, "| Gemini LLM (20%) | ", format_currency(financial_data.pnl_2026.gemini), " |\n")
        write(file, "| Infrastructure (15%) | ", format_currency(financial_data.pnl_2026.infrastructure), " |\n")
        write(file, "| Google Credits | (", format_currency(financial_data.pnl_2026.google_credits), ") |\n")
        write(file, "| **COGS** | **", format_currency(financial_data.pnl_2026.cogs), "** |\n")
        write(file, "| **Gross Profit (100%)** | **", format_currency(financial_data.pnl_2026.gross_profit), "** |\n")
        write(file, "| Commission (25%) | ", format_currency(financial_data.pnl_2026.commission), " |\n")
        write(file, "| Subsidiary Costs | ", format_currency(financial_data.pnl_2026.subsidiary), " |\n")
        write(file, "| Admin Salaries | ", format_currency(financial_data.pnl_2026.admin), " |\n")
        write(file, "| Development (May-Dec) | ", format_currency(financial_data.pnl_2026.dev), " |\n")
        write(file, "| **OpEx** | **", format_currency(financial_data.pnl_2026.opex), "** |\n")
        write(file, "| **EBIT** | **", format_currency(financial_data.pnl_2026.ebit), "** |\n")
        write(file, "| Interest | (", format_currency(financial_data.pnl_2026.interest), ") |\n")
        write(file, "| Taxes | (", format_currency(financial_data.pnl_2026.taxes), ") |\n")
        write(file, "| **Net Income** | **", format_currency(financial_data.pnl_2026.net_income), "** |\n\n")

        write(file, "### Profit & Loss Statement - 2027\n\n")
        write(file, "| Item | Amount |\n")
        write(file, "|------|-------:|\n")
        write(file, "| Revenue | ", format_currency(financial_data.pnl_2027.revenue), " |\n")
        write(file, "| Gemini LLM (20%) | ", format_currency(financial_data.pnl_2027.gemini), " |\n")
        write(file, "| Infrastructure (15%) | ", format_currency(financial_data.pnl_2027.infrastructure), " |\n")
        write(file, "| Google Credits | (", format_currency(financial_data.pnl_2027.google_credits), ") |\n")
        write(file, "| **COGS** | **", format_currency(financial_data.pnl_2027.cogs), "** |\n")
        write(file, "| **Gross Profit (100%)** | **", format_currency(financial_data.pnl_2027.gross_profit), "** |\n")
        write(file, "| Commission (25%) | ", format_currency(financial_data.pnl_2027.commission), " |\n")
        write(file, "| Subsidiary Costs | ", format_currency(financial_data.pnl_2027.subsidiary), " |\n")
        write(file, "| Admin Salaries | ", format_currency(financial_data.pnl_2027.admin), " |\n")
        write(file, "| Development | ", format_currency(financial_data.pnl_2027.dev), " |\n")
        write(file, "| **OpEx** | **", format_currency(financial_data.pnl_2027.opex), "** |\n")
        write(file, "| **EBIT** | **", format_currency(financial_data.pnl_2027.ebit), "** |\n")
        write(file, "| Interest | (", format_currency(financial_data.pnl_2027.interest), ") |\n")
        write(file, "| Taxes | (", format_currency(financial_data.pnl_2027.taxes), ") |\n")
        write(file, "| **Net Income** | **", format_currency(financial_data.pnl_2027.net_income), "** |\n\n")

        write(file, "---\n\n")

        # Sources & Uses
        write(file, "### Sources & Uses of Funds - 2025\n\n")
        write(file, "| Sources | Amount | Uses | Amount |\n")
        write(file, "|---------|-------:|------|-------:|\n")
        max_rows = max(length(financial_data.sources_uses_2025["sources"]), length(financial_data.sources_uses_2025["uses"]))
        for i in 1:max_rows
            src_label = i <= length(financial_data.sources_uses_2025["sources"]) ? financial_data.sources_uses_2025["sources"][i][1] : ""
            src_amt = i <= length(financial_data.sources_uses_2025["sources"]) ? format_currency(financial_data.sources_uses_2025["sources"][i][2], use_k_m=false) : ""
            use_label = i <= length(financial_data.sources_uses_2025["uses"]) ? financial_data.sources_uses_2025["uses"][i][1] : ""
            use_amt = i <= length(financial_data.sources_uses_2025["uses"]) ? format_currency(financial_data.sources_uses_2025["uses"][i][2], use_k_m=false) : ""
            write(file, "| ", src_label, " | ", src_amt, " | ", use_label, " | ", use_amt, " |\n")
        end

        write(file, "\n### Sources & Uses of Funds - 2026\n\n")
        write(file, "| Sources | Amount | Uses | Amount |\n")
        write(file, "|---------|-------:|------|-------:|\n")
        max_rows = max(length(financial_data.sources_uses_2026["sources"]), length(financial_data.sources_uses_2026["uses"]))
        for i in 1:max_rows
            src_label = i <= length(financial_data.sources_uses_2026["sources"]) ? financial_data.sources_uses_2026["sources"][i][1] : ""
            src_amt = i <= length(financial_data.sources_uses_2026["sources"]) ? format_currency(financial_data.sources_uses_2026["sources"][i][2]) : ""
            use_label = i <= length(financial_data.sources_uses_2026["uses"]) ? financial_data.sources_uses_2026["uses"][i][1] : ""
            use_amt = i <= length(financial_data.sources_uses_2026["uses"]) ? format_currency(financial_data.sources_uses_2026["uses"][i][2]) : ""
            write(file, "| ", src_label, " | ", src_amt, " | ", use_label, " | ", use_amt, " |\n")
        end

        write(file, "\n### Sources & Uses of Funds - 2027\n\n")
        write(file, "| Sources | Amount | Uses | Amount |\n")
        write(file, "|---------|-------:|------|-------:|\n")
        max_rows = max(length(financial_data.sources_uses_2027["sources"]), length(financial_data.sources_uses_2027["uses"]))
        for i in 1:max_rows
            src_label = i <= length(financial_data.sources_uses_2027["sources"]) ? financial_data.sources_uses_2027["sources"][i][1] : ""
            src_amt = i <= length(financial_data.sources_uses_2027["sources"]) ? format_currency(financial_data.sources_uses_2027["sources"][i][2]) : ""
            use_label = i <= length(financial_data.sources_uses_2027["uses"]) ? financial_data.sources_uses_2027["uses"][i][1] : ""
            use_amt = i <= length(financial_data.sources_uses_2027["uses"]) ? format_currency(financial_data.sources_uses_2027["uses"][i][2]) : ""
            write(file, "| ", src_label, " | ", src_amt, " | ", use_label, " | ", use_amt, " |\n")
        end

        write(file, "\n---\n\n")

        # Balance Sheets
        write(file, "### Balance Sheets\n\n")

        write(file, "#### December 31, 2025\n\n")
        write(file, "| Assets | Amount | Liabilities & Equity | Amount |\n")
        write(file, "|--------|-------:|----------------------|-------:|\n")
        write(file, "| Cash & Investments | ", format_currency(financial_data.balance_2025.cash, use_k_m=false), " | Accounts Payable | ", format_currency(financial_data.balance_2025.ap, use_k_m=false), " |\n")
        write(file, "| Intellectual Property* | ", format_currency(financial_data.balance_2025.ip_assets, use_k_m=false), " | Deferred Revenue | ", format_currency(financial_data.balance_2025.deferred_revenue, use_k_m=false), " |\n")
        write(file, "| **Total Assets** | **", format_currency(financial_data.balance_2025.total_assets, use_k_m=false), "** | **Total Liabilities** | **", format_currency(financial_data.balance_2025.total_liabilities, use_k_m=false), "** |\n")
        write(file, "| | | Nebula Valuation | ", format_currency(financial_data.balance_2025.nebula_valuation, use_k_m=false), " |\n")
        write(file, "| | | **Total Equity** | **", format_currency(financial_data.balance_2025.total_equity, use_k_m=false), "** |\n\n")
        write(file, "*Pre-existing software platform contributed at formation\n\n")

        write(file, "#### December 31, 2026\n\n")
        write(file, "| Assets | Amount | Liabilities & Equity | Amount |\n")
        write(file, "|--------|-------:|----------------------|-------:|\n")
        write(file, "| Cash & Investments | ", format_currency(financial_data.balance_2026.cash), " | Accounts Payable | ", format_currency(financial_data.balance_2026.ap), " |\n")
        write(file, "| Intellectual Property | ", format_currency(financial_data.balance_2026.ip_assets), " | Deferred Revenue | ", format_currency(financial_data.balance_2026.deferred_revenue), " |\n")
        write(file, "| **Total Assets** | **", format_currency(financial_data.balance_2026.total_assets), "** | **Total Liabilities** | **", format_currency(financial_data.balance_2026.total_liabilities), "** |\n")
        write(file, "| | | Nebula Valuation | ", format_currency(financial_data.balance_2026.nebula_valuation), " |\n")
        write(file, "| | | **Total Equity** | **", format_currency(financial_data.balance_2026.total_equity), "** |\n\n")

        write(file, "#### December 31, 2027\n\n")
        write(file, "| Assets | Amount | Liabilities & Equity | Amount |\n")
        write(file, "|--------|-------:|----------------------|-------:|\n")
        write(file, "| Cash & Investments | ", format_currency(financial_data.balance_2027.cash), " | Accounts Payable | ", format_currency(financial_data.balance_2027.ap), " |\n")
        write(file, "| Intellectual Property | ", format_currency(financial_data.balance_2027.ip_assets), " | Deferred Revenue | ", format_currency(financial_data.balance_2027.deferred_revenue), " |\n")
        write(file, "| **Total Assets** | **", format_currency(financial_data.balance_2027.total_assets), "** | **Total Liabilities** | **", format_currency(financial_data.balance_2027.total_liabilities), "** |\n")
        write(file, "| | | Nebula Valuation | ", format_currency(financial_data.balance_2027.nebula_valuation), " |\n")
        write(file, "| | | **Total Equity** | **", format_currency(financial_data.balance_2027.total_equity), "** |\n\n")

        write(file, "---\n\n")
        timestamp = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
        write(file, "*Generated: ", timestamp, "*\n")
    end
    println("✅ Generated: NLU_Strategic_Plan_Complete.md (13 sections)")
end

function generate_founder_capitalization_file(plan, milestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)
    open("NLU_Founder_Capitalization.md", "w") do file
        write(file, "# 🔒 NLU PORTFOLIO - FOUNDER CAPITALIZATION\n\n")
        write(file, "**⚠️ CONFIDENTIAL - FOUNDER ONLY**\n\n")
        write(file, "This document contains sensitive compensation and equity information.\n\n")
        write(file, "---\n\n")

        # Commission Sales Force
        write(file, "## Commission-Only Sales Force\n\n")
        write(file, "**All roles: 25% commission + SAR equity**\n\n")
        write(file, "**No cash salaries Nov 2025 - Apr 2026 (SAR compensation only)**\n\n")
        write(file, "| Role | SAR Shares | Equity % | Commission | Start | Responsibility |\n")
        write(file, "|------|------------|----------|------------|-------|----------------|\n")
        write(file, "| Part-Time Dev #1 | ", add_commas(25000), " | 0.5% | - | Oct 2025 | Platform dev |\n")
        write(file, "| Part-Time Dev #2 | ", add_commas(25000), " | 0.5% | - | Jan 2026 | Platform dev |\n")
        write(file, "| Sales Closer #1 | ", add_commas(50000), " | 1.0% | 25% | Jan 2026 | Nebula direct |\n")
        write(file, "| Part-Time Dev #3 | ", add_commas(25000), " | 0.5% | - | Apr 2026 | Platform dev |\n")
        write(file, "| AE Mid-Market | ", add_commas(50000), " | 1.0% | 25% | Mar 2026 | Small/Medium |\n")
        write(file, "| Channel Partner | ", add_commas(50000), " | 1.0% | 25% | Apr 2026 | Retirement |\n")
        write(file, "| SDR Disclosure | ", add_commas(25000), " | 0.5% | 25% | May 2026 | Solo firms |\n")
        write(file, "| Junior Dev FT | ", add_commas(50000), " | 1.0% | - | Jun 2026 | Full-time dev |\n")
        write(file, "| AE Enterprise | ", add_commas(75000), " | 1.5% | 25% | Jun 2026 | BigLaw/Large |\n")
        write(file, "| Sales Closer #2 | ", add_commas(50000), " | 1.0% | 25% | Jul 2026 | Lingua pairs |\n")
        write(file, "| AE Lingua Mid-Market #1 | 50,000 | 1.0% | Jul 2026 | 24 months | ", raw"$1,080K" * " |\n")
        write(file, "| AE Lingua Mid-Market #2 | 50,000 | 1.0% | Aug 2026 | 24 months | ", raw"$1,080K" * " |\n")
        write(file, "| AE Lingua Enterprise #1 | 75,000 | 1.5% | Sep 2026 | 24 months | ", raw"$1,620K" * " |\n")
        write(file, "| AE Lingua Enterprise #2 | 75,000 | 1.5% | Oct 2026 | 24 months | ", raw"$1,620K" * " |\n")
        write(file, "| VP Sales Lingua | 100,000 | 2.0% | Nov 2026 | 24 months | ", raw"$2,160K" * " |\n")
        write(file, "| Mid-Level Dev | ", add_commas(75000), " | 1.5% | - | Sep 2026 | Full-time dev |\n")
        write(file, "| Senior Dev | ", add_commas(100000), " | 2.0% | - | Dec 2026 | Full-time dev |\n\n")
        write(file, "**Total SAR Outstanding by Dec 2026:** 875,000 shares (17.5% of 5M authorized)\n\n")
        write(file, "---\n\n")

        # Capitalization Table
        write(file, "## Capitalization Table\n\n")
        write(file, "### Share Allocation at Formation (Nov 2025)\n\n")
        write(file, "| Shareholder | Shares | % | Notes |\n")
        write(file, "|-------------|--------|---|-------|\n")
        write(file, "| Founder (You) | 4,000,000 | 80.0% | For \$650K IP contribution |\n")
        write(file, "| SAR Plan (vesting) | 100,000 | 2.0% | Part-time devs, Sales #1 |\n")
        write(file, "| **Subtotal Allocated** | **4,100,000** | **82.0%** | |\n")
        write(file, "| **Available for issuance** | **900,000** | **18.0%** | Pre-angel pool |\n")
        write(file, "| **Total Authorized** | **5,000,000** | **100.0%** | |\n\n")

        write(file, "### Projected Post-Angel (Jul 2026)\n\n")
        write(file, "| Shareholder | Shares | % (Diluted) | Value @ \$2.25M post |\n")
        write(file, "|-------------|--------|-------------|---------------------|\n")
        write(file, "| Founder | 4,000,000 | 64.3% | \$1,447K |\n")
        write(file, "| Dev Team (converted) | 300,000 | 4.8% | \$108K |\n")
        write(file, "| Sales Team (converted) | 650,000 | 10.5% | \$236K |\n")
        write(file, "| Executives (hired) | 275,000 | 4.4% | \$99K |\n")
        write(file, "| Angel Investors | 735,294 | 11.8% | \$265K |\n")
        write(file, "| **Outstanding** | **5,960,294** | **95.8%** | |\n")
        write(file, "| **C-Level Pool (remaining)** | **175,000** | **2.8%** | CFO/CTO slots |\n")
        write(file, "| **VP/Director Pool (remaining)** | **100,000** | **1.6%** | Senior hires |\n")
        write(file, "| **Total Fully Diluted** | **6,235,294** | **100.0%** | \$2,250K post-money |\n\n")

        # Enhancement #1: Planned Key Hires Section
        write(file, "### Planned Key Hires (Pre-Series A)\n\n")
        write(file, "| Role | Timing | Equity Pool | Strategic Rationale |\n")
        write(file, "|------|--------|-------------|---------------------|\n")
        write(file, "| CFO | Q1 2027 | C-Level (2.8%) | Financial controls, Series A prep |\n")
        write(file, "| CTO (if needed) | Q2 2027 | C-Level (2.8%) | Technical architecture scaling |\n")
        write(file, "| VP Engineering | Q4 2026 | VP/Director (1.6%) | Dev team leadership |\n")
        write(file, "| VP Sales | Q1 2027 | VP/Director (1.6%) | Revenue acceleration |\n\n")
        write(file, "**Rationale:** CFO hire 6 months before Series A is standard. CTO optional if founder remains technical lead.\n\n")

        write(file, "### Projected Post-Series A (Jul 2027)\n\n")
        write(file, "| Shareholder | Shares* | % (Final) | Value @ \$108M |\n")
        write(file, "|-------------|---------|-----------|----------------|\n")
        write(file, "| Founder | 40,000,000 | 56.3% | \$60.8M |\n")
        write(file, "| SAR Plan | 5,000,000 | 7.0% | \$7.6M |\n")
        write(file, "| Angel Investors | 7,352,940 | 10.3% | \$11.1M |\n")
        write(file, "| Series A Investors | 18,750,000 | 26.4% | \$28.5M |\n")
        write(file, "| **Total Outstanding** | **71,102,940** | **100.0%** | **\$108M** |\n\n")
        write(file, "*Assumes 10:1 stock split before Series A\n\n")

        write(file, "### Share Availability Tracking\n\n")
        write(file, "| Milestone | Allocated | Available | Total Auth | % Available |\n")
        write(file, "|-----------|-----------|-----------|------------|-------------|\n")
        write(file, "| Formation (Nov 2025) | 4,100,000 | 900,000 | 5,000,000 | 18.0% |\n")
        write(file, "| Pre-Angel (Jun 2026) | 4,400,000 | 600,000 | 5,000,000 | 12.0% |\n")
        write(file, "| Post-Angel (Jul 2026) | 5,135,294 | 750,000 | 5,885,294 | 12.7% |\n")
        write(file, "| Pre-Series A (Jun 2027) | 5,450,000 | 435,294 | 5,885,294 | 7.4% |\n")
        write(file, "| Post-Series A (Jul 2027) | 71,102,940 | 8,897,060 | 80,000,000 | 11.1% |\n\n")

        write(file, "### Anti-Dilution Provisions\n\n")
        write(file, "**Angel Round Terms:**\n")
        write(file, "- Standard weighted-average anti-dilution protection\n")
        write(file, "- Pro-rata rights for subsequent rounds\n")
        write(file, "- 1x liquidation preference, non-participating\n\n")
        write(file, "**Series A Terms (projected):**\n")
        write(file, "- Weighted-average anti-dilution (typical VC standard)\n")
        write(file, "- Pro-rata rights + super pro-rata (up to 2x initial investment)\n")
        write(file, "- 1x liquidation preference, participating cap at 3x\n\n")
        write(file, "These terms align with NVCA model documents and are standard for institutional rounds.\n\n")

        # Board Composition Section (after Anti-Dilution Provisions)
        write(file, "### Board Composition\n\n")
        write(file, "**Post-Angel Round (Jul 2026):**\n\n")
        write(file, "| Seat | Member | Voting Rights | Notes |\n")
        write(file, "|------|--------|---------------|-------|\n")
        write(file, "| Chair | Founder | Yes | Retains board control |\n")
        write(file, "| Observer | Lead Angel Rep | No | Advisory role, no vote |\n")
        write(file, "| **Total** | **2 members** | **1 voting** | Founder maintains control |\n\n")

        write(file, "**Post-Series A Round (Jul 2027):**\n\n")
        write(file, "| Seat | Member | Appointed By | Voting Rights |\n")
        write(file, "|------|--------|--------------|---------------|\n")
        write(file, "| Chair | Founder (CEO) | Founders | Yes |\n")
        write(file, "| Member | Co-Founder/CTO* | Founders | Yes |\n")
        write(file, "| Member | Series A Lead Partner | Series A Investors | Yes |\n")
        write(file, "| Member | Angel Representative | Angel Investors | Yes |\n")
        write(file, "| Independent | Industry Expert | Unanimous approval | Yes |\n")
        write(file, "| **Total** | **5 seats** | | **5 voting** |\n\n")
        write(file, "*If no co-founder, second seat goes to independent director agreed by all parties\n\n")

        write(file, "**Board Meeting Cadence:**\n")
        write(file, "- Pre-Angel: Quarterly informal updates\n")
        write(file, "- Post-Angel: Quarterly formal board meetings\n")
        write(file, "- Post-Series A: Monthly board meetings + quarterly strategic reviews\n\n")

        write(file, "**Key Governance Provisions:**\n")
        write(file, "- Founder retains operational control through Series A\n")
        write(file, "- Material decisions require board majority (acquisitions \$500K, new funding rounds)\n")
        write(file, "- Independent director ensures alignment between founders and investors\n")
        write(file, "- Standard protective provisions per NVCA model documents\n\n")

        write(file, "---\n\n")

        # SAR Footnote
        write(file, "## Stock Appreciation Rights (SAR) Plan\n\n")
        write(file, "**Outstanding SAR grants as of December 31, 2026:**\n\n")
        write(file, "| Role | Shares | % | Start Date | Vesting | Value @ \$108M |\n")
        write(file, "|------|--------|---|------------|---------|----------------|\n")
        write(file, "| Part-Time Dev #1 | 25,000 | 0.5% | Oct 2025 | 24 months | \$540K |\n")
        write(file, "| Part-Time Dev #2 | 25,000 | 0.5% | Jan 2026 | 24 months | \$540K |\n")
        write(file, "| Sales Closer #1 | 50,000 | 1.0% | Jan 2026 | 24 months | \$1,080K |\n")
        write(file, "| Part-Time Dev #3 | 25,000 | 0.5% | Apr 2026 | 24 months | \$540K |\n")
        write(file, "| AE Mid-Market | 50,000 | 1.0% | Mar 2026 | 24 months | \$1,080K |\n")
        write(file, "| Channel Partner | 50,000 | 1.0% | Apr 2026 | 24 months | \$1,080K |\n")
        write(file, "| SDR Disclosure | 25,000 | 0.5% | May 2026 | 24 months | \$540K |\n")
        write(file, "| Junior Dev FT | 50,000 | 1.0% | Jun 2026 | 24 months | \$1,080K |\n")
        write(file, "| AE Enterprise | 75,000 | 1.5% | Jun 2026 | 24 months | \$1,620K |\n")
        write(file, "| Sales Closer #2 | 50,000 | 1.0% | Jul 2026 | 24 months | \$1,080K |\n")
        write(file, "| SDR Lingua | 25,000 | 0.5% | Aug 2026 | 24 months | \$540K |\n")
        write(file, "| Mid-Level Dev | 75,000 | 1.5% | Sep 2026 | 24 months | \$1,620K |\n")
        write(file, "| Senior Dev | 100,000 | 2.0% | Dec 2026 | 24 months | \$2,160K |\n")
        write(file, "| **Total Outstanding** | **625,000** | **12.5%** | | | **\$13.5M** |\n\n")
        write(file, "**Founder Ownership:** 4,000,000 shares (80.0% at formation, 56.3% post-Series A)\n\n")
        write(file, "SAR grants vest over 24 months. Not recorded on balance sheet until exercised per ASC 718.\n\n")

        write(file, "---\n\n")
        timestamp = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
        write(file, "*Generated: ", timestamp, "*\n")
    end
    println("✅ Generated: NLU_Founder_Capitalization.md (CONFIDENTIAL)")
end

end # module ReportGenerators