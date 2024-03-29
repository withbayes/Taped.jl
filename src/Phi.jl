module Phi

const CC = Core.Compiler

using
    BenchmarkTools,
    DiffRules,
    ExprTools,
    Graphs,
    InteractiveUtils,
    LinearAlgebra,
    Random,
    Setfield

import ChainRulesCore

using Base:
    IEEEFloat, unsafe_convert, unsafe_pointer_to_objref, pointer_from_objref, arrayref,
    arrayset
using Base.Experimental: @opaque
using Base.Iterators: product
using Core:
    Intrinsics, bitcast, SimpleVector, svec, ReturnNode, GotoNode, GotoIfNot, PhiNode,
    PiNode, SSAValue, Argument, OpaqueClosure
using Core.Compiler: IRCode, NewInstruction
using Core.Intrinsics: pointerref, pointerset
using LinearAlgebra.BLAS: @blasfunc, BlasInt, trsm!
using LinearAlgebra.LAPACK: getrf!, getrs!, getri!, trtrs!, potrf!, potrs!

# Needs to be defined before various other things.
function _foreigncall_ end

include("utils.jl")
include("tangents.jl")
include("codual.jl")
include("stack.jl")

include(joinpath("interpreter", "contexts.jl"))
include(joinpath("interpreter", "abstract_interpretation.jl"))
include(joinpath("interpreter", "bbcode.jl"))
include(joinpath("interpreter", "ir_utils.jl"))
include(joinpath("interpreter", "ir_normalisation.jl"))
include(joinpath("interpreter", "registers.jl"))
include(joinpath("interpreter", "interpreted_function.jl"))
include(joinpath("interpreter", "reverse_mode_ad.jl"))
include(joinpath("interpreter", "s2s_reverse_mode_ad.jl"))

include("test_utils.jl")

include(joinpath("rrules", "avoiding_non_differentiable_code.jl"))
include(joinpath("rrules", "blas.jl"))
include(joinpath("rrules", "builtins.jl"))
include(joinpath("rrules", "foreigncall.jl"))
include(joinpath("rrules", "iddict.jl"))
include(joinpath("rrules", "lapack.jl"))
include(joinpath("rrules", "low_level_maths.jl"))
include(joinpath("rrules", "misc.jl"))
include(joinpath("rrules", "new.jl"))

include("chain_rules_macro.jl")
include("interface.jl")

export
    primal,
    tangent,
    randn_tangent,
    increment!!,
    NoTangent,
    Tangent,
    MutableTangent,
    PossiblyUninitTangent,
    set_to_zero!!,
    tangent_type,
    zero_tangent,
    _scale,
    _add_to_primal,
    _diff,
    _dot,
    zero_codual,
    codual_type,
    rrule!!,
    build_rrule,
    value_and_gradient!!,
    value_and_pullback!!

end
