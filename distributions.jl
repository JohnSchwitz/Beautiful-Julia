using StatsPlots, Random, Distributions
using CSV, DataFrames

# Load parameters from CSV files
println("📊 Loading probability parameters from CSV...")

# Load probability parameters
prob_params = Dict{String,Dict{String,Float64}}()
prob_data = CSV.read("data/probability_parameters.csv", DataFrame)
for row in eachrow(prob_data)
    platform = row.Platform
    if !haskey(prob_params, platform)
        prob_params[platform] = Dict{String,Float64}()
    end
    prob_params[platform][row.Parameter_Name] = row.Parameter_Value
end

println("🎲 Generating probability distributions with sample draws...")

# Generate distributions for Nebula-NLU
Random.seed!(42)
nebula_p = prob_params["Nebula-NLU"]

# Create distributions using CSV parameters
poisson_customers = Poisson(nebula_p["lambda_jan_2026"])
beta_purchase = Beta(nebula_p["alpha_purchase"], nebula_p["beta_purchase"])
beta_churn = Beta(nebula_p["alpha_churn"], nebula_p["beta_churn"])

# Generate sample draws
customer_draws = [rand(poisson_customers) for _ in 1:10]
purchase_draws = [rand(beta_purchase) for _ in 1:10]
churn_draws = [rand(beta_churn) for _ in 1:10]

# Create plots
p1 = plot(poisson_customers,
    (poisson_customers.λ-40):(poisson_customers.λ+40),
    title="Customer Acquisition\nPoisson(λ=$(round(Int,poisson_customers.λ)))",
    xlabel="New Customers",
    ylabel="Probability",
    lw=3,
    legend=false,
    color=:blue)
scatter!(p1, customer_draws, [pdf(poisson_customers, x) for x in customer_draws],
    ms=6, color=:red, alpha=0.7)

p2 = plot(beta_purchase, 0:0.01:1,
    title="Purchase Rate\nBeta(α=$(beta_purchase.α), β=$(beta_purchase.β))",
    xlabel="Purchase Rate",
    ylabel="Density",
    lw=3,
    color=:green,
    legend=false)
scatter!(p2, purchase_draws, [pdf(beta_purchase, x) for x in purchase_draws],
    ms=6, color=:red, alpha=0.7)

p3 = plot(beta_churn, 0:0.01:1,
    title="Annual Churn Rate\nBeta(α=$(beta_churn.α), β=$(beta_churn.β))",
    xlabel="Annual Churn Rate",
    ylabel="Density",
    lw=3,
    color=:purple,
    legend=false)
scatter!(p3, churn_draws, [pdf(beta_churn, x) for x in churn_draws],
    ms=6, color=:red, alpha=0.7)

# Display combined plot
final_plot = plot(p1, p2, p3,
    layout=(1, 3),
    size=(1400, 400),
    plot_title="Nebula-NLU Revenue Driver Distributions (10 Sample Draws)",
    titlefont=font(14))

# Save plot to file
savefig(final_plot, "probability_distributions.png")
println("💾 Plot saved as: probability_distributions.png")

# Also display it
display(final_plot)

println("✅ Distribution plots generated!")
println("📊 Red dots show 10 random sample draws from each distribution")
println("📈 These samples represent the variability in your revenue model")
println("🔧 All parameters loaded from data/probability_parameters.csv")

# Print the parameters being used
println("\n📋 Parameters from CSV:")
println("  Customer Acquisition: Poisson(λ=$(nebula_p["lambda_jan_2026"]))")
println("  Purchase Rate: Beta(α=$(nebula_p["alpha_purchase"]), β=$(nebula_p["beta_purchase"]))")
println("  Churn Rate: Beta(α=$(nebula_p["alpha_churn"]), β=$(nebula_p["beta_churn"]))")
