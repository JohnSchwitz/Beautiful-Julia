module Visualizations

using StatsPlots, Random, Distributions
using ..Formatting

export generate_distribution_plots, generate_revenue_variability_plot

function generate_distribution_plots(params::Dict{String,Dict{String,Float64}})
    Random.seed!(42)
    nebula_p = params["Nebula-NLU"]

    poisson_customers = Poisson(nebula_p["lambda_dec_2025"])
    beta_purchase = Beta(nebula_p["alpha_purchase"], nebula_p["beta_purchase"])
    beta_churn = Beta(nebula_p["alpha_churn"], nebula_p["beta_churn"])

    customer_draws = [rand(poisson_customers) for _ in 1:10]
    purchase_draws = [rand(beta_purchase) for _ in 1:10]
    churn_draws = [rand(beta_churn) for _ in 1:10]

    lambda_val = round(Int, poisson_customers.λ)
    p1 = plot(poisson_customers, max(0, lambda_val - 40):(lambda_val+40),
        title="Customer Acquisition\nPoisson(λ=$(lambda_val))",
        xlabel="New Customers", ylabel="Probability", lw=3, legend=false)
    scatter!(p1, customer_draws, [pdf(poisson_customers, x) for x in customer_draws], ms=5, color=:red)

    p2 = plot(beta_purchase, 0:0.01:1,
        title="Purchase Rate\nBeta(α=$(beta_purchase.α), β=$(beta_purchase.β))",
        xlabel="Purchase Rate", ylabel="Density", lw=3, color=:green, legend=false)
    scatter!(p2, purchase_draws, [pdf(beta_purchase, x) for x in purchase_draws], ms=5, color=:red)

    p3 = plot(beta_churn, 0:0.01:1,
        title="Annual Churn Rate\nBeta(α=$(beta_churn.α), β=$(beta_churn.β))",
        xlabel="Annual Churn Rate", ylabel="Density", lw=3, color=:purple, legend=false)
    scatter!(p3, churn_draws, [pdf(beta_churn, x) for x in churn_draws], ms=5, color=:red)

    display(plot(p1, p2, p3, layout=(1, 3), size=(1200, 350),
        plot_title="Key Revenue Driver Distributions (Nebula-NLU)"))
end

function generate_revenue_variability_plot(nebula_f, disclosure_f, lingua_f, params)
    Random.seed!(123)
    n_scenarios = 10
    nebula_p = params["Nebula-NLU"]
    disclosure_p = params["Disclosure-NLU"]
    lingua_p = params["Lingua-NLU"]

    final_nebula_customers = nebula_f[end].total_customers
    final_disclosure_clients = disclosure_f[end]
    final_lingua_users = round(Int, lingua_f[end].active_pairs / 0.67)

    scenarios = []
    for i in 1:n_scenarios
        nebula_revenue = final_nebula_customers * rand(Beta(nebula_p["alpha_purchase"], nebula_p["beta_purchase"])) * 10.0
        disclosure_revenue = (final_disclosure_clients.total_solo * 1.0 +
                              final_disclosure_clients.total_small * 3.0 +
                              final_disclosure_clients.total_medium * 10.0) * 1500.0 * (1 + 0.1 * (rand() - 0.5))
        lingua_revenue = final_lingua_users * rand(Beta(lingua_p["alpha_match_success"], lingua_p["beta_match_success"])) * 59.0
        push!(scenarios, (nebula=nebula_revenue / 1000, disclosure=disclosure_revenue / 1000, lingua=lingua_revenue / 1000))
    end

    nebula_revs = [s.nebula for s in scenarios]
    disclosure_revs = [s.disclosure for s in scenarios]
    lingua_revs = [s.lingua for s in scenarios]

    p = groupedbar([nebula_revs disclosure_revs lingua_revs],
        bar_position=:dodge,
        title="Revenue Variability - 10 Scenarios (Dec 2027)\n(Amounts in K)",
        xlabel="Scenario Number",
        ylabel="Revenue (K)",
        labels=["Nebula-NLU" "Disclosure-NLU" "Lingua-NLU"],
        size=(1000, 500), lw=0)
    display(p)
end

end # module Visualizations