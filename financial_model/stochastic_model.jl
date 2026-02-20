module StochasticModel

using Dates, Distributions, Random
using ..LoadFactors

export MonthlyForecast, DisclosureForecast, LinguaForecast
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

# ========== FINANCIAL MODELING ==========

function model_nebula_revenue(months::Vector{String}, params::Dict{String,Float64}, model_params::Dict{String,Any}, start_month_name::String)
    # Extract freemium funnel parameters
    monthly_price = model_params["MonthlyPrice"]
    annual_price = model_params["AnnualPrice"]
    free_to_monthly = model_params["FreeToMonthlyConversion"]
    free_to_annual = model_params["FreeToAnnualConversion"]
    monthly_to_annual_rate = model_params["MonthlyToAnnualUpgrade"]
    monthly_churn = model_params["MonthlyChurnRate"]
    annual_renewal = model_params["AnnualRenewalRate"]
    grandparent_pct = model_params["GrandparentPercentage"]
    grandparent_annual_conv = model_params["GrandparentFreeToAnnualConversion"]
    grandparent_renewal = model_params["GrandparentAnnualRenewal"]
    grandparent_churn = model_params["GrandparentMonthlyChurn"]

    # Growth parameters from CSV
    starting_customers = model_params["StartingCustomersAtMVP"]
    doubling_end_month = model_params["DoublingPhaseEndMonth"]
    linear_start_month = model_params["LinearPhaseStartMonth"]
    linear_growth = model_params["LinearMonthlyGrowth"]

    # Find key month indices
    start_idx = findfirst(==(start_month_name), months)
    doubling_end_idx = findfirst(==(doubling_end_month), months)
    linear_start_idx = findfirst(==(linear_start_month), months)

    if start_idx === nothing
        @warn "Revenue start month '$start_month_name' not found in timeline"
        return MonthlyForecast[]
    end

    forecasts = MonthlyForecast[]

    # Cohort tracking
    monthly_subscribers = 0.0
    annual_subscribers = 0.0
    grandparent_monthly = 0.0
    grandparent_annual = 0.0

    # Track cohorts for upgrade timing (monthly→annual happens after ~3 months)
    monthly_cohorts = Dict{Int,Float64}()

    # Track current customer base for growth calculation
    current_base = 0.0

    for (i, month_name) in enumerate(months)
        # Step 1: Calculate new free trial signups based on growth phase
        new_trials = 0

        if i >= start_idx
            if i == start_idx
                # First month: starting customer base
                new_trials = round(Int, starting_customers)
                current_base = starting_customers

            elseif !isnothing(doubling_end_idx) && i > start_idx && i <= doubling_end_idx
                # Doubling phase: 2x previous month
                new_trials = round(Int, current_base * 2)
                current_base = new_trials

            elseif !isnothing(linear_start_idx) && i >= linear_start_idx
                # Linear growth phase: fixed number per month
                new_trials = round(Int, linear_growth)
                current_base = linear_growth

            else
                # Transition month or unspecified: use current base
                new_trials = round(Int, current_base)
            end

            # Add some stochastic variation (±10%)
            variation = rand() * 0.2 - 0.1  # -10% to +10%
            new_trials = max(0, round(Int, new_trials * (1 + variation)))
        end

        # Step 2: Free → Paid conversion
        new_conversions = new_trials * (free_to_monthly + free_to_annual)

        # Segment: Regular vs Grandparent
        grandparent_trials = new_conversions * grandparent_pct
        regular_trials = new_conversions * (1 - grandparent_pct)

        # Regular conversions
        total_conversion_rate = free_to_monthly + free_to_annual
        if total_conversion_rate > 0
            new_monthly_regular = regular_trials * (free_to_monthly / total_conversion_rate)
            new_annual_regular = regular_trials * (free_to_annual / total_conversion_rate)
        else
            new_monthly_regular = 0.0
            new_annual_regular = 0.0
        end

        # Grandparent conversions (higher annual preference)
        new_annual_grandparent = grandparent_trials * grandparent_annual_conv
        new_monthly_grandparent = grandparent_trials * (1 - grandparent_annual_conv)

        # Step 3: Apply churn to existing subscribers
        monthly_subscribers *= (1 - monthly_churn)
        annual_subscribers *= (1 - (1 - annual_renewal) / 12)  # Monthly equivalent of annual churn
        grandparent_monthly *= (1 - grandparent_churn)
        grandparent_annual *= (1 - (1 - grandparent_renewal) / 12)

        # Step 4: Monthly → Annual upgrades (after 3 months)
        upgrades_to_annual = 0.0
        cohort_to_check = i - 3
        if haskey(monthly_cohorts, cohort_to_check)
            cohort_size = monthly_cohorts[cohort_to_check]
            upgrades_to_annual = cohort_size * monthly_to_annual_rate
            monthly_subscribers -= upgrades_to_annual
            annual_subscribers += upgrades_to_annual
            delete!(monthly_cohorts, cohort_to_check)
        end

        # Step 5: Add new subscribers
        monthly_subscribers += new_monthly_regular
        annual_subscribers += new_annual_regular
        grandparent_monthly += new_monthly_grandparent
        grandparent_annual += new_annual_grandparent

        # Track this month's cohort for future upgrades
        if new_monthly_regular > 0
            monthly_cohorts[i] = new_monthly_regular
        end

        # Step 6: Calculate revenue
        total_monthly_subs = monthly_subscribers + grandparent_monthly
        total_annual_subs = annual_subscribers + grandparent_annual

        monthly_revenue = (total_monthly_subs * monthly_price) +
                          (total_annual_subs * annual_price / 12)

        total_customers = round(Int, total_monthly_subs + total_annual_subs)

        # Calculate conversion rate for this month
        avg_conversion_rate = if new_trials > 0
            new_conversions / new_trials
        else
            0.0
        end

        push!(forecasts, MonthlyForecast(
            month_name,
            new_trials,
            avg_conversion_rate,
            monthly_churn,
            total_customers,
            monthly_revenue / 1000
        ))
    end

    return forecasts
end

function model_disclosure_revenue(months::Vector{String}, params::Dict{String,Float64}, model_params::Dict{String,Any}, start_month_name::String)
    # Extract parameters from CSV
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

    # Find the start index for revenue generation
    sales_start_idx = findfirst(==(start_month_name), months)
    if sales_start_idx === nothing
        return DisclosureForecast[] # Or handle error appropriately
    end

    # Start months for Large and BigLaw from CSV (Q3 2027)
    large_start_month_name = get(model_params, "LargeStartMonth", "Jul 2027")
    biglaw_start_month_name = get(model_params, "BigLawStartMonth", "Jul 2027")

    large_start_idx = findfirst(==(large_start_month_name), months)
    biglaw_start_idx = findfirst(==(biglaw_start_month_name), months)

    if large_start_idx === nothing
        large_start_idx = length(months) + 1  # Never start
    end
    if biglaw_start_idx === nothing
        biglaw_start_idx = length(months) + 1  # Never start
    end

    forecasts = DisclosureForecast[]
    total_solo, total_small, total_medium, total_large, total_biglaw = 0.0, 0.0, 0.0, 0.0, 0.0
    churn_dist = Beta(1, 15)  # Low churn for legal professionals

    for (i, month_name) in enumerate(months)
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

    return forecasts
end

function model_lingua_revenue(months::Vector{String}, params::Dict{String,Float64}, model_params::Dict{String,Any}, start_month_name::String)
    # Extract parameters from CSV
    price_per_match = get(model_params, "LinguaMatchPrice", 59.0)

    # User acquisition from probability_parameters.csv
    lambda_prem_jul = params["lambda_premium_users_jul"]
    lambda_prem_dec = params["lambda_premium_users_dec"]

    match_dist = Beta(params["alpha_match_success"], params["beta_match_success"])
    churn_dist = Beta(1, 15)

    # Find the start index for revenue generation
    sales_start_idx = findfirst(==(start_month_name), months)
    if sales_start_idx === nothing
        return LinguaForecast[] # Or handle error
    end

    forecasts = LinguaForecast[]
    total_premium_users = 0.0

    for (i, month_name) in enumerate(months)
        lambda_prem = 0.0
        if month_name == "Jul 2026"
            lambda_prem = lambda_prem_jul
        elseif month_name == "Dec 2026"
            lambda_prem = lambda_prem_dec
        end

        new_premium_users = 0
        if !isnothing(sales_start_idx) && i >= sales_start_idx && lambda_prem > 0
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

function run_stochastic_analysis(months::Vector{String})
    # Load configuration from CSV files
    prob_params = LoadFactors.load_probability_parameters("data/probability_parameters.csv")
    model_params = LoadFactors.load_model_parameters("data/model_parameters.csv")

    # Centralized start dates. These can be overridden by values in model_parameters.csv
    default_start_dates = Dict(
        "NebulaStartMonth" => "Apr 2026",
        "DisclosureStartMonth" => "May 2026",
        "LinguaStartMonth" => "Sep 2026"
    )
    start_dates = merge(default_start_dates, model_params)

    # Generate forecasts
    nebula_forecast = model_nebula_revenue(months, prob_params["Nebula-NLU"], model_params, start_dates["NebulaStartMonth"])
    disclosure_forecast = model_disclosure_revenue(months, prob_params["Disclosure-NLU"], model_params, start_dates["DisclosureStartMonth"])
    lingua_forecast = model_lingua_revenue(months, prob_params["Lingua-NLU"], model_params, start_dates["LinguaStartMonth"])

    return StochasticResults(
        nebula_forecast,
        disclosure_forecast,
        lingua_forecast,
        prob_params
    )
end

end # module StochasticModel