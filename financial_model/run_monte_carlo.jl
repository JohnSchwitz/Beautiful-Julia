"""
run_monte_carlo.jl

Monte Carlo analysis for 2-year detailed forecast (2026-2027)
Runs 100 simulations with different random seeds
"""

using Random, Statistics, Distributions
using CSV, DataFrames, Dates

# Load modules
include("load_factors.jl")
include("stochastic_model.jl")

using .LoadFactors
using .StochasticModel

println("🎲 Monte Carlo Analysis - 2-Year Forecast (2026-2027)")
println("="^70)

# Load input data
println("📂 Loading parameters...")
cost_factors_df = LoadFactors.load_cost_factors()
salaries_df = LoadFactors.load_salaries()
headcount_df = LoadFactors.load_headcount()
model_params = LoadFactors.load_model_parameters()
prob_params = LoadFactors.load_probability_parameters()
active_months_df = LoadFactors.load_active_months()
months = String.(active_months_df.Month)

println("✅ Parameters loaded from CSV files")
println("\n⏳ Running 100 Monte Carlo simulations...")

# Store results for each simulation
all_results = []

for sim in 1:100
    Random.seed!(sim * 42)  # Different seed for each simulation

    # Run the stochastic model
    results = StochasticModel.run_stochastic_analysis(months)

    # Extract final month revenue (Dec 2027)
    nebula_final = results.nebula_forecast[end].revenue_k
    disclosure_final = results.disclosure_forecast[end].revenue_k
    lingua_final = results.lingua_forecast[end].revenue_k
    total_final = nebula_final + disclosure_final + lingua_final

    # Store results
    push!(all_results, (
        simulation=sim,
        nebula_revenue=nebula_final,
        disclosure_revenue=disclosure_final,
        lingua_revenue=lingua_final,
        total_revenue=total_final,
        nebula_customers=results.nebula_forecast[end].total_customers,
        disclosure_clients=results.disclosure_forecast[end].total_clients,
        lingua_pairs=results.lingua_forecast[end].active_pairs
    ))

    if sim % 10 == 0
        println("  ✓ Completed $sim/100 simulations...")
    end
end

# Convert to DataFrame for analysis
results_df = DataFrame(all_results)

# Calculate statistics
println("\n" * "="^70)
println("📊 MONTE CARLO RESULTS (100 Simulations)")
println("="^70)

println("\n💰 December 2027 Monthly Revenue Statistics (K):")
println("  Platform          Mean      Std Dev    Min       Max       90% CI")
println("  " * "-"^68)

for (platform, col) in [("Nebula-NLU", :nebula_revenue),
    ("Disclosure-NLU", :disclosure_revenue),
    ("Lingua-NLU", :lingua_revenue),
    ("TOTAL", :total_revenue)]

    data = results_df[!, col]
    μ = mean(data)
    σ = std(data)
    p5 = quantile(data, 0.05)
    p95 = quantile(data, 0.95)
    min_val = minimum(data)
    max_val = maximum(data)

    println("  $(rpad(platform, 18)) $(rpad(round(μ, digits=0), 10)) $(rpad(round(σ, digits=0), 11)) $(rpad(round(min_val, digits=0), 10)) $(rpad(round(max_val, digits=0), 10)) \$$(round(p5, digits=0))K - \$$(round(p95, digits=0))K")
end

println("\n📈 Customer/Client Metrics (Dec 2027):")
println("  Metric                    Mean      Std Dev    Min       Max")
println("  " * "-"^68)

for (label, col) in [("Nebula Customers", :nebula_customers),
    ("Disclosure Clients", :disclosure_clients),
    ("Lingua Pairs", :lingua_pairs)]

    data = results_df[!, col]
    μ = mean(data)
    σ = std(data)
    min_val = minimum(data)
    max_val = maximum(data)

    println("  $(rpad(label, 26)) $(rpad(round(Int, μ), 10)) $(rpad(round(Int, σ), 11)) $(rpad(round(Int, min_val), 10)) $(round(Int, max_val))")
end

# Risk analysis
total_revenue = results_df.total_revenue
mean_revenue = mean(total_revenue)
downside_risk = sum(total_revenue .< (mean_revenue * 0.8)) / length(total_revenue) * 100
upside_potential = sum(total_revenue .> (mean_revenue * 1.2)) / length(total_revenue) * 100

println("\n🎯 Risk Analysis:")
println("  Probability of >20% downside: $(round(downside_risk, digits=1))%")
println("  Probability of >20% upside:   $(round(upside_potential, digits=1))%")

# Calculate annual ARR projections
mean_arr_2027 = mean_revenue * 12
conservative_valuation = mean_arr_2027 * 10
optimistic_valuation = mean_arr_2027 * 15

println("\n💼 Valuation Implications (Based on Mean):")
println("  Mean Dec 2027 Monthly Revenue: \$$(round(mean_revenue, digits=0))K")
println("  Implied ARR:                   \$$(round(mean_arr_2027/1000, digits=1))M")
println("  Conservative Valuation (10x):  \$$(round(conservative_valuation/1000, digits=1))M")
println("  Optimistic Valuation (15x):    \$$(round(optimistic_valuation/1000, digits=1))M")

# Save results to CSV
CSV.write("output/monte_carlo_results.csv", results_df)
println("\n💾 Detailed results saved to: output/monte_carlo_results.csv")

# Generate markdown report
open("output/monte_carlo_report.md", "w") do io
    write(
        io,
        """
# Monte Carlo Analysis Report
**2-Year Forecast (2026-2027) - 100 Simulations**

## Summary Statistics

### December 2027 Monthly Revenue (K)

| Platform | Mean | Std Dev | Min | Max | 90% Confidence Interval |
|----------|------|---------|-----|-----|-------------------------|
"""
    )

    for (platform, col) in [("Nebula-NLU", :nebula_revenue),
        ("Disclosure-NLU", :disclosure_revenue),
        ("Lingua-NLU", :lingua_revenue),
        ("**TOTAL**", :total_revenue)]

        data = results_df[!, col]
        μ = round(mean(data), digits=0)
        σ = round(std(data), digits=0)
        min_val = round(minimum(data), digits=0)
        max_val = round(maximum(data), digits=0)
        p5 = round(quantile(data, 0.05), digits=0)
        p95 = round(quantile(data, 0.95), digits=0)

        # Use string interpolation without dollar signs, then add them back
        write(io, "| $platform | \$$(μ)K | \$$(σ)K | \$$(min_val)K | \$$(max_val)K | \$$(p5)K - \$$(p95)K |\n")
    end

    write(
        io,
        """

## Risk Analysis

- **Downside Risk (>20% below mean):** $(round(downside_risk, digits=1))%
- **Upside Potential (>20% above mean):** $(round(upside_potential, digits=1))%

## Valuation Implications

- **Mean Dec 2027 Monthly Revenue:** \$$(round(mean_revenue, digits=0))K
- **Implied ARR:** \$$(round(mean_arr_2027/1000, digits=1))M
- **Conservative Valuation (10x ARR):** \$$(round(conservative_valuation/1000, digits=1))M
- **Optimistic Valuation (15x ARR):** \$$(round(optimistic_valuation/1000, digits=1))M

---

*Analysis completed: $(Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))*  
*All parameters loaded from `data/` CSV files*  
*100 simulations with independent random seeds*
"""
    )
end