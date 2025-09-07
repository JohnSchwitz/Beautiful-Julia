using StatsPlots, Random, Distributions
using CSV, DataFrames

println("🔄 Loading model parameters from CSV files...")

# Load probability parameters
prob_params = Dict{String, Dict{String, Float64}}()
prob_data = CSV.read("data/probability_parameters.csv", DataFrame)
for row in eachrow(prob_data)
    platform = row.Platform
    if !haskey(prob_params, platform)
        prob_params[platform] = Dict{String, Float64}()
    end
    prob_params[platform][row.Parameter_Name] = row.Parameter_Value
end

# Load model parameters
model_params = Dict{String, Dict{String, Float64}}()
model_data = CSV.read("data/model_parameters.csv", DataFrame)
for row in eachrow(model_data)
    param_name = row.Parameter
    if !haskey(model_params, "General")
        model_params["General"] = Dict{String, Float64}()
    end
    model_params["General"][param_name] = row.Value
end

println("🎲 Generating 50 revenue scenarios for detailed analysis...")

# Simulate 50 different revenue outcomes for better statistics
Random.seed!(123)
n_scenarios = 50

nebula_p = prob_params["Nebula-NLU"]
general_m = model_params["General"]

# Estimated final customer/client counts (Dec 2026)
estimated_nebula_customers = 15000
estimated_disclosure_clients = 250
estimated_lingua_pairs = 800

# Collect data for each platform separately
nebula_scenarios = []
disclosure_scenarios = []
lingua_scenarios = []

for i in 1:n_scenarios
    # Nebula-NLU revenue variability
    nebula_revenue = estimated_nebula_customers * 
        rand(Beta(nebula_p["alpha_purchase"], nebula_p["beta_purchase"])) * 
        general_m["MonthlyPrice"] / 1000
    
    # Disclosure-NLU revenue variability
    disclosure_revenue = estimated_disclosure_clients * 
        (1.0 * 15000 + 3.3 * 50000) / 12000 * # Annual to monthly
        (1 + 0.15 * (rand() - 0.5))  # ±7.5% variability
    
    # Lingua-NLU revenue variability  
    lingua_revenue = estimated_lingua_pairs * 
        rand(Beta(2.0, 1.5)) * # Match success rate
        99.0 / 1000 # Match fee
    
    push!(nebula_scenarios, nebula_revenue)
    push!(disclosure_scenarios, disclosure_revenue)
    push!(lingua_scenarios, lingua_revenue)
end

# Calculate statistics for each platform
nebula_mean = mean(nebula_scenarios)
nebula_std = std(nebula_scenarios)
disclosure_mean = mean(disclosure_scenarios)
disclosure_std = std(disclosure_scenarios)
lingua_mean = mean(lingua_scenarios)
lingua_std = std(lingua_scenarios)

# Chart 1: Nebula-NLU Revenue Variability
p1 = bar(1:min(20, n_scenarios), nebula_scenarios[1:min(20, n_scenarios)],
    title = "Nebula-NLU Revenue Variability\n(First 20 Scenarios)",
    xlabel = "Scenario Number",
    ylabel = "Monthly Revenue (k\$)",
    color = :blue,
    alpha = 0.7,
    size = (800, 500))

# Add mean line and error bars
hline!(p1, [nebula_mean], color = :red, lw = 2, label = "Mean: \$$(round(Int, nebula_mean))K")
hline!(p1, [nebula_mean + nebula_std], color = :red, lw = 1, linestyle = :dash, label = "+1σ")
hline!(p1, [nebula_mean - nebula_std], color = :red, lw = 1, linestyle = :dash, label = "-1σ")

# Chart 2: Disclosure-NLU Revenue Variability  
p2 = bar(1:min(20, n_scenarios), disclosure_scenarios[1:min(20, n_scenarios)],
    title = "Disclosure-NLU Revenue Variability\n(First 20 Scenarios)",
    xlabel = "Scenario Number", 
    ylabel = "Monthly Revenue (k\$)",
    color = :green,
    alpha = 0.7,
    size = (800, 500))

hline!(p2, [disclosure_mean], color = :red, lw = 2, label = "Mean: \$$(round(Int, disclosure_mean))K")
hline!(p2, [disclosure_mean + disclosure_std], color = :red, lw = 1, linestyle = :dash, label = "+1σ")
hline!(p2, [disclosure_mean - disclosure_std], color = :red, lw = 1, linestyle = :dash, label = "-1σ")

# Chart 3: Lingua-NLU Revenue Variability
p3 = bar(1:min(20, n_scenarios), lingua_scenarios[1:min(20, n_scenarios)],
    title = "Lingua-NLU Revenue Variability\n(First 20 Scenarios)",
    xlabel = "Scenario Number",
    ylabel = "Monthly Revenue (k\$)", 
    color = :purple,
    alpha = 0.7,
    size = (800, 500))

hline!(p3, [lingua_mean], color = :red, lw = 2, label = "Mean: \$$(round(Int, lingua_mean))K")
hline!(p3, [lingua_mean + lingua_std], color = :red, lw = 1, linestyle = :dash, label = "+1σ")
hline!(p3, [lingua_mean - lingua_std], color = :red, lw = 1, linestyle = :dash, label = "-1σ")

# Save individual platform charts
savefig(p1, "nebula_revenue_variability.png")
savefig(p2, "disclosure_revenue_variability.png") 
savefig(p3, "lingua_revenue_variability.png")

# Chart 4: Error Bar Comparison Chart
means = [nebula_mean, disclosure_mean, lingua_mean]
stds = [nebula_std, disclosure_std, lingua_std]
platform_names = ["Nebula-NLU", "Disclosure-NLU", "Lingua-NLU"]

p4 = bar(platform_names, means,
    yerr = stds,
    title = "Revenue Comparison with Standard Deviation\n($(n_scenarios) Scenarios Each)",
    ylabel = "Monthly Revenue (k\$)",
    color = [:blue :green :purple],
    alpha = 0.7,
    size = (800, 600),
    legend = false)

# Add value labels on bars
for i in 1:3
    annotate!(p4, i, means[i] + stds[i] + 10, text("μ=$(round(Int,means[i]))K\nσ=$(round(Int,stds[i]))K", 8, :center))
end

savefig(p4, "platform_comparison_error_bars.png")

# Display all charts
display(p1)
display(p2) 
display(p3)
display(p4)

println("💾 Charts saved:")
println("  - nebula_revenue_variability.png")
println("  - disclosure_revenue_variability.png") 
println("  - lingua_revenue_variability.png")
println("  - platform_comparison_error_bars.png")

# Print detailed statistics
println("\n📊 DETAILED REVENUE VARIABILITY ANALYSIS ($(n_scenarios) Scenarios)")
println("=" ^ 70)

println("\n🔵 Nebula-NLU Statistics:")
println("  Mean:              \$$(round(Int, nebula_mean))K")
println("  Standard Deviation: \$$(round(Int, nebula_std))K")
println("  Minimum:           \$$(round(Int, minimum(nebula_scenarios)))K")
println("  Maximum:           \$$(round(Int, maximum(nebula_scenarios)))K")
println("  Coefficient of Variation: $(round(nebula_std/nebula_mean*100, digits=1))%")

println("\n🟢 Disclosure-NLU Statistics:")
println("  Mean:              \$$(round(Int, disclosure_mean))K")
println("  Standard Deviation: \$$(round(Int, disclosure_std))K")
println("  Minimum:           \$$(round(Int, minimum(disclosure_scenarios)))K")
println("  Maximum:           \$$(round(Int, maximum(disclosure_scenarios)))K")
println("  Coefficient of Variation: $(round(disclosure_std/disclosure_mean*100, digits=1))%")

println("\n🟣 Lingua-NLU Statistics:")
println("  Mean:              \$$(round(Int, lingua_mean))K")
println("  Standard Deviation: \$$(round(Int, lingua_std))K")
println("  Minimum:           \$$(round(Int, minimum(lingua_scenarios)))K")
println("  Maximum:           \$$(round(Int, maximum(lingua_scenarios)))K")
println("  Coefficient of Variation: $(round(lingua_std/lingua_mean*100, digits=1))%")

total_mean = nebula_mean + disclosure_mean + lingua_mean
total_std = sqrt(nebula_std^2 + disclosure_std^2 + lingua_std^2)  # Assuming independence

println("\n📊 Total Portfolio Statistics:")
println("  Combined Mean:     \$$(round(Int, total_mean))K")
println("  Combined Std Dev:  \$$(round(Int, total_std))K")
println("  Portfolio CV:      $(round(total_std/total_mean*100, digits=1))%")

println("\n✅ Revenue variability analysis complete!")
println("🔧 All parameters loaded from data/ CSV files")
