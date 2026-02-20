using CSV, DataFrames, Dates, Statistics

module ActualsTracker

export load_actuals, compare_forecast_vs_actuals, generate_variance_report

function load_actuals(product::String)
    """Load actual performance data for a specific product"""
    filepath = "data/actuals/$(product)_actuals.csv"
    if !isfile(filepath)
        @warn "No actuals file found for $product at $filepath"
        return nothing
    end
    return CSV.read(filepath, DataFrame)
end

function compare_forecast_vs_actuals(forecast_df::DataFrame, actuals_df::DataFrame, metric::Symbol)
    """
    Compare forecasted vs actual values for a given metric
    Returns DataFrame with: Month, Forecast, Actual, Variance, Variance%
    """
    comparison = DataFrame(
        Month=String[],
        Forecast=Float64[],
        Actual=Float64[],
        Variance=Float64[],
        VariancePct=Float64[]
    )

    for row in eachrow(actuals_df)
        month = row.Month
        actual_value = ismissing(row[metric]) ? missing : row[metric]

        # Skip if no actual data yet
        if ismissing(actual_value)
            continue
        end

        # Find matching forecast
        forecast_row = filter(r -> r.Month == month, forecast_df)
        if nrow(forecast_row) == 0
            @warn "No forecast found for $month"
            continue
        end

        forecast_value = forecast_row[1, metric]
        variance = actual_value - forecast_value
        variance_pct = (variance / forecast_value) * 100

        push!(comparison, (month, forecast_value, actual_value, variance, variance_pct))
    end

    return comparison
end

function generate_variance_report(product::String, forecast_data, actuals_df::DataFrame)
    """Generate a comprehensive variance analysis report"""

    println("\n" * "="^60)
    println("VARIANCE ANALYSIS: $product")
    println("="^60)

    if product == "nebula"
        metrics = [:Revenue, :NewTrials, :MonthlySubscribers, :AnnualSubscribers]

        for metric in metrics
            if metric in names(actuals_df)
                println("\n📊 $metric Analysis:")

                # Calculate actual values
                actual_values = filter(!ismissing, actuals_df[!, metric])
                if length(actual_values) > 0
                    println("  • Latest Actual: $(round(actual_values[end], digits=2))")
                    println("  • Average: $(round(mean(actual_values), digits=2))")
                    println("  • Trend: ", length(actual_values) > 1 ?
                                           (actual_values[end] > actual_values[1] ? "📈 Growing" : "📉 Declining") :
                                           "Not enough data")
                else
                    println("  • No actual data available yet")
                end
            end
        end

        # Conversion rate analysis
        if :FreeToMonthlyConv in names(actuals_df) && :FreeToAnnualConv in names(actuals_df)
            monthly_conv = filter(!ismissing, actuals_df.FreeToMonthlyConv)
            annual_conv = filter(!ismissing, actuals_df.FreeToAnnualConv)

            if length(monthly_conv) > 0
                println("\n🎯 Conversion Rates:")
                println("  • Free→Monthly: $(round(mean(monthly_conv)*100, digits=1))%")
                println("  • Free→Annual: $(round(mean(annual_conv)*100, digits=1))%")
                println("  • Total Conversion: $(round((mean(monthly_conv)+mean(annual_conv))*100, digits=1))%")
            end
        end

    elseif product == "disclosure"
        println("\n📊 Client Acquisition:")
        for segment in [:NewSolo, :NewSmall, :NewMedium, :NewLarge, :NewBigLaw]
            if segment in names(actuals_df)
                values = filter(!ismissing, actuals_df[!, segment])
                if length(values) > 0
                    println("  • $segment: $(round(mean(values), digits=1)) avg/month")
                end
            end
        end

    elseif product == "lingua"
        println("\n📊 User Engagement:")
        if :MatchSuccessRate in names(actuals_df)
            rates = filter(!ismissing, actuals_df.MatchSuccessRate)
            if length(rates) > 0
                println("  • Match Success Rate: $(round(mean(rates)*100, digits=1))%")
            end
        end
    end

    println("\n" * "="^60 * "\n")
end

function calculate_forecast_accuracy(actuals_df::DataFrame, metric::Symbol, forecast_value::Float64)
    """Calculate MAPE (Mean Absolute Percentage Error) for forecast accuracy"""
    actual_values = filter(!ismissing, actuals_df[!, metric])

    if length(actual_values) == 0
        return nothing
    end

    errors = abs.((actual_values .- forecast_value) ./ actual_values) * 100
    mape = mean(errors)

    return (
        MAPE=mape,
        Accuracy=100 - mape,
        Status=mape < 10 ? "✅ Excellent" :
               mape < 20 ? "👍 Good" :
               mape < 30 ? "⚠️ Fair" : "❌ Needs Revision"
    )
end

end # module ActualsTracker