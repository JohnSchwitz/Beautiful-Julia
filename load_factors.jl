module LoadFactors

using DataFrames, CSV
export ResourcePlan, load_project_tasks, ProjectTask, load_configuration, load_resource_plan, load_tasks, load_probability_parameters, load_cost_factors, load_model_parameters, create_resource_plan

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

function load_resource_plan_with_config(filepath::String, config::Dict)
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

function load_resource_plan()
    config = load_configuration("data/config.csv")
    return load_resource_plan_with_config("data/resource_plan.csv", config)
end

function create_resource_plan()
    return load_resource_plan()
end

function load_tasks(filepath::String)
    df = CSV.read(filepath, DataFrame)
    println("DEBUG: Loaded tasks:")
    for row in eachrow(df)
        println("  $(row.Name) - Seq: $(row.Sequence) - Hours: $(row.PlannedHours)")
    end
    # Handle missing sequence values
    tasks = ProjectTask[]
    for row in eachrow(df)
        seq = ismissing(row.Sequence) ? 999 : row.Sequence  # Put unsequenced tasks at end
        push!(tasks, ProjectTask(row.Name, row.PlannedHours, seq, row.TaskType))
    end
    return tasks
end

function load_project_tasks()
    return load_tasks("data/project_tasks.csv")
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

function load_cost_factors(filepath::String="data/cost_factors.csv")
    df = CSV.read(filepath, DataFrame)
    return df
end

function load_model_parameters(filepath::String="data/model_parameters.csv")
    df = CSV.read(filepath, DataFrame)
    params = Dict{String,Any}()
    for row in eachrow(df)
        # Handle different data types
        if row.ParameterValue == "true"
            params[row.ParameterName] = true
        elseif row.ParameterValue == "false"
            params[row.ParameterName] = false
        elseif occursin("NLU_MVP", string(row.ParameterValue)) || occursin("Foundation", string(row.ParameterValue))
            params[row.ParameterName] = string(row.ParameterValue)  # Milestone names
        else
            params[row.ParameterName] = parse(Float64, string(row.ParameterValue))
        end
    end
    return params
end

end # module LoadFactors