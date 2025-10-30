include("load_factors.jl")
include("stochastic_model.jl")
include("presentation/presentation_output.jl")  # Updated path

using .LoadFactors
using .StochasticModel
using .PresentationOutput

function run_analysis()
    println("🚀 Running NLU Portfolio Analysis...")

    initial_tasks = LoadFactors.load_project_tasks()
    plan = LoadFactors.load_resource_plan()
    hours = StochasticModel.calculate_resource_hours(plan)
    milestones = StochasticModel.calculate_milestones(initial_tasks, hours, plan.months)

    # Run stochastic models
    results = StochasticModel.run_stochastic_analysis()

    # Extract forecast data
    nebula_f = results.nebula_forecast
    disclosure_f = results.disclosure_forecast
    lingua_f = results.lingua_forecast
    prob_params = results.prob_params

    # Generate outputs
    PresentationOutput.generate_spreadsheet_output(plan, milestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)

    # Generate markdown reports
    PresentationOutput.generate_executive_summary_file(plan, milestones, nebula_f, disclosure_f, lingua_f)
    PresentationOutput.generate_three_year_projections_file(plan, milestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)
    PresentationOutput.generate_complete_strategic_plan_file(plan, milestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)
    PresentationOutput.generate_founder_capitalization_file(plan, milestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)  # ADD THIS LINEestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)

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
println("  - NLU_Strategic_Plan_Complete.md (13 sections - for investors/employees)")
println("  - NLU_Founder_Capitalization.md (CONFIDENTIAL - founder only)")









