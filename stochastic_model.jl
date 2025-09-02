module StochasticModel

using Distributions, Random
using ..LoadFactors

export Milestone, MonthlyForecast, DisclosureForecast, LinguaForecast
export calculate_resource_hours, calculate_milestones, prepare_tasks_for_milestones
export model_nebula_revenue, model_disclosure_revenue, model_lingua_revenue
export run_stochastic_analysis, StochasticResults

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
    revenue_k::Float64 # Revenue in thousands
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
    # Extract pricing parameters
    monthly_price = model_params["MonthlyPrice"]  # $20
    annual_price = model_params["AnnualPrice"]    # $60
    annual_conversion_rate = model_params["AnnualConversionRate"]  # 35%

    # Extract growth parameters
    starting_customers = Int(model_params["StartingCustomersAtMVP"])  # 2000
    exponential_target = Int(model_params["ExponentialGrowthTarget"])  # 8000
    annual_growth = model_params["AnnualGrowthRatePostTarget"] / 100.0  # 2.0 = 200%
    monthly_compound = (1 + annual_growth)^(1 / 12)  # 1.096 = 9.6% monthly

    immediate_rate = model_params["ImmediatePurchaseRate"]  # 0.70
    delayed_rate = model_params["DelayedPurchaseRate"]     # 0.30
    churn_multiplier = model_params["ChurnMultiplier"]     # 1.5

    # Distribution configurations
    purchase_rate_dist = Beta(params["alpha_purchase"], params["beta_purchase"])
    adjusted_churn_dist = Beta(params["alpha_churn"] * churn_multiplier, params["beta_churn"])

    # Find MVP start month (November 2025)
    mvp_start_month = findfirst(==("Nov 2025"), plan.months)

    forecasts = MonthlyForecast[]
    total_monthly_customers = 0.0
    total_annual_customers = 0.0
    pending_delayed_customers = 0.0

    # Track monthly acquisition rate, not cumulative target
    monthly_acquisition_rate = Float64(starting_customers)
    exponential_phase = true
    months_in_exponential = 0

    for (i, month_name) in enumerate(plan.months)
        new_customers = 0

        # Customer acquisition with proper growth limits
        if i >= mvp_start_month
            if exponential_phase && months_in_exponential < 3
                # Nov: 2000, Dec: 4000, Jan: 8000 (then stop exponential)
                new_customers = rand(Poisson(monthly_acquisition_rate))
                monthly_acquisition_rate *= 2.0  # Double the monthly rate
                months_in_exponential += 1

                if months_in_exponential >= 3
                    exponential_phase = false
                    monthly_acquisition_rate = Float64(exponential_target) # Reset to 8000/month base
                end
            else
                # Linear phase - grow monthly acquisition rate by compound rate
                monthly_acquisition_rate *= monthly_compound  # 9.6% monthly growth
                new_customers = rand(Poisson(min(monthly_acquisition_rate, 50000)))
            end
        end

        # Purchase and pricing decisions
        purchase_conversion_rate = rand(purchase_rate_dist)
        annual_churn_rate = rand(adjusted_churn_dist)
        monthly_churn_rate = 1 - (1 - annual_churn_rate)^(1 / 12)

        # Split new purchasers between monthly and annual
        immediate_purchases = new_customers * purchase_conversion_rate * immediate_rate
        delayed_purchases = pending_delayed_customers
        total_new_purchases = immediate_purchases + delayed_purchases

        # Pricing split: 35% choose annual, 65% choose monthly
        new_annual_customers = total_new_purchases * annual_conversion_rate
        new_monthly_customers = total_new_purchases * (1 - annual_conversion_rate)

        # Apply churn to existing customers
        retained_monthly = total_monthly_customers * (1 - monthly_churn_rate)
        retained_annual = total_annual_customers * (1 - annual_churn_rate / 12)  # Annual customers churn less frequently

        # Update customer base
        total_monthly_customers = retained_monthly + new_monthly_customers
        total_annual_customers = retained_annual + new_annual_customers

        # Calculate revenue: Monthly customers pay monthly, annual customers pay 1/12 per month
        monthly_revenue = (total_monthly_customers * monthly_price) +
                          (total_annual_customers * annual_price / 12)

        # Set up next month's delayed purchases
        pending_delayed_customers = new_customers * purchase_conversion_rate * delayed_rate

        # Debug output for key months
        if month_name in ["Nov 2025", "Dec 2025", "Jan 2026", "Jun 2026", "Dec 2026", "Sep 2027"]
            println("DEBUG $month_name: New=$new_customers, Monthly=$(round(total_monthly_customers)), Annual=$(round(total_annual_customers)), Revenue=$(round(monthly_revenue))")
        end

        total_customers = round(Int, total_monthly_customers + total_annual_customers)

        push!(forecasts, MonthlyForecast(
            month_name,
            new_customers,
            purchase_conversion_rate,
            annual_churn_rate,
            total_customers,
            monthly_revenue / 1000  # Convert to thousands
        ))
    end

    return forecasts
end

function model_disclosure_revenue(plan::ResourcePlan, milestones::Vector{Milestone}, params::Dict{String,Float64}, model_params::Dict{String,Any})
    # Extract annual revenue per firm size from model_params
    solo_annual = model_params["SoloAnnualRevenue"]     # $15,000
    small_annual = model_params["SmallAnnualRevenue"]   # $50,000  
    medium_annual = model_params["MediumAnnualRevenue"] # $150,000
    large_annual = model_params["LargeAnnualRevenue"]   # $300,000
    biglaw_annual = model_params["BigLawAnnualRevenue"] # $750,000

    # Firm acquisition rates (reasonable for legal market)
    lambda_solo = 2.0      # 2 solo firms/month
    lambda_small = 1.5     # 1.5 small firms/month  
    lambda_medium = 0.3    # 0.3 medium firms/month
    lambda_large = 0.1     # 0.1 large firms/month
    lambda_biglaw = 0.05   # 0.05 BigLaw firms/month

    # Start in October 2025
    sales_start_idx = findfirst(==("Oct 2025"), plan.months)
    if sales_start_idx === nothing
        sales_start_idx = length(plan.months) + 1
    end

    forecasts = DisclosureForecast[]
    total_solo, total_small, total_medium, total_large, total_biglaw = 0.0, 0.0, 0.0, 0.0, 0.0
    churn_dist = Beta(1, 15)  # Low churn for legal professionals

    for (i, month_name) in enumerate(plan.months)
        new_solo, new_small, new_medium, new_large, new_biglaw = 0, 0, 0, 0, 0

        if i >= sales_start_idx
            new_solo = rand(Poisson(lambda_solo))
            new_small = rand(Poisson(lambda_small))
            new_medium = rand(Poisson(lambda_medium))
            new_large = rand(Poisson(lambda_large))
            new_biglaw = rand(Poisson(lambda_biglaw))
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

    return forecasts
end

function model_lingua_revenue(plan::ResourcePlan, milestones::Vector{Milestone}, params::Dict{String,Float64})
    price_per_match = 59.0  # $59 per match (reasonable pricing)

    # Reasonable user acquisition
    lambda_prem_jul = 125.0   # 125 users in Jul 2026
    lambda_prem_dec = 420.0   # 420 users in Dec 2026

    match_dist = Beta(params["alpha_match_success"], params["beta_match_success"])
    churn_dist = Beta(1, 15)

    # Find MVP completion month
    mvp_milestone_idx = findfirst(m -> m.task == "LinguaNU_MVP", milestones)
    mvp_completion_date = mvp_milestone_idx !== nothing ? milestones[mvp_milestone_idx].milestone_date : "Jul 2026"

    sales_start_idx = findfirst(==(mvp_completion_date), plan.months)
    if sales_start_idx === nothing
        sales_start_idx = findfirst(==("Jul 2026"), plan.months)  # Fallback
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
    # Create the resource plan
    plan = LoadFactors.create_resource_plan()
    hours = calculate_resource_hours(plan)
    initial_tasks = LoadFactors.load_project_tasks()
    milestones = calculate_milestones(initial_tasks, hours, plan.months)

    # Define probability parameters
    prob_params = Dict{String,Dict{String,Float64}}(
        "Nebula-NLU" => Dict(
            "lambda_jan_2026" => 8000.0,
            "alpha_purchase" => 2.0,
            "beta_purchase" => 3.0,
            "alpha_churn" => 1.0,
            "beta_churn" => 9.0
        ),
        "Disclosure-NLU" => Dict(
            "solo_revenue_multiplier" => 1.25,
            "small_revenue_multiplier" => 3.33,
            "medium_revenue_multiplier" => 10.0,
            "base_monthly_cost" => 1500.0
        ),
        "Lingua-NLU" => Dict(
            "alpha_match_success" => 2.0,
            "beta_match_success" => 1.0,
            "mean_match_success" => 0.67
        )
    )

    # Define model parameters
    model_params = Dict{String,Any}(
        "MonthlyPrice" => 20.0,
        "AnnualPrice" => 60.0,
        "AnnualConversionRate" => 0.35,
        "StartingCustomersAtMVP" => 2000,
        "ExponentialGrowthTarget" => 8000,
        "AnnualGrowthRatePostTarget" => 200.0,
        "ImmediatePurchaseRate" => 0.70,
        "DelayedPurchaseRate" => 0.30,
        "ChurnMultiplier" => 1.5,
        "PurchaseCutoffMonths" => 2,
        "SoloAnnualRevenue" => 15000.0,
        "SmallAnnualRevenue" => 50000.0,
        "MediumAnnualRevenue" => 150000.0,
        "LargeAnnualRevenue" => 300000.0,
        "BigLawAnnualRevenue" => 750000.0
    )

    # Generate forecasts
    nebula_forecast = model_nebula_revenue(plan, prob_params["Nebula-NLU"], model_params)
    disclosure_forecast = model_disclosure_revenue(plan, milestones, prob_params["Disclosure-NLU"], model_params)
    lingua_forecast = model_lingua_revenue(plan, milestones, prob_params["Lingua-NLU"])

    # Return structured results
    return StochasticResults(
        nebula_forecast,
        disclosure_forecast,
        lingua_forecast,
        prob_params
    )
end

end # module StochasticModel