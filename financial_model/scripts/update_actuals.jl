using CSV, DataFrames, Dates

"""
Monthly workflow to update actuals and compare to forecast
Usage: julia scripts/update_actuals.jl
"""

function prompt_nebula_actuals(month::String)
    println("\n📊 NEBULA-NLU ACTUALS FOR $month")
    println("="^50)

    print("New Free Trials: ")
    trials = parse(Int, readline())

    print("Free→Monthly Conversions: ")
    monthly_conv = parse(Float64, readline())

    print("Free→Annual Conversions: ")
    annual_conv = parse(Float64, readline())

    print("Total Monthly Subscribers (end of month): ")
    monthly_subs = parse(Int, readline())

    print("Total Annual Subscribers (end of month): ")
    annual_subs = parse(Int, readline())

    print("Monthly Revenue (actual $): ")
    revenue = parse(Float64, readline())

    print("Notes (optional): ")
    notes = readline()

    return (
        Month=month,
        NewTrials=trials,
        FreeToMonthlyConv=monthly_conv,
        FreeToAnnualConv=annual_conv,
        MonthlySubscribers=monthly_subs,
        AnnualSubscribers=annual_subs,
        Revenue=revenue,
        Notes=notes
    )
end

function update_actuals_file(product::String, new_data::NamedTuple)
    filepath = "data/actuals/$(product)_actuals.csv"

    # Load existing or create new
    if isfile(filepath)
        df = CSV.read(filepath, DataFrame)
    else
        df = DataFrame()
    end

    # Append new data
    push!(df, new_data)

    # Save
    CSV.write(filepath, df)
    println("✅ Updated $filepath")
end

function main()
    println("🎯 NLU PORTFOLIO ACTUALS TRACKER")
    println("="^50)

    print("Enter month (e.g., 'Jan 2026'): ")
    month = readline()

    print("Which product? (nebula/disclosure/lingua): ")
    product = readline()

    if product == "nebula"
        data = prompt_nebula_actuals(month)
        update_actuals_file("nebula", data)
    else
        println("⚠️ Product-specific prompts not yet implemented for $product")
    end

    println("\n🎉 Actuals updated! Run variance analysis with:")
    println("   julia analysis/run_variance_analysis.jl")
end

main()