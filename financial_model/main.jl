using CSV
using DataFrames
using Dates

# Load all modules
include("load_factors.jl")
include("stochastic_model.jl")
include("presentation/formatting.jl")
include("presentation/financial_statements.jl")
include("presentation/report_generators.jl")

using .LoadFactors
using .StochasticModel
using .Formatting
using .FinancialStatements
using .ReportGenerators

function main()
    println("Starting financial model simulation...")

    # Load input data
    println("Loading input data from CSV files...")
    cost_factors_df = LoadFactors.load_cost_factors()
    salaries_df = LoadFactors.load_salaries()
    headcount_df = LoadFactors.load_headcount()

    println("✅ Input data loaded.")

    # Load active months for forecasting
    println("Loading active months from data/active_months.csv...")
    active_months_df = LoadFactors.load_active_months()
    months = active_months_df.Month

    # Run deterministic analysis only
    println("Running deterministic forecast...")
    results = StochasticModel.run_stochastic_analysis(months)
    println("✅ Deterministic forecast complete.")

    # Extract forecasts from results
    nebula_f = results.nebula_forecast
    disclosure_f = results.disclosure_forecast
    lingua_f = results.lingua_forecast

    # Generate output reports (deterministic only)
    println("Generating output reports...")

    ReportGenerators.generate_complete_strategic_plan_file(
        months,
        nebula_f,
        disclosure_f,
        lingua_f,
        cost_factors_df,
        salaries_df,
        headcount_df
    )

    println("✅ All reports generated successfully!")
    println("\nOutput files:")
    println("  - NLU_Strategic_Plan_Complete.md")
end

# Run the main function
main()