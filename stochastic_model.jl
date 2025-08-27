module StochasticModel

using Distributions, Random
using ..LoadFactors

export Milestone, MonthlyForecast, DisclosureForecast, LinguaForecast
export calculate_resource_hours, calculate_milestones, prepare_tasks_for_milestones
export model_nebula_revenue, model_disclosure_revenue, model_lingua_revenue

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

"""
IMPROVED NEBULA REVENUE MODEL

Key Features:
1. **Two-Phase Purchase Model**: 70% of interested customers buy immediately, 
   30% buy in the following month (then cutoff)
2. **Enhanced Churn**: Captures both normal churn AND customers who "disappear" 
   without ever purchasing by increasing early probability mass
3. **Simple State Tracking**: Only 3 variables - current customers, pending customers, new acquisitions
4. **Realistic Revenue Timing**: Revenue comes from immediate purchases + delayed purchases from previous month

Model Behavior:
- Month N: Acquire customers via Poisson(λ), some buy now, some buy next month
- Month N+1: Previous month's pending customers purchase + new immediate purchases
- Continuous churn applied to existing customer base
- Clean 2-month purchase cutoff (no infinite tails)
"""
function model_nebula_revenue(plan::ResourcePlan, params::Dict{String,Float64})
    purchase_price = 20.0
    lambda_oct_2025 = params["lambda_oct_2025"]
    lambda_jan_2026 = params["lambda_jan_2026"]
    lambda_jul_2026 = params["lambda_jul_2026"]

    # Adjusted churn to account for "disappearing" customers
    # Higher early churn captures customers who never convert + those who disappear
    adjusted_churn_dist = Beta(params["alpha_churn"] * 1.5, params["beta_churn"])

    # Purchase timing: what % buy this month vs next month
    immediate_purchase_rate = 0.7  # 70% buy in acquisition month
    delayed_purchase_rate = 0.3   # 30% buy in following month

    forecasts = MonthlyForecast[]
    total_customers = 0.0
    pending_next_month_customers = 0.0  # Customers who will buy next month
    lambda = 0.0

    for (i, month_name) in enumerate(plan.months)
        # Update acquisition rate based on milestones
        if month_name == "Oct 2025"
            lambda = lambda_oct_2025
        elseif month_name == "Jan 2026"
            lambda = lambda_jan_2026
        elseif month_name == "Jul 2026"
            lambda = lambda_jul_2026
        end

        # NEW CUSTOMERS ACQUIRED THIS MONTH
        new_customers = lambda > 0 ? rand(Poisson(lambda)) : 0

        # REVENUE CALCULATION
        purchase_conversion_rate = rand(Beta(params["alpha_purchase"], params["beta_purchase"]))

        # Revenue from immediate purchases (this month's new customers)
        immediate_revenue = new_customers * purchase_conversion_rate * immediate_purchase_rate * purchase_price

        # Revenue from delayed purchases (last month's pending customers)
        delayed_revenue = pending_next_month_customers * purchase_price

        total_monthly_revenue = immediate_revenue + delayed_revenue

        # UPDATE CUSTOMER BASE
        # Apply churn (includes "disappearing" customers)
        annual_churn_rate = rand(adjusted_churn_dist)
        monthly_churn_rate = 1 - (1 - annual_churn_rate)^(1 / 12)

        # Retain existing customers
        customers_retained = total_customers * (1 - monthly_churn_rate)

        # Add new paying customers (immediate + any pending from last month)
        new_paying_customers = new_customers * purchase_conversion_rate * immediate_purchase_rate +
                               pending_next_month_customers

        total_customers = customers_retained + new_paying_customers

        # SET UP NEXT MONTH'S PENDING CUSTOMERS
        # Some of this month's acquired customers will buy next month
        pending_next_month_customers = new_customers * purchase_conversion_rate * delayed_purchase_rate

        push!(forecasts, MonthlyForecast(
            month_name,
            new_customers,
            purchase_conversion_rate,
            annual_churn_rate,
            round(Int, total_customers),
            total_monthly_revenue / 1000
        ))
    end

    return forecasts
end

function model_disclosure_revenue(plan::ResourcePlan, milestones::Vector{Milestone}, params::Dict{String,Float64})
    base_price = params["base_monthly_cost"]
    lambda_solo = params["lambda_solo_firms"]
    lambda_small = params["lambda_small_firms"]
    lambda_medium = params["lambda_medium_firms"]
    lambda_large = get(params, "lambda_large_firms", 0.1)
    lambda_biglaw = get(params, "lambda_biglaw", 0.0)
    rev_mult_solo = params["solo_revenue_multiplier"]
    rev_mult_small = params["small_revenue_multiplier"]
    rev_mult_medium = params["medium_revenue_multiplier"]
    rev_mult_large = get(params, "large_revenue_multiplier", 50.5)
    rev_mult_biglaw = get(params, "biglaw_revenue_multiplier", 202.0)
    mvp_milestone_idx = findfirst(m -> m.task == "Disclosure - Mobile UI", milestones)
    mvp_completion_date = mvp_milestone_idx !== nothing ? milestones[mvp_milestone_idx].milestone_date : "Beyond Plan"
    sales_start_idx = findfirst(==(mvp_completion_date), plan.months)
    sales_start_idx = sales_start_idx !== nothing ? sales_start_idx + 2 : length(plan.months) + 1
    forecasts = DisclosureForecast[]
    total_solo_clients, total_small_clients, total_medium_clients, total_large_clients, total_biglaw_clients = 0.0, 0.0, 0.0, 0.0, 0.0
    churn_dist = Beta(1, 15)
    for (i, month_name) in enumerate(plan.months)
        new_solo, new_small, new_medium, new_large, new_biglaw = 0, 0, 0, 0, 0
        if i >= sales_start_idx
            new_solo = rand(Poisson(lambda_solo))
            new_small = rand(Poisson(lambda_small))
            new_medium = rand(Poisson(lambda_medium))
            new_large = rand(Poisson(lambda_large))
            new_biglaw = rand(Poisson(lambda_biglaw))
        end
        new_customers = new_solo + new_small + new_medium + new_large + new_biglaw
        monthly_churn_rate = 1 - (1 - rand(churn_dist))^(1 / 12)
        total_solo_clients = total_solo_clients * (1 - monthly_churn_rate) + new_solo
        total_small_clients = total_small_clients * (1 - monthly_churn_rate) + new_small
        total_medium_clients = total_medium_clients * (1 - monthly_churn_rate) + new_medium
        total_large_clients = total_large_clients * (1 - monthly_churn_rate) + new_large
        total_biglaw_clients = total_biglaw_clients * (1 - monthly_churn_rate) + new_biglaw
        total_customers = round(Int, total_solo_clients + total_small_clients + total_medium_clients + total_large_clients + total_biglaw_clients)
        monthly_revenue = (total_solo_clients * rev_mult_solo + total_small_clients * rev_mult_small + total_medium_clients * rev_mult_medium + total_large_clients * rev_mult_large + total_biglaw_clients * rev_mult_biglaw) * base_price
        push!(forecasts, DisclosureForecast(month_name, new_customers, total_customers, round(Int, total_solo_clients), round(Int, total_small_clients), round(Int, total_medium_clients), round(Int, total_large_clients), round(Int, total_biglaw_clients), monthly_revenue / 1000))
    end
    return forecasts
end

function model_lingua_revenue(plan::ResourcePlan, milestones::Vector{Milestone}, params::Dict{String,Float64})
    price_per_match = 59.0
    lambda_prem_jul = params["lambda_premium_users_jul"]
    lambda_prem_dec = params["lambda_premium_users_dec"]
    match_dist = Beta(params["alpha_match_success"], params["beta_match_success"])
    churn_dist = Beta(1, 15)
    mvp_milestone_idx = findfirst(m -> m.task == "Lingua-NLU MVP", milestones)
    mvp_completion_date = mvp_milestone_idx !== nothing ? milestones[mvp_milestone_idx].milestone_date : "Beyond Plan"
    sales_start_idx = findfirst(==(mvp_completion_date), plan.months)
    sales_start_idx = sales_start_idx !== nothing ? sales_start_idx + 1 : length(plan.months) + 1
    forecasts = LinguaForecast[]
    total_premium_users = 0.0
    lambda_prem = 0.0
    for (i, month_name) in enumerate(plan.months)
        if month_name == "Jul 2026"
            lambda_prem = lambda_prem_jul
        end
        if month_name == "Dec 2026"
            lambda_prem = lambda_prem_dec
        end
        new_premium_users = (i >= sales_start_idx && lambda_prem > 0) ? rand(Poisson(lambda_prem)) : 0
        monthly_churn_rate = 1 - (1 - rand(churn_dist))^(1 / 12)
        users_retained = total_premium_users * (1 - monthly_churn_rate)
        total_premium_users = users_retained + new_premium_users
        match_success_rate = rand(match_dist)
        monthly_revenue = total_premium_users * match_success_rate * price_per_match
        push!(forecasts, LinguaForecast(month_name, round(Int, total_premium_users * match_success_rate), monthly_revenue / 1000))
    end
    return forecasts
end

end # module StochasticModel