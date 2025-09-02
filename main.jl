include("load_factors.jl")
include("stochastic_model.jl")
include("presentation_output.jl")

using .LoadFactors
using .StochasticModel
using .PresentationOutput

function run_analysis()
    println("🚀 Running NLU Portfolio Analysis...")

    # Use the correct function names that actually exist:
    initial_tasks = LoadFactors.load_project_tasks()
    plan = LoadFactors.load_resource_plan()  # Changed from create_resource_plan to load_resource_plan
    hours = StochasticModel.calculate_resource_hours(plan)
    milestones = StochasticModel.calculate_milestones(initial_tasks, hours, plan.months)

    # Run stochastic models
    results = StochasticModel.run_stochastic_analysis()

    # Extract the forecast data from the results struct
    nebula_f = results.nebula_forecast
    disclosure_f = results.disclosure_forecast
    lingua_f = results.lingua_forecast
    prob_params = results.prob_params

    # Generate spreadsheet output
    PresentationOutput.generate_spreadsheet_output(plan, milestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)

    # Generate the three markdown files
    PresentationOutput.generate_executive_summary_file(plan, milestones, nebula_f, disclosure_f, lingua_f)
    PresentationOutput.generate_three_year_projections_file(plan, milestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)
    PresentationOutput.generate_complete_strategic_plan_file(plan, milestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)

    return results
end

# Run the analysis
println("Available LoadFactors functions: ", names(LoadFactors))
println("Starting NLU Portfolio Analysis...")
results = run_analysis()
println("✅ Analysis complete!")
println("📁 Generated files:")
println("  - NLU_Executive_Summary.md")
println("  - NLU_Three_Year_Projections.md")
println("  - NLU_Strategic_Plan_Complete.md")










