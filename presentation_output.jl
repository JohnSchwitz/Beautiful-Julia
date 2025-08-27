module PresentationOutput

using DataFrames, StatsPlots, Random, Distributions, Printf

export generate_spreadsheet_output, generate_distribution_plots, generate_revenue_variability_plot

function generate_distribution_plots(params::Dict{String,Dict{String,Float64}})
    println("✅ Generating distribution plots...")
    Random.seed!(42)
    nebula_p = params["Nebula-NLU"]
    poisson_customers = Poisson(nebula_p["lambda_jan_2026"])
    beta_purchase = Beta(nebula_p["alpha_purchase"], nebula_p["beta_purchase"])
    beta_churn = Beta(nebula_p["alpha_churn"], nebula_p["beta_churn"])
    customer_draws = [rand(poisson_customers) for _ in 1:10]
    purchase_draws = [rand(beta_purchase) for _ in 1:10]
    churn_draws = [rand(beta_churn) for _ in 1:10]
    p1 = plot(poisson_customers, (poisson_customers.λ-40):(poisson_customers.λ+40), title="Customer Acquisition\nPoisson(λ=$(round(Int,poisson_customers.λ)))", xlabel="New Customers", ylabel="Probability", lw=3, legend=false)
    scatter!(p1, customer_draws, [pdf(poisson_customers, x) for x in customer_draws], ms=5, color=:red)
    p2 = plot(beta_purchase, 0:0.01:1, title="Purchase Rate\nBeta(α=$(beta_purchase.α), β=$(beta_purchase.β))", xlabel="Purchase Rate", ylabel="Density", lw=3, color=:green, legend=false)
    scatter!(p2, purchase_draws, [pdf(beta_purchase, x) for x in purchase_draws], ms=5, color=:red)
    p3 = plot(beta_churn, 0:0.01:1, title="Annual Churn Rate\nBeta(α=$(beta_churn.α), β=$(beta_churn.β))", xlabel="Annual Churn Rate", ylabel="Density", lw=3, color=:purple, legend=false)
    scatter!(p3, churn_draws, [pdf(beta_churn, x) for x in churn_draws], ms=5, color=:red)
    display(plot(p1, p2, p3, layout=(1, 3), size=(1200, 350), plot_title="Key Revenue Driver Distributions with 10 Sample Draws (Nebula-NLU)"))
end

function generate_revenue_variability_plot(nebula_f, disclosure_f, lingua_f, params)
    println("✅ Generating revenue variability plot...")
    Random.seed!(123)
    n_scenarios = 10
    nebula_p = params["Nebula-NLU"]
    disclosure_p = params["Disclosure-NLU"]
    lingua_p = params["Lingua-NLU"]
    final_nebula_customers = nebula_f[end].total_customers
    final_disclosure_clients = disclosure_f[end]
    final_lingua_users = round(Int, lingua_f[end].active_pairs / get(params["Lingua-NLU"], "mean_match_success", 0.6))
    scenarios = []
    for i in 1:n_scenarios
        nebula_revenue = final_nebula_customers * rand(Beta(nebula_p["alpha_purchase"], nebula_p["beta_purchase"])) * 20.0  # Updated to $20
        disclosure_revenue = (final_disclosure_clients.total_solo * disclosure_p["solo_revenue_multiplier"] + final_disclosure_clients.total_small * disclosure_p["small_revenue_multiplier"] + final_disclosure_clients.total_medium * disclosure_p["medium_revenue_multiplier"]) * disclosure_p["base_monthly_cost"] * (1 + 0.1 * (rand() - 0.5))
        lingua_revenue = final_lingua_users * rand(Beta(lingua_p["alpha_match_success"], lingua_p["beta_match_success"])) * 59.0
        push!(scenarios, (nebula=nebula_revenue / 1000, disclosure=disclosure_revenue / 1000, lingua=lingua_revenue / 1000))
    end
    nebula_revs = [s.nebula for s in scenarios]
    disclosure_revs = [s.disclosure for s in scenarios]
    lingua_revs = [s.lingua for s in scenarios]
    p = groupedbar([nebula_revs disclosure_revs lingua_revs], bar_position=:dodge, title="Revenue Variability - 10 Independent Scenarios (Dec 2026)", xlabel="Scenario Number", ylabel="Revenue (k\$)", labels=["Nebula-NLU" "Disclosure-NLU" "Lingua-NLU"], size=(1000, 500), lw=0)
    display(p)
end

function _tsv_resource_summary(initial_tasks, hours)
    println("\n\n📊 RESOURCE SUMMARY")
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")
    println("Track\tTotal Task Months\tAvailable Capacity\tUtilization %\tBuffer Months")
    hours_per_month = 240
    tracks = ["Development", "Marketing"]
    total_months = [round(Int, sum(t.planned_hours for t in initial_tasks if t.task_type == track) / hours_per_month) for track in tracks]
    available_months = [round(Int, hours.cumulative_dev[end] / hours_per_month), round(Int, hours.cumulative_marketing[end] / hours_per_month)]
    utilization = [round(Int, (total_months[i] / available_months[i]) * 100) for i in 1:2]
    buffer = available_months .- total_months
    for i in 1:length(tracks)
        println("$(tracks[i])\t$(total_months[i])\t$(available_months[i])\t$(utilization[i])%\t$(buffer[i])")
    end
    println("```")
end

function _tsv_strategic_milestones(milestones, plan)
    println("\n\n🎯 MILESTONE SCHEDULE")
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")
    println("Milestone\tComponents\tCompletion Date\tStatus")
    strategic_map = [
        ("Infrastructure Complete", ["Infrastructure"]),
        ("Nebula-NLU MVP", ["Nebula-NLU MVP"]),
        ("Disclosure-NLU MVP", ["Disclosure - Doc Upload", "Disclosure - Preprocessing", "Disclosure - Batch System", "Disclosure - VS2.0 Integration", "Disclosure - Query Engine", "Disclosure - Gemini Summaries", "Disclosure - BFF API", "Disclosure - Attorney Dashboard", "Disclosure - Case Management", "Disclosure - Advanced Search UI", "Disclosure - Doc Viewer", "Disclosure - Mobile UI"]),
        ("Nebula-NLU Scale", ["Nebula-NLU Scale"]),
        ("Marketing Foundation", ["Mktg Digital Foundation"]),
        ("Content & Lead Generation", ["Content & Lead Generation"]),
        ("Advanced Marketing Operations", ["Advanced Operations"]),
        ("Lingua-NLU MVP", ["Lingua-NLU MVP"]),
        ("Disclosure-NLU Enterprise", ["Disclosure - Multi-user Mgmt", "Disclosure - Security/Compliance", "Disclosure - Integrations", "Disclosure - Analytics", "Disclosure - Custom Deployment", "Disclosure - Advanced Legal AI", "Disclosure - Large Law Firm Feat", "Disclosure - Conference Platform", "Disclosure - Corp Legal Tools", "Disclosure - Market Expansion"])
    ]
    aug_2025_idx = findfirst(==("Aug 2025"), plan.months)
    for (name, components) in strategic_map
        component_milestones = filter(m -> m.task in components, milestones)
        if isempty(component_milestones)
            continue
        end
        dates = [m.milestone_date for m in component_milestones]
        month_indices = [findfirst(==(d), plan.months) for d in dates if d != "Beyond Plan"]
        final_date = isempty(month_indices) ? "Beyond Plan" : plan.months[maximum(month_indices)]
        current_milestone_idx = findfirst(==(final_date), plan.months)
        status = "ON TIME"
        if final_date == "Beyond Plan"
            status = "DELAYED"
        elseif current_milestone_idx !== nothing && aug_2025_idx !== nothing && current_milestone_idx > aug_2025_idx
            status = "PLANNED"
        end
        comp_str = length(components) > 2 ? "$(components[1]) ... $(components[end])" : join(components, ", ")
        println("$(name)\t$(comp_str)\t$(final_date)\t$(status)")
    end
    println("```")
end

function _tsv_hiring_schedule(plan)
    println("\n\n📅 HIRING & RESOURCE SCHEDULE")
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")
    println("Month\tExp. Devs\tIntern Devs\tExp. Marketers\tIntern Marketers")
    for i in 1:length(plan.months)
        println("$(plan.months[i])\t$(plan.experienced_devs[i])\t$(plan.intern_devs[i])\t$(plan.experienced_marketers[i])\t$(plan.intern_marketers[i])")
    end
    println("```")
end

function _tsv_activity_indicators(plan, nebula_f, disclosure_f, lingua_f)
    println("\n\n📈 NLU ACTIVITY INDICATORS")
    nebula_mvp_idx = findfirst(f -> f.revenue_k > 0, nebula_f)
    disclosure_mvp_idx = findfirst(f -> f.revenue_k > 0, disclosure_f)

    println("\nNEBULA-NLU CUSTOMER METRICS (Enhanced Model)")
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")
    println("Month\tNew Customers\tTotal Customers\tActive Users\tRevenue Model")
    for (i, f) in enumerate(nebula_f)
        new_cust = i < nebula_mvp_idx ? "pre-MVP" : string(f.new_customers)
        total_cust = i < nebula_mvp_idx ? "pre-MVP" : string(f.total_customers)
        active_users = i < nebula_mvp_idx ? "pre-MVP" : string(round(Int, f.total_customers * f.avg_purchases_per_customer))
        revenue_model = i < nebula_mvp_idx ? "pre-MVP" : "Immediate+Delayed"
        println("$(f.month)\t$(new_cust)\t$(total_cust)\t$(active_users)\t$(revenue_model)")
    end
    println("```")

    println("\nDISCLOSURE-NLU LEGAL FIRM METRICS")
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")
    println("Month\tSolo Firms\tSmall Firms\tMedium Firms\tTotal Firms")
    for (i, f) in enumerate(disclosure_f)
        solo = i < disclosure_mvp_idx ? "pre-MVP" : string(f.total_solo)
        small = i < disclosure_mvp_idx ? "pre-MVP" : string(f.total_small)
        medium = i < disclosure_mvp_idx ? "pre-MVP" : string(f.total_medium)
        total = i < disclosure_mvp_idx ? "pre-MVP" : string(f.total_clients)
        println("$(f.month)\t$(solo)\t$(small)\t$(medium)\t$(total)")
    end
    println("```")

    println("\nLINGUA-NLU PROFESSIONAL NETWORK METRICS")
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")
    println("Month\tActive Pairs")
    lingua_map = Dict(f.month => f for f in lingua_f)
    for month_name in plan.months
        if haskey(lingua_map, month_name)
            f = lingua_map[month_name]
            pairs = f.revenue_k > 0 ? string(f.active_pairs) : "pre-MVP"
            println("$(month_name)\t$(pairs)")
        end
    end
    println("```")
end

function _tsv_revenue_by_product(plan, nebula_f, disclosure_f, lingua_f)
    println("\n\n💰 NLU REVENUE BY PRODUCT")
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")
    println("Month\tNebula-NLU (k\$)\tDisclosure-NLU (k\$)\tLingua-NLU (k\$)\tTOTAL (k\$)")
    nebula_map = Dict(f.month => f.revenue_k * 2.0 for f in nebula_f)  # Apply $20 pricing
    disclosure_map = Dict(f.month => f.revenue_k for f in disclosure_f)
    lingua_map = Dict(f.month => f.revenue_k for f in lingua_f)
    for month_name in plan.months
        neb_rev = get(nebula_map, month_name, 0.0)
        dis_rev = get(disclosure_map, month_name, 0.0)
        lin_rev = get(lingua_map, month_name, 0.0)
        total_rev = neb_rev + dis_rev + lin_rev
        neb_str = neb_rev > 0 ? string(round(Int, neb_rev)) : "pre-MVP"
        dis_str = dis_rev > 0 ? string(round(Int, dis_rev)) : "pre-MVP"
        lin_str = lin_rev > 0 ? string(round(Int, lin_rev)) : "pre-MVP"
        total_str = total_rev > 0 ? string(round(Int, total_rev)) : "pre-MVP"
        println("$(month_name)\t$(neb_str)\t$(dis_str)\t$(lin_str)\t$(total_str)")
    end
    println("```")
end

function _tsv_valuation_analysis(plan, nebula_f, disclosure_f, lingua_f)
    println("\n\n💼 VALUATION ANALYSIS")
    function _valuation_snapshot(month_name, conservative_mult, optimistic_mult, ownership_pct)
        println("\n$(uppercase(month_name)) VALUATION")
        println("Copy the table below and paste it into Google Sheets.")
        println("```tsv")
        println("Metric\tValue")
        neb_rev = get(Dict(f.month => f.revenue_k * 2.0 for f in nebula_f), month_name, 0.0)  # Apply $20 pricing
        dis_rev = get(Dict(f.month => f.revenue_k for f in disclosure_f), month_name, 0.0)
        lin_rev = get(Dict(f.month => f.revenue_k for f in lingua_f), month_name, 0.0)
        total_rev_k = neb_rev + dis_rev + lin_rev
        arr_m = (total_rev_k * 12) / 1000
        println("Combined Monthly Revenue\t\$$(round(Int, total_rev_k))k")
        println("Implied Annual Recurring Revenue (ARR)\t\$$(round(arr_m, digits=2))M")
        println("Conservative Valuation ($(Int(conservative_mult))x ARR)\t\$$(round(arr_m * conservative_mult, digits=1))M")
        println("Optimistic Valuation ($(Int(optimistic_mult))x ARR)\t\$$(round(arr_m * optimistic_mult, digits=1))M")
        println("Founder Equity - Conservative\t\$$(round(arr_m * conservative_mult * ownership_pct, digits=1))M")
        println("Founder Equity - Optimistic\t\$$(round(arr_m * optimistic_mult * ownership_pct, digits=1))M")
        println("```")
    end
    _valuation_snapshot("Mar 2026", 8, 12, 0.85)
    _valuation_snapshot("Dec 2026", 10, 15, 0.70)
end

function _tsv_probability_documentation(params)
    println("\n\n🎲 PROBABILITY ANALYSIS & BUSINESS MODEL PARAMETERS")
    println("="^60)
    println("This section documents the statistical models used for the simulation.")
    nebula_p = params["Nebula-NLU"]
    disclosure_p = params["Disclosure-NLU"]
    lingua_p = params["Lingua-NLU"]
    doc_string = """
    ### NEBULA-NLU ENHANCED STOCHASTIC MODEL
    **Customer Acquisition**: Poisson Distribution
    - Oct 2025: λ = $(round(Int, nebula_p["lambda_oct_2025"]))
    - Jan 2026: λ = $(round(Int, nebula_p["lambda_jan_2026"]))
    - Jul 2026: λ = $(round(Int, nebula_p["lambda_jul_2026"]))

    **Purchase Behavior**: Two-Phase Model
    - Immediate Purchase Rate: 70% (buy in acquisition month)
    - Delayed Purchase Rate: 30% (buy in following month)
    - Cutoff: No purchases after 2 months
    - Base Conversion: Beta(α=$(nebula_p["alpha_purchase"]), β=$(nebula_p["beta_purchase"]))
    - Mean purchase rate: $(round(nebula_p["alpha_purchase"] / (nebula_p["alpha_purchase"] + nebula_p["beta_purchase"]) * 100, digits=1))%

    **Enhanced Annual Churn**: Beta Distribution (α=$(nebula_p["alpha_churn"]), β=$(nebula_p["beta_churn"]))
    - Includes normal churn + customers who "disappear" without purchasing
    - Enhanced early probability mass captures non-converting prospects
    - Base mean churn: $(round(nebula_p["alpha_churn"] / (nebula_p["alpha_churn"] + nebula_p["beta_churn"]) * 100, digits=1))%

    ### DISCLOSURE-NLU STOCHASTIC MODEL
    **Firm Acquisition**: Poisson Distribution
    - Solo Firms: λ = $(disclosure_p["lambda_solo_firms"])
    - Small Firms: λ = $(disclosure_p["lambda_small_firms"])
    - Medium Firms: λ = $(disclosure_p["lambda_medium_firms"])
    **Revenue Model**: Multiplier-based
    - Base Cost: \$$(disclosure_p["base_monthly_cost"])
    - Multipliers: Solo=$(disclosure_p["solo_revenue_multiplier"])x, Small=$(disclosure_p["small_revenue_multiplier"])x, Medium=$(disclosure_p["medium_revenue_multiplier"])x

    ### LINGUA-NLU STOCHASTIC MODEL
    **Premium User Acquisition**: Poisson Distribution
    - Jul 2026: λ = $(lingua_p["lambda_premium_users_jul"])
    - Dec 2026: λ = $(lingua_p["lambda_premium_users_dec"])
    **Match Success**: Beta Distribution (α=$(lingua_p["alpha_match_success"]), β=$(lingua_p["beta_match_success"]))
    - Mean match success rate: $(round(lingua_p["alpha_match_success"] / (lingua_p["alpha_match_success"] + lingua_p["beta_match_success"]) * 100, digits=1))%
    """
    println(doc_string)
end

function generate_spreadsheet_output(plan, milestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)
    println("📋 STRATEGIC PLAN DATA (for Google Sheets)")
    println("="^60)

    # ========== REVENUE SUMMARY BY PRODUCT BY YEAR (NEW) ==========
    println("\n\n💎 REVENUE SUMMARY BY PRODUCT BY YEAR")
    println("="^50)
    println("Copy the table below and paste it into Google Sheets.")
    println("```tsv")
    println("Product\t2025 Revenue (k\$)\t2026 Revenue (k\$)\tTotal Revenue (k\$)")

    # Calculate 2025 totals (Sep-Dec only)
    nebula_2025 = sum(f.revenue_k for f in nebula_f if f.month in ["Sep 2025", "Oct 2025", "Nov 2025", "Dec 2025"]) * 2.0  # $20 pricing
    disclosure_2025 = sum(f.revenue_k for f in disclosure_f if f.month in ["Sep 2025", "Oct 2025", "Nov 2025", "Dec 2025"])
    lingua_2025 = sum(f.revenue_k for f in lingua_f if f.month in ["Sep 2025", "Oct 2025", "Nov 2025", "Dec 2025"])

    # Calculate 2026 totals (Jan-Dec)
    months_2026 = ["Jan 2026", "Feb 2026", "Mar 2026", "Apr 2026", "May 2026", "Jun 2026",
        "Jul 2026", "Aug 2026", "Sep 2026", "Oct 2026", "Nov 2026", "Dec 2026"]
    nebula_2026 = sum(f.revenue_k for f in nebula_f if f.month in months_2026) * 2.0  # $20 pricing
    disclosure_2026 = sum(f.revenue_k for f in disclosure_f if f.month in months_2026)
    lingua_2026 = sum(f.revenue_k for f in lingua_f if f.month in months_2026)

    # Print summary
    println("Nebula-NLU (\$20/month)\t$(round(nebula_2025, digits=1))\t$(round(nebula_2026, digits=1))\t$(round(nebula_2025 + nebula_2026, digits=1))")
    println("Disclosure-NLU (Legal)\t$(round(disclosure_2025, digits=1))\t$(round(disclosure_2026, digits=1))\t$(round(disclosure_2025 + disclosure_2026, digits=1))")
    println("Lingua-NLU (Matching)\t$(round(lingua_2025, digits=1))\t$(round(lingua_2026, digits=1))\t$(round(lingua_2025 + lingua_2026, digits=1))")

    total_2025 = nebula_2025 + disclosure_2025 + lingua_2025
    total_2026 = nebula_2026 + disclosure_2026 + lingua_2026
    grand_total = total_2025 + total_2026

    println("TOTAL PORTFOLIO\t$(round(total_2025, digits=1))\t$(round(total_2026, digits=1))\t$(round(grand_total, digits=1))")
    println("```")

    # ========== UPDATED TABLE OF CONTENTS ==========
    println("\n\n📑 TABLE OF CONTENTS")
    println("="^30)
    println("💎 Revenue Summary by Product by Year")
    println("📊 Resource Summary")
    println("🎯 Milestone Schedule")
    println("📅 Hiring & Resource Schedule")
    println("📈 NLU Activity Indicators")
    println("   ├── Nebula-NLU Customer Metrics (Enhanced Model)")
    println("   ├── Disclosure-NLU Legal Firm Metrics")
    println("   └── Lingua-NLU Professional Network Metrics")
    println("💰 NLU Revenue by Product")
    println("💼 Valuation Analysis")
    println("   ├── Mar 2026 Valuation")
    println("   └── Dec 2026 Valuation")
    println("🏦 Financial Statements")
    println("   ├── Profit & Loss Statement")
    println("   ├── Sources & Uses of Funds")
    println("   ├── Balance Sheet")
    println("   └── Deferred Salary Tracking")
    println("🎲 Probability Analysis & Business Model Parameters")
    println("   ├── Nebula-NLU Enhanced Stochastic Model")
    println("   ├── Disclosure-NLU Stochastic Model")
    println("   └── Lingua-NLU Stochastic Model")
    println("📁 Output Files Generated")
    println("   ├── monthly_pnl_with_deferred_salaries.csv")
    println("   ├── sources_uses_2025.csv & sources_uses_2026.csv")
    println("   ├── balance_sheet_with_valuation.csv")
    println("   ├── deferred_salary_tracking.csv")
    println("   └── strategic_plan_comprehensive.csv")
    println("\n" * "="^60)

    _tsv_resource_summary(initial_tasks, hours)
    _tsv_strategic_milestones(milestones, plan)
    _tsv_hiring_schedule(plan)
    _tsv_activity_indicators(plan, nebula_f, disclosure_f, lingua_f)
    _tsv_revenue_by_product(plan, nebula_f, disclosure_f, lingua_f)
    _tsv_valuation_analysis(plan, nebula_f, disclosure_f, lingua_f)
    _tsv_probability_documentation(prob_params)
    println("\n\n✅ Strategic plan data saved to: output/strategic_plan_comprehensive.csv")
    println("\n✅ Data generation complete.")
    println("ℹ️ To visualize distributions, call `generate_distribution_plots(results.prob_params)` after capturing the output of `run_analysis()`.")
end

end # module PresentationOutput