module StochasticModel

using Dates, Distributions, Random
using ..LoadFactors

export MonthlyForecast, DiscoveryForecast, NoetherForecast
export model_nebula_revenue, model_discovery_revenue, model_noether_revenue
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

struct DiscoveryForecast
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

struct NoetherForecast
    month::String
    new_clients::Int
    total_clients::Int
    total_solo::Int
    total_small::Int
    total_medium::Int
    total_large::Int
    total_biglaw::Int
    total_corp::Int
    revenue_k::Float64
end

struct StochasticResults
    nebula_forecast::Vector{MonthlyForecast}
    discoverynlu_forecast::Vector{DiscoveryForecast}
    noether_forecast::Vector{NoetherForecast}
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

function model_discovery_revenue(months::Vector{String}, params::Dict{String,Float64}, model_params::Dict{String,Any}, start_month_name::String)
    # Extract parameters from CSV — DiscoveryNLU-specific pricing keys
    solo_annual = model_params["DiscoverySoloAnnualRevenue"]
    small_annual = model_params["DiscoverySmallAnnualRevenue"]
    medium_annual = model_params["DiscoveryMediumAnnualRevenue"]
    large_annual = model_params["DiscoveryLargeAnnualRevenue"]
    biglaw_annual = model_params["DiscoveryBigLawAnnualRevenue"]

    # Firm acquisition rates from probability_parameters.csv
    lambda_solo = params["lambda_solo_firms"]
    lambda_small = params["lambda_small_firms"]
    lambda_medium = params["lambda_medium_firms"]
    lambda_large = get(params, "lambda_large_firms", 0.1)
    lambda_biglaw = get(params, "lambda_biglaw_firms", 0.05)

    # Find the start index for revenue generation
    sales_start_idx = findfirst(==(start_month_name), months)
    if sales_start_idx === nothing
        return DiscoveryForecast[]
    end

    # Start months for Large and BigLaw from CSV
    large_start_month_name = get(model_params, "DiscoveryLargeStartMonth", "Jan 2027")
    biglaw_start_month_name = get(model_params, "DiscoveryBigLawStartMonth", "Jan 2027")

    large_start_idx = something(findfirst(==(large_start_month_name), months), length(months) + 1)
    biglaw_start_idx = something(findfirst(==(biglaw_start_month_name), months), length(months) + 1)

    forecasts = DiscoveryForecast[]
    total_solo, total_small, total_medium, total_large, total_biglaw = 0.0, 0.0, 0.0, 0.0, 0.0
    churn_dist = Beta(1, 15)  # Low churn for legal professionals

    for (i, month_name) in enumerate(months)
        new_solo, new_small, new_medium, new_large, new_biglaw = 0, 0, 0, 0, 0

        if i >= sales_start_idx
            new_solo = rand(Poisson(lambda_solo))
            new_small = rand(Poisson(lambda_small))
            new_medium = rand(Poisson(lambda_medium))

            if i >= large_start_idx
                new_large = rand(Poisson(lambda_large))
            end
            if i >= biglaw_start_idx
                new_biglaw = rand(Poisson(lambda_biglaw))
            end

            if i == sales_start_idx || i == sales_start_idx + 1
                println("DEBUG DiscoveryNLU $(month_name): New firms - Solo:$(new_solo), Small:$(new_small), Medium:$(new_medium)")
            end
        end

        # Apply Beta(1,15) churn
        monthly_churn_rate = 1 - (1 - rand(churn_dist))^(1 / 12)
        total_solo = total_solo * (1 - monthly_churn_rate) + new_solo
        total_small = total_small * (1 - monthly_churn_rate) + new_small
        total_medium = total_medium * (1 - monthly_churn_rate) + new_medium
        total_large = total_large * (1 - monthly_churn_rate) + new_large
        total_biglaw = total_biglaw * (1 - monthly_churn_rate) + new_biglaw

        total_customers = round(Int, total_solo + total_small + total_medium + total_large + total_biglaw)

        monthly_revenue = (total_solo * solo_annual / 12 +
                           total_small * small_annual / 12 +
                           total_medium * medium_annual / 12 +
                           total_large * large_annual / 12 +
                           total_biglaw * biglaw_annual / 12)

        if monthly_revenue > 0 && (i == sales_start_idx || i == sales_start_idx + 1)
            println("DEBUG DiscoveryNLU $(month_name): Revenue=$(round(monthly_revenue)), Solo=$(round(Int,total_solo)), Small=$(round(Int,total_small)), Medium=$(round(Int,total_medium))")
        end

        push!(forecasts, DiscoveryForecast(
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

function model_noether_revenue(months::Vector{String}, params::Dict{String,Float64}, model_params::Dict{String,Any}, start_month_name::String)
    # Extract Noether.studio pricing parameters
    solo_annual   = model_params["NoetherSoloAnnualRevenue"]
    small_annual  = model_params["NoetherSmallAnnualRevenue"]
    medium_annual = model_params["NoetherMediumAnnualRevenue"]
    large_annual  = model_params["NoetherLargeAnnualRevenue"]
    biglaw_annual = model_params["NoetherBigLawAnnualRevenue"]
    corp_annual   = model_params["NoetherCorpAnnualRevenue"]

    # Firm acquisition rates from probability_parameters.csv (Noether section)
    lambda_solo   = params["lambda_solo_firms"]
    lambda_small  = params["lambda_small_firms"]
    lambda_medium = params["lambda_medium_firms"]
    lambda_large  = get(params, "lambda_large_firms", 0.1)
    lambda_biglaw = get(params, "lambda_biglaw_firms", 0.1)
    lambda_corp   = get(params, "lambda_corp_firms", 0.15)

    sales_start_idx = findfirst(==(start_month_name), months)
    if sales_start_idx === nothing
        return NoetherForecast[]
    end

    # Tier unlock timing from CSV
    large_start_month_name  = get(model_params, "NoetherLargeStartMonth",  "Jan 2027")
    biglaw_start_month_name = get(model_params, "NoetherBigLawStartMonth", "Jan 2027")
    corp_start_month_name   = get(model_params, "NoetherCorpStartMonth",   "Mar 2027")

    large_start_idx  = something(findfirst(==(large_start_month_name),  months), length(months) + 1)
    biglaw_start_idx = something(findfirst(==(biglaw_start_month_name), months), length(months) + 1)
    corp_start_idx   = something(findfirst(==(corp_start_month_name),   months), length(months) + 1)

    forecasts = NoetherForecast[]
    total_solo, total_small, total_medium = 0.0, 0.0, 0.0
    total_large, total_biglaw, total_corp = 0.0, 0.0, 0.0
    churn_dist = Beta(1, 15)  # Same low-churn model as DiscoveryNLU

    for (i, month_name) in enumerate(months)
        new_solo, new_small, new_medium = 0, 0, 0
        new_large, new_biglaw, new_corp  = 0, 0, 0

        if i >= sales_start_idx
            new_solo   = rand(Poisson(lambda_solo))
            new_small  = rand(Poisson(lambda_small))
            new_medium = rand(Poisson(lambda_medium))

            if i >= large_start_idx
                new_large = rand(Poisson(lambda_large))
            end
            if i >= biglaw_start_idx
                new_biglaw = rand(Poisson(lambda_biglaw))
            end
            if i >= corp_start_idx
                new_corp = rand(Poisson(lambda_corp))
            end

            if i == sales_start_idx || i == sales_start_idx + 1
                println("DEBUG Noether $(month_name): New firms - Solo:$(new_solo), Small:$(new_small), Medium:$(new_medium)")
            end
        end

        # Apply Beta(1,15) churn — same model as DiscoveryNLU
        monthly_churn_rate = 1 - (1 - rand(churn_dist))^(1 / 12)
        total_solo   = total_solo   * (1 - monthly_churn_rate) + new_solo
        total_small  = total_small  * (1 - monthly_churn_rate) + new_small
        total_medium = total_medium * (1 - monthly_churn_rate) + new_medium
        total_large  = total_large  * (1 - monthly_churn_rate) + new_large
        total_biglaw = total_biglaw * (1 - monthly_churn_rate) + new_biglaw
        total_corp   = total_corp   * (1 - monthly_churn_rate) + new_corp

        total_clients = round(Int, total_solo + total_small + total_medium +
                                   total_large + total_biglaw + total_corp)

        monthly_revenue = (total_solo   * solo_annual   / 12 +
                           total_small  * small_annual  / 12 +
                           total_medium * medium_annual / 12 +
                           total_large  * large_annual  / 12 +
                           total_biglaw * biglaw_annual / 12 +
                           total_corp   * corp_annual   / 12)

        if monthly_revenue > 0 && (i == sales_start_idx || i == sales_start_idx + 1)
            println("DEBUG Noether $(month_name): Revenue=$(round(monthly_revenue)), Solo=$(round(Int,total_solo)), Small=$(round(Int,total_small))")
        end

        push!(forecasts, NoetherForecast(
            month_name,
            new_solo + new_small + new_medium + new_large + new_biglaw + new_corp,
            total_clients,
            round(Int, total_solo),
            round(Int, total_small),
            round(Int, total_medium),
            round(Int, total_large),
            round(Int, total_biglaw),
            round(Int, total_corp),
            monthly_revenue / 1000
        ))
    end

    return forecasts
end

function run_stochastic_analysis(months::Vector{String})
    # Load configuration from CSV files
    prob_params = LoadFactors.load_probability_parameters("data/probability_parameters.csv")
    model_params = LoadFactors.load_model_parameters("data/model_parameters.csv")

    # Centralized start dates — overridden by values in model_parameters.csv
    default_start_dates = Dict(
        "NebulaNLU_Revenue_Start"   => "Jul 2026",
        "DiscoveryNLU_Revenue_Start" => "Aug 2026",
        "NoetherNLU_Revenue_Start"   => "Sep 2026"
    )
    start_dates = merge(default_start_dates, model_params)

    # Generate forecasts — platform keys must match probability_parameters.csv Platform column
    nebula_forecast      = model_nebula_revenue(months,    prob_params["NebulaNLU"],   model_params, start_dates["NebulaNLU_Revenue_Start"])
    discoverynlu_forecast = model_discovery_revenue(months, prob_params["DiscoveryNLU"], model_params, start_dates["DiscoveryNLU_Revenue_Start"])
    noether_forecast     = model_noether_revenue(months,   prob_params["Noether"],     model_params, start_dates["NoetherNLU_Revenue_Start"])

    return StochasticResults(
        nebula_forecast,
        discoverynlu_forecast,
        noether_forecast,
        prob_params
    )
end

end # module StochasticModel
