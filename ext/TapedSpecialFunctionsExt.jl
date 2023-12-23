module TapedSpecialFunctionsExt

    using ChainRulesCore, SpecialFunctions, Taped, Umlaut

    import Taped: CoDual, rrule!!, isprimitive, RMC, @is_primitive, DefaultCtx

    isprimitive(::RMC, ::typeof(erfc), ::Float64) = true
    @is_primitive DefaultCtx Tuple{typeof(erfc), Float64}
    function rrule!!(::CoDual{typeof(erfc)}, x::CoDual{Float64})
        y, erfc_pb = rrule(erfc, primal(x))
        function erfc_pb!!(dy, df, dx)
            _, dx_inc = erfc_pb(dy)
            return df, increment!!(dx, dx_inc)
        end
        return zero_codual(y), erfc_pb!!
    end
end
