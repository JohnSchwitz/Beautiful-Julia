using CSV
using DataFrames
using Dates

# Load all modules
include("load_factors.jl")
include("stochastic_model.jl")
include("long_term_projections.jl")
include("presentation/formatting.jl")
include("presentation/financial_statements.jl")
include("presentation/report_generators.jl")

using .LoadFactors
using .StochasticModel
using .LongTermProjections
using .Formatting
using .FinancialStatements
using .ReportGenerators

function main()
    println("Starting financial model simulation (2026-2030)...")

    # Load input data
    println("Loading input data from CSV files...")
    cost_factors_df = LoadFactors.load_cost_factors()
    salaries_df = LoadFactors.load_salaries()
    headcount_df = LoadFactors.load_headcount()
    model_params = LoadFactors.load_model_parameters()
    prob_params = LoadFactors.load_probability_parameters()
    active_months_df = LoadFactors.load_active_months()
    months = String.(active_months_df.Month)

    println("✅ Input data loaded.")

    # ========================================================================
    # YEARS 1-2: DETAILED FORECAST
    # ========================================================================
    println("\n" * "="^80)
    println("YEARS 1-2 (2026-2027): Detailed Monthly Forecast")
    println("="^80)

    results = StochasticModel.run_stochastic_analysis(months)
    println("✅ Detailed forecast complete.")

    # Extract forecasts (FIX: use consistent variable names)
    nebula_forecast = results.nebula_forecast      # ✅ Changed from nebula_f
    disclosure_forecast = results.disclosure_forecast  # ✅ Changed from disclosure_f
    lingua_forecast = results.lingua_forecast      # ✅ Changed from lingua_f

    # ========================================================================
    # EXTRACT 2027 BASELINE
    # ========================================================================
    println("\n" * "="^80)
    println("EXTRACTING 2027 BASELINE for Long-Term Projection")
    println("="^80)

    baseline_2027 = LongTermProjections.extract_2027_baseline(
        nebula_forecast,      # ✅ Using consistent name
        disclosure_forecast,  # ✅ Using consistent name
        lingua_forecast       # ✅ Using consistent name
    )

    # Auto-update assumptions with actual baseline
    println("\n📝 Auto-updating assumptions_2028.csv with 2027 baseline...")
    LongTermProjections.update_assumptions_with_baseline(
        baseline_2027,
        "data_longterm/assumptions_2028.csv"
    )

    # ========================================================================
    # YEARS 3-5: STRATEGIC FORECAST
    # ========================================================================
    println("\n" * "="^80)
    println("YEARS 3-5 (2028-2030): Strategic Annual Forecast")
    println("="^80)

    longterm_forecasts = LongTermProjections.project_years_3_to_5(  # ✅ Single declaration
        baseline_2027,
        "data_longterm"
    )

    # ========================================================================
    # GENERATE REPORTS
    # ========================================================================
    println("\n" * "="^80)
    println("GENERATING REPORTS")
    println("="^80)

    ReportGenerators.generate_complete_strategic_plan_file(
        months,
        nebula_forecast,      # ✅ Consistent naming
        disclosure_forecast,  # ✅ Consistent naming
        lingua_forecast,      # ✅ Consistent naming
        longterm_forecasts,   # ✅ Correct variable name
        cost_factors_df,
        salaries_df,
        headcount_df,
        model_params,
        prob_params
    )

    println("\n✅ All reports generated successfully!")
    println("\nOutput files:")
    println("  - NLU_Strategic_Plan_Complete.md (5-year strategic plan: 2026-2030)")
end

# Run the main function
main()