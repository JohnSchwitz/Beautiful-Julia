module PresentationOutput

using DataFrames, StatsPlots, Random, Distributions, Printf, Dates

# Get LoadFactors from parent
import ..LoadFactors

# Import sub-modules
include("formatting.jl")
include("visualizations.jl")
include("financial_statements.jl")
include("report_generators.jl")

using .Formatting
using .Visualizations
using .FinancialStatements
using .ReportGenerators

# Re-export key functions
export format_number, format_currency, add_commas
export generate_distribution_plots, generate_revenue_variability_plot
export generate_executive_summary_file, generate_three_year_projections_file,
    generate_complete_strategic_plan_file

function generate_spreadsheet_output(plan, milestones, initial_tasks, hours, nebula_f, disclosure_f, lingua_f, prob_params)
    pnl_data = FinancialStatements.generate_monthly_pnl_table(plan, nebula_f, disclosure_f, lingua_f)
    println("✅ Generated financial data tables (embedded in reports)")
end

export generate_spreadsheet_output

end # module PresentationOutput