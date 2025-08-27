# load_factors.jl
module LoadFactors

using DataFrames, CSV
export ResourcePlan, ProjectTask, load_configuration, load_resource_plan, load_tasks, load_probability_parameters, load_cost_factors

struct ResourcePlan
    work_days::Vector{Int}
    experienced_devs::Vector{Float64}
    intern_devs::Vector{Float64}
    experienced_marketers::Vector{Float64}
    intern_marketers::Vector{Float64}
    dev_efficiency::Vector{Float64}
    marketing_efficiency::Vector{Float64}
    months::Vector{String}
    dev_productivity_factor::Float64
    marketing_productivity_factor::Float64
    intern_productivity_factor::Float64
end

struct ProjectTask
    name::String
    planned_hours::Int
    sequence::Int
    task_type::String
end

function load_configuration(filepath::String)
    config_df = CSV.read(filepath, DataFrame)
    config_dict = Dict(row.key => parse(Float64, string(row.value)) for row in eachrow(config_df))
    return config_dict
end

function load_resource_plan(filepath::String, config::Dict)
    df = CSV.read(filepath, DataFrame)
    return ResourcePlan(
        df.work_days,
        df.experienced_devs,
        df.intern_devs,
        df.experienced_marketers,
        df.intern_marketers,
        df.dev_efficiency,
        df.marketing_efficiency,
        df.month,
        config["dev_productivity_factor"],
        config["marketing_productivity_factor"],
        config["intern_productivity_factor"]
    )
end

function load_tasks(filepath::String)
    df = CSV.read(filepath, DataFrame)
    return [ProjectTask(row.name, row.planned_hours, row.sequence, row.task_type) for row in eachrow(df)]
end

function load_probability_parameters(filepath::String)
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

function load_cost_factors(filepath::String="cost_factors.csv")
    df = CSV.read(filepath, DataFrame)
    return df
end

end # module LoadFactors