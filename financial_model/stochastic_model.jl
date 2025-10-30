module StochasticModel

using Distributions, Random
using ..LoadFactors

export Milestone, MonthlyForecast, DisclosureForecast, LinguaForecast
export calculate_resource_hours, calculate_milestones, prepare_tasks_for_milestones
export model_nebula_revenue, model_disclosure_revenue, model_lingua_revenue
export run_stochastic_analysis, StochasticResults
export format_number, format_currency

# ========== NUMBER FORMATTING ==========
function format_number(value::Real; use_k_m::Bool=true)
    abs_val = abs(value)

    if !use_k_m
        return string(round(Int, value))
    end

    if abs_val >= 1_000_000
        formatted = round(value / 1_000_000, digits=1)
        return string(formatted) * "M"
    elseif abs_val >= 1_000
        formatted = round(value / 1_000, digits=1)
        return string(formatted) * "K"
    else
        return string(round(Int, value))
    end
end

function format_currency(value::Real; use_k_m::Bool=true)
    return "\$" * format_number(value, use_k_m=use_k_m)
end

# ========== DATA STRUCTURES ==========
struct Milestone
    task::String
    sequence::Int
    planned_hours::Int
    cumulative_hours::Int
    milestone_date::String
    available_hours::Float64
    buffer_hours::Float64
    resource_type::String
end

struct MonthlyForecast
    month::String
    new_customers::Int
    avg_purchases_per_customer::Float64
    annual_churn_rate::Float64
    total_customers::Int
    revenue_k::Float64
end

struct DisclosureForecast
    month::String
    new_clients::Int
    total_clients::Int
    total_solo::Int
    total_small::Int
    total_medium::Int
    total_large::Int
    total_biglaw::Int
    revenue_k::Float64
end

struct LinguaForecast
    month::String
    active_pairs::Int
    revenue_k::Float64
end

struct StochasticResults
    nebula_forecast::Vector{MonthlyForecast}
    disclosure_forecast::Vector{DisclosureForecast}
    lingua_forecast::Vector{LinguaForecast}
    prob_params::Dict{String,Dict{String,Float64}}
end

# ========== CALCULATION FUNCTIONS ==========
function calculate_resource_hours(plan::ResourcePlan)
    monthly_dev_hours = (plan.experienced_devs .* plan.dev_productivity_factor .+
                         plan.intern_devs .* plan.intern_productivity_factor) .* 8 .* plan.work_days .* plan.dev_efficiency

    monthly_marketing_hours = (plan.experienced_marketers .* plan.marketing_productivity_factor .+
                               plan.intern_marketers .* plan.intern_productivity_factor) .* 8 .* plan.work_days .* plan.marketing_efficiency

    return (monthly_dev=monthly_dev_hours,
        monthly_marketing=monthly_marketing_hours,
        cumulative_dev=cumsum(monthly_dev_hours),
        cumulative_marketing=cumsum(monthly_marketing_hours))
end

function calculate_milestones(tasks::Vector{ProjectTask}, hours, months::Vector{String})
    dev_tasks = sort(filter(t -> t.task_type == "Development", tasks), by=t -> t.sequence)
    marketing_tasks = sort(filter(t -> t.task_type == "Marketing", tasks), by=t -> t.sequence)
    milestones = Milestone[]

    function _calculate_milestones_for_type(task_list, cumulative_hours, resource_type, months)
        task_cumulative = 0
        for task in task_list
            task_cumulative += task.planned_hours
            milestone_month_idx = findfirst(h -> h >= task_cumulative, cumulative_hours)
            if milestone_month_idx !== nothing
                push!(milestones, Milestone(task.name, task.sequence, task.planned_hours, task_cumulative, months[milestone_month_idx], cumulative_hours[milestone_month_idx], cumulative_hours[milestone_month_idx] - task_cumulative, resource_type))
            else
                push!(milestones, Milestone(task.name, task.sequence, task.planned_hours, task_cumulative, "Beyond Plan", 0.0, 0.0, resource_type))
            end
        end
    end

    _calculate_milestones_for_type(dev_tasks, hours.cumulative_dev, "Development", months)
    _calculate_milestones_for_type(marketing_tasks, hours.cumulative_marketing, "Marketing", months)
    return milestones
end

function prepare_tasks_for_milestones(initial_tasks::Vector{ProjectTask}, hours)
    tasks = deepcopy(initial_tasks)
    dev_planned_total = sum(t.planned_hours for t in tasks if t.task_type == "Development")
    mktg_planned_total = sum(t.planned_hours for t in tasks if t.task_type == "Marketing")
    remaining_dev_hours = hours.cumulative_dev[end] - dev_planned_total
    remaining_mktg_hours = hours.cumulative_marketing[end] - mktg_planned_total
    next_dev_seq = isempty(filter(t -> t.task_type == "Development", tasks)) ? 1 : maximum(t.sequence for t in tasks if t.task_type == "Development") + 1
    next_mktg_seq = isempty(filter(t -> t.task_type == "Marketing", tasks)) ? 1 : maximum(t.sequence for t in tasks if t.task_type == "Marketing") + 1
    push!(tasks, ProjectTask("Future Project Development", max(0, round(Int, remaining_dev_hours)), next_dev_seq, "Development"))
    push!(tasks, ProjectTask("Executing Mktg", max(0, round(Int, remaining_mktg_hours)), next_mktg_seq, "Marketing"))
    return tasks
end

# ========== FINANCIAL MODELING ==========

function model_nebula_revenue(plan::ResourcePlan, params::Dict{String,Float64}, model_params::Dict{String,Any})
    # Extract pricing parameters from CSV
    monthly_price = model_params["MonthlyPrice"]
    annual_price = model_params["AnnualPrice"]
    annual_conversion_rate = model_params["AnnualConversionRate"]

    # Extract growth parameters from probability_parameters.csv
    lambda_dec = params["lambda_dec_2025"]      # 200
    lambda_jan = params["lambda_jan_2026"]      # 400
    lambda_feb = params["lambda_feb_2026"]      # 800
    lambda_mar = params["lambda_mar_2026"]      # 1600
    lambda_apr = params["lambda_apr_2026"]      # 3200
    lambda_may_onwards = params["lambda_may_2026_onwards"]  # 533

    # Distribution configurations
    purchase_rate_dist = Beta(params["alpha_purchase"], params["beta_purchase"])
    churn_dist = Beta(params["alpha_churn"], params["beta_churn"])

    # Find MVP start month (Dec 2025 based on CSV)
    mvp_start_month = findfirst(==("Dec 2025"), plan.months)
    doubling_end = findfirst(==("Apr 2026"), plan.months)
    linear_start = findfirst(==("May 2026"), plan.months)

    forecasts = MonthlyForecast[]
    total_monthly_customers = 0.0
    total_annual_customers = 0.0
    pending_delayed_customers = 0.0

    for (i, month_name) in enumerate(plan.months)
        new_customers = 0
        lambda_current = 0.0

        # Customer acquisition based on CSV parameters
        if i >= mvp_start_month && !isnothing(mvp_start_month)
            if month_name == "Dec 2025"
                lambda_current = lambda_dec
            elseif month_name == "Jan 2026"
                lambda_current = lambda_jan
            elseif month_name == "Feb 2026"
                lambda_current = lambda_feb
            elseif month_name == "Mar 2026"
                lambda_current = lambda_mar
            elseif month_name == "Apr 2026"
                lambda_current = lambda_apr
            elseif !isnothing(linear_start) && i >= linear_start
                lambda_current = lambda_may_onwards
            end

            if lambda_current > 0
                new_customers = rand(Poisson(lambda_current))
            end
        end

        # Purchase and pricing decisions
        purchase_conversion_rate = rand(purchase_rate_dist)
        annual_churn_rate = rand(churn_dist)
        monthly_churn_rate = 1 - (1 - annual_churn_rate)^(1 / 12)

        # Process delayed purchases from previous month
        immediate_purchases = new_customers * purchase_conversion_rate * model_params["ImmediatePurchaseRate"]
        delayed_purchases = pending_delayed_customers
        total_new_purchases = immediate_purchases + delayed_purchases

        # Pricing split based on CSV annual conversion rate
        new_annual_customers = total_new_purchases * annual_conversion_rate
        new_monthly_customers = total_new_purchases * (1 - annual_conversion_rate)

        # Apply churn
        retained_monthly = total_monthly_customers * (1 - monthly_churn_rate)
        retained_annual = total_annual_customers * (1 - annual_churn_rate / 12)

        # Update customer base
        total_monthly_customers = retained_monthly + new_monthly_customers
        total_annual_customers = retained_annual + new_annual_customers

        # Calculate revenue
        monthly_revenue = (total_monthly_customers * monthly_price) +
                          (total_annual_customers * annual_price / 12)

        # Set up next month's delayed purchases
        pending_delayed_customers = new_customers * purchase_conversion_rate * model_params["DelayedPurchaseRate"]

        total_customers = round(Int, total_monthly_customers + total_annual_customers)

        push!(forecasts, MonthlyForecast(
            month_name,
            new_customers,
            purchase_conversion_rate,
            annual_churn_rate,
            total_customers,
            monthly_revenue / 1000
        ))
    end

    return forecasts
end

function model_disclosure_revenue(plan::ResourcePlan, milestones::Vector{Milestone}, params::Dict{String,Float64}, model_params::Dict{String,Any})
    # Extract annual revenue per firm size from CSV
    solo_annual = model_params["SoloAnnualRevenue"]
    small_annual = model_params["SmallAnnualRevenue"]
    medium_annual = model_params["MediumAnnualRevenue"]
    large_annual = model_params["LargeAnnualRevenue"]
    biglaw_annual = model_params["BigLawAnnualRevenue"]

    # Firm acquisition rates from probability_parameters.csv
    lambda_solo = params["lambda_solo_firms"]
    lambda_small = params["lambda_small_firms"]
    lambda_medium = params["lambda_medium_firms"]
    lambda_large = get(params, "lambda_large_firms", 0.1)
    lambda_biglaw = get(params, "lambda_biglaw_firms", 0.05)

    # CRITICAL FIX: Find MVP completion date from milestones
    disclosure_mvp_milestone = findfirst(m -> m.task == "DisclosureNLU_MVP", milestones)

    if disclosure_mvp_milestone !== nothing
        mvp_completion_month = milestones[disclosure_mvp_milestone].milestone_date
        println("DEBUG: Disclosure MVP completes: $(mvp_completion_month)")
    else
        mvp_completion_month = "Jan 2026"  # Fallback
        println("DEBUG: Disclosure MVP milestone not found, using fallback: Jan 2026")
    end

    # Find the index of MVP completion month
    sales_start_idx = findfirst(==(mvp_completion_month), plan.months)

    if sales_start_idx === nothing
        # If MVP month not in plan, start from beginning of plan
        sales_start_idx = 1
        println("DEBUG: MVP month $(mvp_completion_month) not found in plan, starting from month 1")
    else
        println("DEBUG: Sales start at index $(sales_start_idx): $(plan.months[sales_start_idx])")
    end

    # Start months for Large and BigLaw from CSV (Q3 2027)
    large_start_month_name = get(model_params, "LargeStartMonth", "Jul 2027")
    biglaw_start_month_name = get(model_params, "BigLawStartMonth", "Jul 2027")

    large_start_idx = findfirst(==(large_start_month_name), plan.months)
    biglaw_start_idx = findfirst(==(biglaw_start_month_name), plan.months)

    if large_start_idx === nothing
        large_start_idx = length(plan.months) + 1  # Never start
    end
    if biglaw_start_idx === nothing
        biglaw_start_idx = length(plan.months) + 1  # Never start
    end

    forecasts = DisclosureForecast[]
    total_solo, total_small, total_medium, total_large, total_biglaw = 0.0, 0.0, 0.0, 0.0, 0.0
    churn_dist = Beta(1, 15)  # Low churn for legal professionals

    for (i, month_name) in enumerate(plan.months)
        new_solo, new_small, new_medium, new_large, new_biglaw = 0, 0, 0, 0, 0

        # CRITICAL: Only acquire firms after MVP completion
        if i >= sales_start_idx
            new_solo = rand(Poisson(lambda_solo))
            new_small = rand(Poisson(lambda_small))
            new_medium = rand(Poisson(lambda_medium))

            # Large and BigLaw start in Q3 2027
            if i >= large_start_idx
                new_large = rand(Poisson(lambda_large))
            end
            if i >= biglaw_start_idx
                new_biglaw = rand(Poisson(lambda_biglaw))
            end

            # Debug output for first few months
            if i == sales_start_idx || i == sales_start_idx + 1
                println("DEBUG $(month_name): New firms - Solo:$(new_solo), Small:$(new_small), Medium:$(new_medium)")
            end
        end

        # Apply churn
        monthly_churn_rate = 1 - (1 - rand(churn_dist))^(1 / 12)
        total_solo = total_solo * (1 - monthly_churn_rate) + new_solo
        total_small = total_small * (1 - monthly_churn_rate) + new_small
        total_medium = total_medium * (1 - monthly_churn_rate) + new_medium
        total_large = total_large * (1 - monthly_churn_rate) + new_large
        total_biglaw = total_biglaw * (1 - monthly_churn_rate) + new_biglaw

        total_customers = round(Int, total_solo + total_small + total_medium + total_large + total_biglaw)

        # Calculate monthly revenue (annual revenue / 12 per firm)
        monthly_revenue = (total_solo * solo_annual / 12 +
                           total_small * small_annual / 12 +
                           total_medium * medium_annual / 12 +
                           total_large * large_annual / 12 +
                           total_biglaw * biglaw_annual / 12)

        # Debug output for first few revenue months
        if monthly_revenue > 0 && (i == sales_start_idx || i == sales_start_idx + 1)
            println("DEBUG $(month_name): Revenue=$(round(monthly_revenue)), Solo=$(round(Int,total_solo)), Small=$(round(Int,total_small)), Medium=$(round(Int,total_medium))")
        end

        push!(forecasts, DisclosureForecast(
            month_name,
            new_solo + new_small + new_medium + new_large + new_biglaw,
            total_customers,
            round(Int, total_solo),
            round(Int, total_small),
            round(Int, total_medium),
            round(Int, total_large),
            round(Int, total_biglaw),
            monthly_revenue / 1000
        ))
    end

    println("DEBUG: Disclosure forecasts generated: $(length(forecasts)) months")
    println("DEBUG: First revenue month: $(findfirst(f -> f.revenue_k > 0, forecasts))")

    return forecasts
end

function model_lingua_revenue(plan::ResourcePlan, milestones::Vector{Milestone}, params::Dict{String,Float64}, model_params::Dict{String,Any})
    # Price per match from CSV
    price_per_match = get(model_params, "LinguaMatchPrice", 59.0)

    # User acquisition from probability_parameters.csv
    lambda_prem_jul = params["lambda_premium_users_jul"]
    lambda_prem_dec = params["lambda_premium_users_dec"]

    match_dist = Beta(params["alpha_match_success"], params["beta_match_success"])
    churn_dist = Beta(1, 15)

    # Find MVP completion month
    mvp_milestone_idx = findfirst(m -> m.task == "LinguaNU_MVP", milestones)
    mvp_completion_date = mvp_milestone_idx !== nothing ? milestones[mvp_milestone_idx].milestone_date : "Jul 2026"

    sales_start_idx = findfirst(==(mvp_completion_date), plan.months)
    if sales_start_idx === nothing
        sales_start_idx = findfirst(==("Jul 2026"), plan.months)
    end

    forecasts = LinguaForecast[]
    total_premium_users = 0.0

    for (i, month_name) in enumerate(plan.months)
        lambda_prem = 0.0
        if month_name == "Jul 2026"
            lambda_prem = lambda_prem_jul
        elseif month_name == "Dec 2026"
            lambda_prem = lambda_prem_dec
        end

        new_premium_users = 0
        if i >= sales_start_idx && lambda_prem > 0
            new_premium_users = rand(Poisson(lambda_prem))
        end

        monthly_churn_rate = 1 - (1 - rand(churn_dist))^(1 / 12)
        users_retained = total_premium_users * (1 - monthly_churn_rate)
        total_premium_users = users_retained + new_premium_users

        match_success_rate = rand(match_dist)
        successful_matches = total_premium_users * match_success_rate
        monthly_revenue = successful_matches * price_per_match

        push!(forecasts, LinguaForecast(
            month_name,
            round(Int, successful_matches),
            monthly_revenue / 1000
        ))
    end

    return forecasts
end

function run_stochastic_analysis()
    # Load all configuration from CSV files
    plan = LoadFactors.create_resource_plan()
    hours = calculate_resource_hours(plan)
    initial_tasks = LoadFactors.load_project_tasks()
    milestones = calculate_milestones(initial_tasks, hours, plan.months)

    prob_params = LoadFactors.load_probability_parameters("data/probability_parameters.csv")
    model_params = LoadFactors.load_model_parameters("data/model_parameters.csv")

    # Generate forecasts
    nebula_forecast = model_nebula_revenue(plan, prob_params["Nebula-NLU"], model_params)
    disclosure_forecast = model_disclosure_revenue(plan, milestones, prob_params["Disclosure-NLU"], model_params)
    lingua_forecast = model_lingua_revenue(plan, milestones, prob_params["Lingua-NLU"], model_params)

    return StochasticResults(
        nebula_forecast,
        disclosure_forecast,
        lingua_forecast,
        prob_params
    )
end

end # module StochasticModel