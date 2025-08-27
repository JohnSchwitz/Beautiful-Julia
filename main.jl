# main.jl
using Random
include("load_factors.jl")
include("stochastic_model.jl")
include("presentation_output.jl")

using .LoadFactors
using .StochasticModel
using .PresentationOutput

function run_analysis()
    Random.seed!(42)

    # File paths
    config_file = "config.csv"
    resource_file = "resource_plan.csv"
    tasks_file = "project_tasks.csv"
    prob_params_file = "probability_parameters.csv"

    # Load data
    config = load_configuration(config_file)
    plan = load_resource_plan(resource_file, config)
    initial_tasks = load_tasks(tasks_file)
    prob_params = load_probability_parameters(prob_params_file)

    # Calculate resources and milestones
    hours = calculate_resource_hours(plan)
    milestone_tasks = prepare_tasks_for_milestones(initial_tasks, hours)
    milestones = calculate_milestones(milestone_tasks, hours, plan.months)

    # Generate revenue forecasts
    nebula_forecast = model_nebula_revenue(plan, prob_params["Nebula-NLU"])
    disclosure_forecast = model_disclosure_revenue(plan, milestones, prob_params["Disclosure-NLU"])
    lingua_forecast = model_lingua_revenue(plan, milestones, prob_params["Lingua-NLU"])

    # Generate output
    generate_spreadsheet_output(plan, milestones, initial_tasks, hours,
        nebula_forecast, disclosure_forecast, lingua_forecast, prob_params)

    return (plan=plan, milestones=milestones, tasks=milestone_tasks, hours=hours,
        nebula_forecast=nebula_forecast, disclosure_forecast=disclosure_forecast,
        lingua_forecast=lingua_forecast, prob_params=prob_params)
end

# Main execution
println("🚀 NLU STRATEGIC ANALYSIS WITH ENHANCED NEBULA MODEL")
println("="^55)

results = run_analysis()

println("\n\n🎨 VISUALIZATION FUNCTIONS")
println("="^30)
println("To generate distribution plots, run:")
println("generate_distribution_plots(results.prob_params)")
println("\nTo generate revenue variability plots, run:")
println("generate_revenue_variability_plot(results.nebula_forecast, results.disclosure_forecast, results.lingua_forecast, results.prob_params)")