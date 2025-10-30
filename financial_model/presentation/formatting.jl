module Formatting

export format_number, format_currency, add_commas

function format_number(value::Real; use_k_m::Bool=true)
    abs_val = abs(value)
    sign_str = value < 0 ? "-" : ""

    if !use_k_m || abs_val < 1_000
        if abs_val >= 1_000
            num_str = string(round(Int, abs(value)))
            formatted = reverse(join([reverse(num_str)[i:min(i + 2, end)] for i in 1:3:length(num_str)], ","))
            return sign_str * formatted
        else
            return string(round(Int, value))
        end
    end

    if abs_val >= 1_000_000
        formatted = round(abs(value) / 1_000_000, digits=1)
        return sign_str * string(formatted) * "M"
    elseif abs_val >= 1_000
        formatted = round(abs(value) / 1_000, digits=1)
        return sign_str * string(formatted) * "K"
    else
        return string(round(Int, value))
    end
end

function format_currency(value::Real; use_k_m::Bool=true)
    if value < 0
        return "-\$" * format_number(abs(value), use_k_m=use_k_m)
    else
        return "\$" * format_number(value, use_k_m=use_k_m)
    end
end

function add_commas(value::Int)
    num_str = string(abs(value))
    if length(num_str) <= 3
        return value < 0 ? "-" * num_str : num_str
    end
    formatted = reverse(join([reverse(num_str)[i:min(i + 2, end)] for i in 1:3:length(num_str)], ","))
    return value < 0 ? "-" * formatted : formatted
end

end # module Formatting