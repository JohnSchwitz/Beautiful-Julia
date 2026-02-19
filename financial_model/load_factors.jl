module LoadFactors

using DataFrames, CSV, Dates
export load_cost_factors, load_salaries, load_headcount,
    load_model_parameters, load_probability_parameters,
    load_timeline, load_active_months,  # ← Added load_active_months
    load_financing, load_tasks, load_resource_plan

function load_cost_factors(filepath::String="data/cost_factors.csv")
    df = CSV.read(filepath, DataFrame)
    return df
end

function load_model_parameters(filepath::String="config/model_parameters.csv")
    df = CSV.read(filepath, DataFrame, header=1, types=[String, String, String])

    params = Dict{String,Any}()

    for row in eachrow(df)
        # Access columns by name
        param_name = row.Parameter
        param_value_str = row.Value

        # Skip if this is the header row (shouldn't happen but safe check)
        if param_name == "Parameter"
            continue
        end

        # Try to convert to number if possible, otherwise keep as string
        if !ismissing(param_value_str) && param_value_str != ""
            value = try
                parse(Float64, param_value_str)
            catch
                param_value_str  # Keep as string for month names
            end

            params[param_name] = value
        end
    end

    return params
end

function load_probability_parameters(filepath::String="data/probability_parameters.csv")
    df = CSV.read(filepath, DataFrame)
    params = Dict{String,Dict{String,Float64}}()
    for row in eachrow(df)
        platform = row.Platform
        if !haskey(params, platform)
            params[platform] = Dict{String,Float64}()
        end
        params[platform][row.Parameter_Name] = parse(Float64, string(row.Parameter_Value))
    end
    return params
end

function load_financing(filepath::String="data/financing.csv")
    df = CSV.read(filepath, DataFrame)
    return df
end

function load_sales_force(filepath::String="data/sales_force.csv")
    return CSV.read(filepath, DataFrame)
end

function load_headcount(filepath::String="data/Headcount.csv")
    return CSV.read(filepath, DataFrame)
end

function load_salaries(filepath::String="data/Salaries.csv")
    return CSV.read(filepath, DataFrame)
end

function load_timeline(filepath::String="data/timeline.csv")
    df = CSV.read(filepath, DataFrame)
    timeline_params = Dict(row.Parameter => row.Value for row in eachrow(df))
    start_date = Date(timeline_params["StartDate"])
    end_date = Date(timeline_params["EndDate"])
    return [Dates.format(d, "U Y") for d in start_date:Dates.Month(1):end_date]
end

function load_active_months(filepath::String="data/active_months.csv")
    """
    Load the list of active months for forecasting.
    Returns a DataFrame with a single column 'Month' containing month strings.
    """
    df = CSV.read(filepath, DataFrame, header=true, stringtype=String)  # ← Force String type
    return df
end

end # module LoadFactors