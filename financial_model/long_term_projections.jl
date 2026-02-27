"""
long_term_projections.jl

Generates Years 3-5 (2028-2030) annual projections
"""

module LongTermProjections

using DataFrames, CSV, Dates
using ..LoadFactors

export project_years_3_to_5, extract_2027_baseline, validate_longterm_assumptions
export AnnualForecast, update_assumptions_with_baseline

struct AnnualForecast
    year::Int
    disclosure_revenue::Float64
    lingua_revenue::Float64
    nebula_revenue::Float64
    total_revenue::Float64
    cogs::Float64
    gross_profit::Float64
    gross_margin::Float64
    rd_opex::Float64
    sm_opex::Float64
    ga_opex::Float64
    commission_expense::Float64
    total_opex::Float64
    ebitda::Float64
    ebitda_margin::Float64
    net_income::Float64
    headcount::Int
    disclosure_cagr_effective::Float64
    lingua_cagr_effective::Float64
    nebula_cagr_effective::Float64
end

function project_years_3_to_5(
    baseline_2027::Dict,
    data_dir::String="data_longterm"
)

    println("📂 Loading long-term assumptions from $data_dir...")

    # ✅ AUTO-UPDATE BEFORE LOADING
    println("\n📝 Auto-updating assumptions_2028.csv with 2027 baseline...")
    update_assumptions_with_baseline(
        baseline_2027,
        "$data_dir/assumptions_2028.csv"
    )

    println("📂 Loading long-term assumptions from $data_dir...")

    assumptions_2028 = load_assumptions("$data_dir/assumptions_2028.csv")
    assumptions_2029 = load_assumptions("$data_dir/assumptions_2029.csv")
    assumptions_2030 = load_assumptions("$data_dir/assumptions_2030.csv")
    events = load_strategic_events("$data_dir/strategic_events.csv")
    deployment = load_series_b_deployment("$data_dir/series_b_deployment.csv")

    validate_longterm_assumptions(
        baseline_2027,
        assumptions_2028,
        assumptions_2029,
        assumptions_2030,
        events
    )

    println("Projecting 2028...")
    forecast_2028 = project_single_year(
        baseline_2027,
        assumptions_2028,
        filter_events(events, 2028),
        deployment,
        2028
    )

    println("Projecting 2029...")
    forecast_2029 = project_single_year(
        Dict(
            "disclosure_revenue" => forecast_2028.disclosure_revenue,
            "lingua_revenue" => forecast_2028.lingua_revenue,
            "nebula_revenue" => forecast_2028.nebula_revenue,
            "total_revenue" => forecast_2028.total_revenue
        ),
        assumptions_2029,
        filter_events(events, 2029),
        deployment,
        2029
    )

    println("Projecting 2030...")
    forecast_2030 = project_single_year(
        Dict(
            "disclosure_revenue" => forecast_2029.disclosure_revenue,
            "lingua_revenue" => forecast_2029.lingua_revenue,
            "nebula_revenue" => forecast_2029.nebula_revenue,
            "total_revenue" => forecast_2029.total_revenue
        ),
        assumptions_2030,
        filter_events(events, 2030),
        deployment,
        2030
    )

    println("✅ Long-term projections complete!")
    return [forecast_2028, forecast_2029, forecast_2030]
end

function project_single_year(
    prior_year::Dict,
    assumptions::DataFrame,
    events::DataFrame,
    deployment::DataFrame,
    year::Int
)

    # ========================================================================
    # STEP 1: CALCULATE REVENUE
    # ========================================================================

    # Extract base CAGR from assumptions CSV
    disclosure_cagr = get_param(assumptions, "disclosure_cagr")
    lingua_cagr = get_param(assumptions, "lingua_cagr")
    nebula_cagr = get_param(assumptions, "nebula_cagr")

    # Apply strategic event multipliers (multiplicative)
    disclosure_cagr = apply_event_multipliers(
        disclosure_cagr,
        events,
        "disclosure",
        ["revenue_acceleration", "revenue_headwind"]
    )
    lingua_cagr = apply_event_multipliers(
        lingua_cagr,
        events,
        "lingua",
        ["revenue_acceleration", "revenue_headwind"]
    )
    nebula_cagr = apply_event_multipliers(
        nebula_cagr,
        events,
        "nebula",
        ["revenue_acceleration", "revenue_headwind"]
    )

    # Calculate revenue for this year
    disclosure_revenue = prior_year["disclosure_revenue"] * (1 + disclosure_cagr)
    lingua_revenue = prior_year["lingua_revenue"] * (1 + lingua_cagr)
    nebula_revenue = prior_year["nebula_revenue"] * (1 + nebula_cagr)
    total_revenue = disclosure_revenue + lingua_revenue + nebula_revenue

    # ========================================================================
    # STEP 2: CALCULATE COGS
    # ========================================================================

    # Base gross margin from assumptions CSV
    gross_margin = get_param(assumptions, "gross_margin")

    # Apply margin improvement events (additive)
    margin_boost = 0.0
    margin_boost += sum_event_impacts(events, "margin_improvement", "all")
    margin_boost += sum_event_impacts(events, "margin_improvement", "disclosure")
    margin_boost += sum_event_impacts(events, "margin_improvement", "lingua")
    margin_boost += sum_event_impacts(events, "margin_improvement", "nebula")

    adjusted_gross_margin = gross_margin + margin_boost
    cogs = total_revenue * (1 - adjusted_gross_margin)
    gross_profit = total_revenue - cogs

    # ========================================================================
    # STEP 3: CALCULATE OPEX
    # ========================================================================

    # Base OpEx from assumptions CSV
    rd_opex = get_param(assumptions, "rd_opex")
    sm_opex = get_param(assumptions, "sm_opex")
    ga_opex = get_param(assumptions, "ga_opex")

    # Add Series B deployment amounts (gradual increase)
    if year in [2028, 2029, 2030]
        deployment_year = filter(row -> row.year == year, deployment)
        if !isempty(deployment_year)
            sm_deploy = sum(deployment_year[deployment_year.category.=="sales_marketing", :monthly_impact]; init=0.0)
            rd_deploy = sum(deployment_year[deployment_year.category.=="product_development", :monthly_impact]; init=0.0)
            ga_deploy = sum(deployment_year[deployment_year.category.=="general_admin", :monthly_impact]; init=0.0)

            sm_opex += sm_deploy
            rd_opex += rd_deploy
            ga_opex += ga_deploy
        end
    end

    # Calculate commission expense
    commission_rate = get_param(assumptions, "commission_rate")

    # Apply commission reduction events (multiplicative)
    commission_multiplier = apply_event_multipliers(
        1.0,
        events,
        "all",
        ["cost_reduction"]
    )
    adjusted_commission_rate = commission_rate * commission_multiplier
    commission_expense = total_revenue * adjusted_commission_rate

    total_opex = rd_opex + sm_opex + ga_opex + commission_expense

    # ========================================================================
    # STEP 4: CALCULATE EBITDA & NET INCOME
    # ========================================================================

    ebitda = gross_profit - total_opex
    ebitda_margin = ebitda / total_revenue

    # Simplified tax calculation (21% federal rate)
    # Assume no interest expense in long-term projection
    net_income = ebitda * 0.79  # After 21% tax

    # ========================================================================
    # STEP 5: EXTRACT HEADCOUNT
    # ========================================================================

    headcount = round(Int, get_param(assumptions, "total_headcount"))

    # ========================================================================
    # RETURN FORECAST STRUCT
    # ========================================================================

    return AnnualForecast(
        year,
        disclosure_revenue,
        lingua_revenue,
        nebula_revenue,
        total_revenue,
        cogs,
        gross_profit,
        adjusted_gross_margin,
        rd_opex,
        sm_opex,
        ga_opex,
        commission_expense,
        total_opex,
        ebitda,
        ebitda_margin,
        net_income,
        headcount,
        disclosure_cagr,  # Store effective CAGR (after events)
        lingua_cagr,
        nebula_cagr
    )
end

# ============================================================================
# HELPER FUNCTIONS - CSV LOADING
# ============================================================================

"""
load_assumptions(filepath::String)

Load annual assumptions CSV (assumptions_YYYY.csv)
Returns DataFrame with columns: parameter, value, unit, notes
Forces 'value' column to be parsed correctly
"""
function load_assumptions(filepath::String)
    if !isfile(filepath)
        error("❌ Assumptions file not found: $filepath\n" *
              "Please create this file using the template in data_longterm/README.md")
    end

    # First pass: read with automatic types to check structure
    df_check = CSV.read(filepath, DataFrame, comment="#", silencewarnings=true)

    # Validate required columns exist
    required_cols = ["parameter", "value"]
    for col in required_cols
        if !(col in names(df_check))
            error("❌ Missing required column '$col' in $filepath")
        end
    end

    # Second pass: force 'value' column to be read as String first (we'll convert later)
    # This prevents CSV.jl from making incorrect type assumptions
    df = CSV.read(
        filepath,
        DataFrame,
        comment="#",
        types=Dict(:parameter => String, :value => String),
        silencewarnings=true
    )

    # Clean and validate each value
    for i in 1:nrow(df)
        param = df[i, :parameter]
        value_str = df[i, :value]

        # Skip if empty or missing
        if ismissing(value_str) || isempty(strip(value_str))
            continue  # Will be caught in validation
        end

        # Try to parse as number
        cleaned = strip(value_str)
        try
            df[i, :value] = parse(Float64, cleaned)
        catch e
            # Check if it's a date parameter (should stay as string)
            if occursin("date", lowercase(param)) || occursin("month", lowercase(param))
                # Keep as string for date parameters
                df[i, :value] = cleaned
            else
                # @warn "⚠️ Could not parse '$param' value '$value_str' as number in $filepath (will validate later)"
            end
        end
    end

    println("  ✅ Loaded $(nrow(df)) parameters from $(basename(filepath))")
    return df
end

"""
load_strategic_events(filepath::String)

Load strategic events CSV
Returns DataFrame with columns: event_id, event_name, start_date, end_date, impact_type, platform, multiplier, description
"""
function load_strategic_events(filepath::String)
    if !isfile(filepath)
        error("❌ Strategic events file not found: $filepath\n" *
              "Please create this file using the template in data_longterm/README.md")
    end

    df = CSV.read(filepath, DataFrame, comment="#")

    # Validate required columns
    required_cols = ["event_id", "event_name", "start_date", "end_date", "impact_type", "platform", "multiplier"]
    for col in required_cols
        if !(col in names(df))
            error("❌ Missing required column '$col' in $filepath")
        end
    end

    # Parse dates (handle both String and Date types - FIX FOR DATE PARSING ERROR)
    if eltype(df.start_date) <: AbstractString
        try
            df.start_date = Date.(df.start_date, dateformat"yyyy-mm-dd")
        catch e
            error("❌ Invalid date format in start_date column. Use YYYY-MM-DD format.\n" *
                  "Example: 2028-06-01\n" *
                  "Error: $e")
        end
    elseif !(eltype(df.start_date) <: Union{Date,Missing})
        error("❌ start_date column must be Date or String type, got $(eltype(df.start_date))")
    end

    if eltype(df.end_date) <: AbstractString
        try
            df.end_date = Date.(df.end_date, dateformat"yyyy-mm-dd")
        catch e
            error("❌ Invalid date format in end_date column. Use YYYY-MM-DD format.\n" *
                  "Example: 2030-12-31\n" *
                  "Error: $e")
        end
    elseif !(eltype(df.end_date) <: Union{Date,Missing})
        error("❌ end_date column must be Date or String type, got $(eltype(df.end_date))")
    end

    println("  ✅ Loaded $(nrow(df)) strategic events from $(basename(filepath))")
    return df
end

"""
load_series_b_deployment(filepath::String)

Load Series B deployment schedule CSV
Returns DataFrame with monthly impacts per category
"""
function load_series_b_deployment(filepath::String)
    if !isfile(filepath)
        @warn "⚠️ Series B deployment file not found: $filepath (proceeding without deployment)"
        return DataFrame(
            year=Int[],
            category=String[],
            monthly_impact=Float64[]
        )
    end

    df = CSV.read(filepath, DataFrame, comment="#")

    # Convert simplified format (total_amount, deploy_over_months) to monthly impacts
    if "total_amount" in names(df) && "deploy_over_months" in names(df)
        # Calculate monthly rate
        df.monthly_rate = df.total_amount ./ df.deploy_over_months

        # Parse start_month to Date (handle both String and Date types - FIX FOR DATE PARSING ERROR)
        if "start_month" in names(df)
            if eltype(df.start_month) <: AbstractString
                try
                    df.start_date = Date.(df.start_month, dateformat"yyyy-mm-dd")
                catch e
                    error("❌ Invalid date format in start_month column. Use YYYY-MM-DD format.\n" *
                          "Example: 2028-06-01\n" *
                          "Error: $e")
                end
            elseif eltype(df.start_month) <: Date
                df.start_date = df.start_month  # Already a Date
            else
                error("❌ start_month column must be Date or String type, got $(eltype(df.start_month))")
            end
        else
            error("❌ start_month column not found in $filepath")
        end

        # Expand into annual impacts
        expanded = DataFrame(
            year=Int[],
            category=String[],
            monthly_impact=Float64[]
        )

        for row in eachrow(df)
            start_year = year(row.start_date)
            end_year = start_year + ceil(Int, row.deploy_over_months / 12) - 1

            for yr in start_year:end_year
                months_in_year = if yr == start_year
                    # First year: from start_month to Dec
                    13 - month(row.start_date)
                elseif yr == end_year
                    # Last year: from Jan to end of deployment
                    remaining_months = row.deploy_over_months - (12 * (yr - start_year - 1) + (13 - month(row.start_date)))
                    min(12, remaining_months)
                else
                    # Middle years: full 12 months
                    12
                end

                annual_impact = row.monthly_rate * months_in_year

                push!(expanded, (
                    year=yr,
                    category=row.category,
                    monthly_impact=annual_impact
                ))
            end
        end

        df = expanded
    end

    println("  ✅ Loaded Series B deployment schedule from $(basename(filepath))")
    return df
end

# ============================================================================
# HELPER FUNCTIONS - PARAMETER EXTRACTION
# ============================================================================

"""
get_param(df::DataFrame, param_name::String)

Extract parameter value from assumptions DataFrame with robust type handling
"""
function get_param(df::DataFrame, param_name::String)
    row = filter(r -> r.parameter == param_name, df)
    if isempty(row)
        error("❌ Required parameter '$param_name' not found in assumptions CSV")
    end

    value = row[1, :value]

    # Handle different types robustly
    if ismissing(value)
        error("❌ Parameter '$param_name' has missing value")
    elseif value isa Number
        return Float64(value)
    elseif value isa AbstractString
        # Try to parse as number
        cleaned = strip(String(value))
        if isempty(cleaned)
            error("❌ Parameter '$param_name' has empty value")
        end

        try
            return parse(Float64, cleaned)
        catch e
            error("❌ Parameter '$param_name' has non-numeric value: '$value'\n" *
                  "Expected a number, got a string that can't be converted.\n" *
                  "Check your CSV file for typos or missing values.")
        end
    else
        error("❌ Parameter '$param_name' has unexpected type: $(typeof(value))")
    end
end

"""
apply_event_multipliers(base_value::Float64, events::DataFrame, platform::String, impact_types::Vector{String})

Apply multiplicative event multipliers to a base value

Example:
  base_cagr = 0.88
  event1: revenue_acceleration, multiplier = 1.15 → 0.88 * 1.15 = 1.012
  event2: revenue_headwind, multiplier = 0.92 → 1.012 * 0.92 = 0.931
"""
function apply_event_multipliers(
    base_value::Float64,
    events::DataFrame,
    platform::String,
    impact_types::Vector{String}
)
    multiplier = 1.0

    for impact_type in impact_types
        relevant_events = filter(
            row -> row.platform in [platform, "all"] && row.impact_type == impact_type,
            events
        )

        for event in eachrow(relevant_events)
            multiplier *= event.multiplier
        end
    end

    return base_value * multiplier
end

"""
sum_event_impacts(events::DataFrame, impact_type::String, platform::String)

Sum additive event impacts (for margin improvements)

Example:
  event1: margin_improvement, platform=all, multiplier=0.02 → +2%
  event2: margin_improvement, platform=disclosure, multiplier=0.01 → +1%
  Total: +3% margin boost
"""
function sum_event_impacts(
    events::DataFrame,
    impact_type::String,
    platform::String
)
    relevant_events = filter(
        row -> row.platform in [platform, "all"] && row.impact_type == impact_type,
        events
    )

    return sum(event.multiplier for event in eachrow(relevant_events); init=0.0)
end

"""
filter_events(events::DataFrame, year::Int)

Filter events that are active in a given year
"""
function filter_events(events::DataFrame, year::Int)
    return filter(row ->
            Dates.year(row.start_date) <= year <= Dates.year(row.end_date),
        events
    )
end

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

"""
validate_longterm_assumptions(baseline_2027, assumptions_2028, assumptions_2029, assumptions_2030, events)

Validate that long-term assumptions are consistent with 2027 baseline and internally coherent.
Collects ALL errors before failing (instead of stopping at first error).
"""
function validate_longterm_assumptions(
    baseline_2027::Dict,
    assumptions_2028::DataFrame,
    assumptions_2029::DataFrame,
    assumptions_2030::DataFrame,
    events::DataFrame
)

    println("\n🔍 Validating long-term assumptions...")

    errors = String[]  # Collect all errors
    warnings = String[]  # Collect all warnings

    # ========================================================================
    # VALIDATION 1: Check all required parameters exist and are numeric
    # ========================================================================

    required_params_2028 = [
        "disclosure_revenue_2027", "lingua_revenue_2027", "nebula_revenue_2027",
        "disclosure_cagr", "lingua_cagr", "nebula_cagr",
        "gross_margin", "commission_rate",
        "rd_opex", "sm_opex", "ga_opex",
        "total_headcount"
    ]

    required_params_2029 = [
        "disclosure_revenue_2028", "lingua_revenue_2028", "nebula_revenue_2028",
        "disclosure_cagr", "lingua_cagr", "nebula_cagr",
        "gross_margin", "commission_rate",
        "rd_opex", "sm_opex", "ga_opex",
        "total_headcount"
    ]

    required_params_2030 = [
        "disclosure_revenue_2029", "lingua_revenue_2029", "nebula_revenue_2029",
        "disclosure_cagr", "lingua_cagr", "nebula_cagr",
        "gross_margin", "commission_rate",
        "rd_opex", "sm_opex", "ga_opex",
        "total_headcount"
    ]

    # Check 2028 parameters
    for param in required_params_2028
        row = filter(r -> r.parameter == param, assumptions_2028)
        if isempty(row)
            push!(errors, "❌ Missing required parameter '$param' in assumptions_2028.csv")
        else
            value = row[1, :value]
            if ismissing(value)
                push!(errors, "❌ Parameter '$param' has missing value in assumptions_2028.csv")
            elseif value isa AbstractString
                cleaned = strip(String(value))
                if isempty(cleaned)
                    push!(errors, "❌ Parameter '$param' has empty value in assumptions_2028.csv")
                else
                    try
                        parse(Float64, cleaned)
                    catch
                        push!(errors, "❌ Parameter '$param' in assumptions_2028.csv is not numeric: '$value'")
                    end
                end
            elseif !(value isa Number)
                push!(errors, "❌ Parameter '$param' in assumptions_2028.csv has unexpected type: $(typeof(value))")
            end
        end
    end

    # Check 2029 parameters
    for param in required_params_2029
        row = filter(r -> r.parameter == param, assumptions_2029)
        if isempty(row)
            push!(errors, "❌ Missing required parameter '$param' in assumptions_2029.csv")
        else
            value = row[1, :value]
            if ismissing(value) || (value isa AbstractString && isempty(strip(String(value))))
                push!(errors, "❌ Parameter '$param' has missing/empty value in assumptions_2029.csv")
            elseif value isa AbstractString
                try
                    parse(Float64, strip(String(value)))
                catch
                    push!(errors, "❌ Parameter '$param' in assumptions_2029.csv is not numeric: '$value'")
                end
            end
        end
    end

    # Check 2030 parameters
    for param in required_params_2030
        row = filter(r -> r.parameter == param, assumptions_2030)
        if isempty(row)
            push!(errors, "❌ Missing required parameter '$param' in assumptions_2030.csv")
        else
            value = row[1, :value]
            if ismissing(value) || (value isa AbstractString && isempty(strip(String(value))))
                push!(errors, "❌ Parameter '$param' has missing/empty value in assumptions_2030.csv")
            elseif value isa AbstractString
                try
                    parse(Float64, strip(String(value)))
                catch
                    push!(errors, "❌ Parameter '$param' in assumptions_2030.csv is not numeric: '$value'")
                end
            end
        end
    end

    # ========================================================================
    # VALIDATION 2: 2028 starting revenue matches 2027 ending (±5% threshold)
    # ========================================================================

    threshold = 0.05  # 5% variance allowed

    for (platform, csv_param) in [
        ("disclosure", "disclosure_revenue_2027"),
        ("lingua", "lingua_revenue_2027"),
        ("nebula", "nebula_revenue_2027")
    ]
        baseline_value = baseline_2027["$(platform)_revenue"]

        # Only validate if parameter exists and is numeric
        row = filter(r -> r.parameter == csv_param, assumptions_2028)
        if !isempty(row)
            value = row[1, :value]
            if value isa Number || (value isa AbstractString && !isempty(strip(String(value))))
                try
                    csv_value = value isa Number ? Float64(value) : parse(Float64, strip(String(value)))
                    variance = abs(baseline_value - csv_value) / baseline_value

                    if variance > threshold
                        push!(errors, "❌ Large mismatch in $platform 2027 revenue:\n" *
                                      "  Detailed model: \$$(round(baseline_value, digits=0))\n" *
                                      "  assumptions_2028.csv: \$$(round(csv_value, digits=0))\n" *
                                      "  Variance: $(round(variance * 100, digits=1))% (threshold: $(threshold * 100)%)\n" *
                                      "  → Update assumptions_2028.csv line for '$csv_param'")
                    elseif variance > 0.01  # Warn if >1% but <5%
                        push!(warnings, "⚠️ Minor variance in $platform 2027 revenue: $(round(variance * 100, digits=1))% (acceptable)")
                    else
                        println("  ✅ $platform 2027 revenue consistent (variance: $(round(variance * 100, digits=2))%)")
                    end
                catch e
                    push!(errors, "❌ Cannot compare $platform 2027 revenue due to type error: $e")
                end
            end
        end
    end

    # ========================================================================
    # VALIDATION 3: CAGR values are reasonable (-100% to 500%)
    # ========================================================================

    for (year, assumptions, file) in [
        (2028, assumptions_2028, "assumptions_2028.csv"),
        (2029, assumptions_2029, "assumptions_2029.csv"),
        (2030, assumptions_2030, "assumptions_2030.csv")
    ]
        for platform in ["disclosure", "lingua", "nebula"]
            param_name = "$(platform)_cagr"
            row = filter(r -> r.parameter == param_name, assumptions)
            if !isempty(row)
                value = row[1, :value]
                try
                    cagr = value isa Number ? Float64(value) : parse(Float64, strip(String(value)))

                    if cagr < -1.0
                        push!(errors, "❌ Extremely negative CAGR for $platform in $year: $(round(cagr * 100, digits=1))% (check $file)")
                    elseif cagr < 0
                        push!(warnings, "⚠️ Negative CAGR for $platform in $year: $(round(cagr * 100, digits=1))% (unusual but allowed)")
                    elseif cagr > 5.0
                        push!(warnings, "⚠️ Very high CAGR for $platform in $year: $(round(cagr * 100, digits=1))% (verify assumptions)")
                    end
                catch e
                    # Already caught in parameter existence check
                end
            end
        end
    end

    # ========================================================================
    # VALIDATION 4: Gross margins are between 0% and 100%
    # ========================================================================

    for (year, assumptions, file) in [
        (2028, assumptions_2028, "assumptions_2028.csv"),
        (2029, assumptions_2029, "assumptions_2029.csv"),
        (2030, assumptions_2030, "assumptions_2030.csv")
    ]
        row = filter(r -> r.parameter == "gross_margin", assumptions)
        if !isempty(row)
            value = row[1, :value]
            try
                gm = value isa Number ? Float64(value) : parse(Float64, strip(String(value)))

                if gm < 0 || gm > 1
                    push!(errors, "❌ Invalid gross margin in $year: $(round(gm * 100, digits=1))% (must be 0-100% in $file)")
                end
            catch e
                # Already caught in parameter existence check
            end
        end
    end

    # ========================================================================
    # VALIDATION 5: Strategic events have valid date ranges
    # ========================================================================

    for event in eachrow(events)
        if event.start_date > event.end_date
            push!(errors, "❌ Event '$(event.event_name)' (ID: $(event.event_id)) has start_date after end_date")
        end
    end

    # ========================================================================
    # REPORT ALL ERRORS AND WARNINGS
    # ========================================================================

    # Print warnings first
    if !isempty(warnings)
        println("\n⚠️  WARNINGS ($(length(warnings))):")
        for warning in warnings
            println("  $warning")
        end
    end

    # Print errors
    if !isempty(errors)
        println("\n❌ VALIDATION FAILED - $(length(errors)) error(s) found:\n")
        for (i, err) in enumerate(errors)
            println("ERROR $i:")
            println("  $err")
            println()
        end

        println("="^80)
        println("TROUBLESHOOTING TIPS:")
        println("="^80)
        println("1. Check CSV files in data_longterm/ for:")
        println("   - Missing values (empty cells)")
        println("   - Non-numeric values in numeric columns")
        println("   - Typos in parameter names")
        println()
        println("2. Common fixes:")
        println("   - Open CSV in text editor (not Excel - it can corrupt formatting)")
        println("   - Ensure 'value' column has numbers only (no text, no special chars)")
        println("   - Remove any hidden characters or extra spaces")
        println()
        println("3. After fixing, re-run: julia main.jl")
        println("="^80)

        error("Validation failed with $(length(errors)) error(s). See above for details.")
    end

    println("\n✅ All validations passed!")
    if !isempty(warnings)
        println("   (with $(length(warnings)) warning(s) - review above)")
    end
    println()
end

"""
extract_2027_baseline(nebula_f, disclosure_f, lingua_f)

Extract 2027 ending state from detailed model forecasts

Arguments:
- nebula_f: Vector of MonthlyForecast from StochasticModel
- disclosure_f: Vector of DisclosureForecast from StochasticModel
- lingua_f: Vector of LinguaForecast from StochasticModel

Returns:
- Dict with annualized 2027 ending revenue
"""
function extract_2027_baseline(nebula_f, disclosure_f, lingua_f)
    # Get Dec 2027 data
    nebula_dec = filter(f -> f.month == "Dec 2027", nebula_f)
    disclosure_dec = filter(f -> f.month == "Dec 2027", disclosure_f)
    lingua_dec = filter(f -> f.month == "Dec 2027", lingua_f)

    if isempty(nebula_dec) || isempty(disclosure_dec) || isempty(lingua_dec)
        error("❌ Could not find Dec 2027 data in forecast. Check that timeline extends through 2027.")
    end

    nebula_dec = nebula_dec[1]
    disclosure_dec = disclosure_dec[1]
    lingua_dec = lingua_dec[1]

    # Annualize monthly revenue (revenue_k is in thousands, monthly)
    baseline = Dict(
        "disclosure_revenue" => disclosure_dec.revenue_k * 1000 * 12,
        "lingua_revenue" => lingua_dec.revenue_k * 1000 * 12,
        "nebula_revenue" => nebula_dec.revenue_k * 1000 * 12,
        "total_revenue" => (disclosure_dec.revenue_k + lingua_dec.revenue_k + nebula_dec.revenue_k) * 1000 * 12,
        "disclosure_customers" => disclosure_dec.total_clients,
        "lingua_pairs" => lingua_dec.active_pairs,
        "nebula_subscribers" => nebula_dec.total_customers
    )

    println("\n📌 2027 Baseline Extracted:")
    println("  Disclosure: \$$(round(baseline["disclosure_revenue"], digits=0)) ($(baseline["disclosure_customers"]) customers)")
    println("  Lingua: \$$(round(baseline["lingua_revenue"], digits=0)) ($(baseline["lingua_pairs"]) pairs)")
    println("  Nebula: \$$(round(baseline["nebula_revenue"], digits=0)) ($(baseline["nebula_subscribers"]) subscribers)")
    println("  Total: \$$(round(baseline["total_revenue"], digits=0))")
    println()

    return baseline
end

"""
update_assumptions_with_baseline(baseline_2027::Dict, assumptions_file::String)

Automatically update assumptions_2028.csv with actual 2027 ending values
"""
function update_assumptions_with_baseline(baseline_2027::Dict, assumptions_file::String)
    # Read current assumptions (force value column to String to allow updates)
    df = CSV.read(
        assumptions_file,
        DataFrame,
        comment="#",
        types=Dict(:parameter => String, :value => String),
        silencewarnings=true
    )

    # Update the three revenue parameters
    for (param, key) in [
        ("disclosure_revenue_2027", "disclosure_revenue"),
        ("lingua_revenue_2027", "lingua_revenue"),
        ("nebula_revenue_2027", "nebula_revenue")
    ]
        idx = findfirst(df.parameter .== param)
        if idx !== nothing
            old_value = df[idx, :value]
            new_value = string(round(Int, baseline_2027[key]))  # ✅ Convert to string

            if old_value != new_value
                println("  📝 Updating $param: $old_value → $new_value")
                df[idx, :value] = new_value  # Now writing String to String column
            end
        end
    end

    # Write back to CSV
    CSV.write(assumptions_file, df)
    println("  ✅ Updated $assumptions_file with 2027 baseline")
end

end # module LongTermProjections