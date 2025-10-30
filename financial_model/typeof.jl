# Include the load_factors module first
include("load_factors.jl")
using .LoadFactors

# Now load the resource plan
plan = LoadFactors.load_resource_plan()

# Display the information
println("Type of plan object: ", typeof(plan))
println("\nProperty names: ", propertynames(plan))
println("\nFirst 5 experienced_devs: ", plan.experienced_devs[1:5])
println("First 5 months: ", plan.months[1:5])

println("Type: ", typeof(plan))
println("Fields: ", fieldnames(typeof(plan)))
println("Length of months: ", length(plan.months))
println("First 3 months: ", plan.months[1:3])
println("First 3 exp_devs: ", plan.experienced_devs[1:3])
println("Access test: plan.experienced_devs[1] = ", plan.experienced_devs[1])

println("===== DEBUG OUTPUT =====")
println("Type: ", typeof(plan))
println("Number of months: ", length(plan.months))
println("\nFirst 5 months:")
for i in 1:5
    println("  Month ", i, ": ", plan.months[i],
        " | Exp Dev: ", plan.experienced_devs[i],
        " | Intern Dev: ", plan.intern_devs[i],
        " | Exp Mkt: ", plan.experienced_marketers[i],
        " | Intern Mkt: ", plan.intern_marketers[i])
end

println("plan.months length: ", length(plan.months))  # Should be 26
println("nebula_f length: ", length(nebula_f))        # Should be 26
println("disclosure_f length: ", length(disclosure_f))  # Should be 26
println("lingua_f length: ", length(lingua_f))          # Should be 26

# Run this and show me output:
println("Lingua forecast fields: ", fieldnames(typeof(lingua_f[1])))
println("Nov 2027 Lingua data: ", lingua_f[end-1])  # Assuming Nov is 2nd to last
println("Oct 2027 Lingua data: ", lingua_f[end-2])