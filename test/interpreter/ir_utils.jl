module IRUtilsGlobalRefs
    __x_1 = 5.0
    const __x_2 = 5.0
    __x_3::Float64 = 5.0
    const __x_4::Float64 = 5.0
end

@testset "ir_utils" begin
    @testset "ircode $(typeof(fargs))" for fargs in Any[
        (sin, 5.0), (cos, 1.0),
    ]
        # Construct a vector of instructions from known function.
        f, args... = fargs
        insts = only(code_typed(f, _typeof(args)))[1].code
    
        # Use Phi.ircode to build an `IRCode`.
        argtypes = Any[map(_typeof, fargs)...]
        ir = Phi.ircode(insts, argtypes)

        # Check the validity of the `IRCode`, and that an OpaqueClosure constructed using it
        # gives the same answer as the original function.
        @test length(ir.stmts.inst) == length(insts)
        @test Core.OpaqueClosure(ir; do_compile=true)(args...) == f(args...)
    end
    @testset "infer_ir!" begin

        # Generate IR without any types. 
        ir = Phi.ircode(
            Any[
                Expr(:call, GlobalRef(Base, :sin), Argument(2)),
                Expr(:call, cos, SSAValue(1)),
                ReturnNode(SSAValue(2)),
            ],
            Any[Tuple{}, Float64],
        )

        # Run inference and check that the types are as expected.
        ir = Phi.infer_ir!(ir)
        @test ir.stmts.type[1] == Float64
        @test ir.stmts.type[2] == Float64

        # Check that the ir is runable.
        @test Core.OpaqueClosure(ir)(5.0) == cos(sin(5.0))
    end
    @testset "replace_all_uses_with!" begin

        # `replace_all_uses_with!` is just a lightweight wrapper around `replace_uses_with`,
        # so we just test that carefully.
        @testset "replace_uses_with $val" for (val, target) in Any[
            (5.0, 5.0),
            (5, 5),
            (Expr(:call, sin, SSAValue(1)), Expr(:call, sin, SSAValue(2))),
            (Expr(:call, sin, SSAValue(3)), Expr(:call, sin, SSAValue(3))),
            (GotoNode(1), GotoNode(1)),
            (GotoIfNot(false, 5), GotoIfNot(false, 5)),
            (GotoIfNot(SSAValue(1), 3), GotoIfNot(SSAValue(2), 3)),
            (GotoIfNot(SSAValue(3), 3), GotoIfNot(SSAValue(3), 3)),
            (
                PhiNode(Int32[1, 2, 3], Any[5, SSAValue(1), SSAValue(3)]),
                PhiNode(Int32[1, 2, 3], Any[5, SSAValue(2), SSAValue(3)]),
            ),
            (PiNode(SSAValue(1), Float64), PiNode(SSAValue(2), Float64)),
            (PiNode(SSAValue(3), Float64), PiNode(SSAValue(3), Float64)),
            (PiNode(Argument(1), Float64), PiNode(Argument(1), Float64)),
            (QuoteNode(:a_quote), QuoteNode(:a_quote)),
            (ReturnNode(5), ReturnNode(5)),
            (ReturnNode(SSAValue(1)), ReturnNode(SSAValue(2))),
            (ReturnNode(SSAValue(3)), ReturnNode(SSAValue(3))),
            (ReturnNode(), ReturnNode()),
        ]
            @test Phi.replace_uses_with(val, SSAValue(1), SSAValue(2)) == target
        end
        @testset "PhiNode with undefined" begin
            vals_with_undef_1 = Vector{Any}(undef, 2)
            vals_with_undef_1[2] = SSAValue(1)
            val = PhiNode(Int32[1, 2], vals_with_undef_1)
            result = Phi.replace_uses_with(val, SSAValue(1), SSAValue(2))
            @test result.values[2] == SSAValue(2)
            @test !isassigned(result.values, 1)
        end
    end
    @testset "globalref_type" begin
        @test Phi.globalref_type(GlobalRef(IRUtilsGlobalRefs, :__x_1)) == Any
        @test Phi.globalref_type(GlobalRef(IRUtilsGlobalRefs, :__x_2)) == Float64
        @test Phi.globalref_type(GlobalRef(IRUtilsGlobalRefs, :__x_3)) == Float64
        @test Phi.globalref_type(GlobalRef(IRUtilsGlobalRefs, :__x_4)) == Float64
    end
    @testset "unhandled_feature" begin
        @test_throws Phi.UnhandledLanguageFeatureException Phi.unhandled_feature("foo")
    end
    @testset "inc_args" begin
        @test Phi.inc_args(Expr(:call, sin, Argument(4))) == Expr(:call, sin, Argument(5))
        @test Phi.inc_args(ReturnNode(Argument(2))) == ReturnNode(Argument(3))
        id = ID()
        @test Phi.inc_args(IDGotoIfNot(Argument(1), id)) == IDGotoIfNot(Argument(2), id)
        @test Phi.inc_args(IDGotoNode(id)) == IDGotoNode(id)
    end
end
