# Algorithmic Differentiation

This section introduces the mathematics behind AD.
Even if you have worked with AD before, we recommend reading in order to acclimatise yourself to the perspective that Tapir.jl takes on the subject.

# Derivatives


A foundation on which all of AD is built the the derivate -- we require a fairly general definition of it, which we build up to here.

_**Scalar-to-Scalar Functions**_

Consider first ``f : \RR \to \RR``, which we require to be differentiable at ``x \in \RR``.
Its derivative at ``x`` is usually thought of as the scalar ``\alpha \in \RR`` such that
```math
\text{d}f = \alpha \, \text{d}x .
```
Loosely speaking, by this notation we mean that for arbitrary small changes ``\text{d} x`` in the input to ``f``, the change in the output ``\text{d} f`` is ``\alpha \, \text{d}x``.
We refer readers to the first few minutes of the first lecture mentioned above for a more careful explanation.

_**Vector-to-Vector Functions**_

The generalisation of this to Euclidean space should be familiar: if ``f : \RR^P \to \RR^Q`` is differentiable at a point ``x \in \RR^P``, then the derivative of ``f`` at ``x`` is given by the Jacobian matrix at ``x``, denoted ``J[x] \in \RR^{Q \times P}``, such that
```math
\text{d}f = J[x] \, \text{d}x .
```

It is possible to stop here, as all the functions we shall need to consider can in principle be written as functions on some subset ``\RR^P``.

However, when we consider differentiating computer programmes, we will have to deal with complicated nested data structures, e.g. `struct`s inside `Tuple`s inside `Vector`s etc.
While all of these data structures _can_ be mapped onto a flat vector in order to make sense of the Jacobian of a computer programme, this becomes very inconvenient very quickly.
To see the problem, consider the Julia function whose input is of type `Tuple{Tuple{Float64, Vector{Float64}}, Vector{Float64}, Float64}` and whose output is of type `Tuple{Vector{Float64}, Float64}`.
What kind of object might be use to represent the derivative of a function mapping between these two spaces?
We certainly _can_ treat these as structured "view" into a "flat" `Vector{Float64}`s, and then define a Jacobian, but actually _finding_ this mapping is a tedious exercise, even if it quite obviously exists.

In fact, a more general formulation of the derivative is used all the time in the context of AD -- the matrix calculus discussed by [giles2008extended](@cite) and [minka2000old](@cite) (to name a couple) make use of a generalised form of the derivative in order to work with functions which map to and from matrices (albeit there are slight differences in naming conventions from text to text), without needing to "flatten" them into vectors in order to make sense of them.

In general, it will be much easier to avoid "flattening" operations wherever possible.
In order to do so, we now introduce a generalised notion of the derivative.

_**Functions Between More General Spaces**_

In order to avoid the difficulties described above, we consider we consider functions ``f : \mathcal{X} \to \mathcal{Y}``, where ``\mathcal{X}`` and ``\mathcal{Y}`` are _finite_ dimensional real Hilbert spaces (read: finite-dimensional vector space with an inner product, and real-valued scalars).
This definition includes functions to / from ``\RR``, ``\RR^D``, but also real-valued matrices, and any other "container" for collections of real numbers.
Furthermore, we shall see later how we can model all sorts of structured representations of data directly as such spaces.

For such spaces, the derivative of ``f`` at ``x \in \mathcal{X}`` is the linear operator (read: linear function) ``D f [x] : \mathcal{X} \to \mathcal{Y}`` satisfying
```math
\text{d}f = D f [x] \, (\text{d} x)
```
The purpose of this linear operator is to provide a linear approximation to ``f`` which is accurate for arguments which are very close to ``x``.

Please note that ``D f [x]`` is a single mathematical object, despite the fact that 3 separate symbols are used to denote it -- ``D f [x] (\dot{x})`` denotes the application of the function ``D f [x]`` to argument ``\dot{x}``.
Furthermore, the dot-notation (``\dot{x}``) does not have anything to do with time-derivatives, it is simply common notation used in the AD literature to denote the arguments of derivatives.

So, instead of thinking of the derivative as a number or a matrix, we think about it as a _function_.
We can express the previous notions of the derivative in this language.

In the scalar case, rather than thinking of the derivative as _being_ ``\alpha``, we think of it is a the linear operator ``D f [x] (\dot{x}) := \alpha \dot{x}``.
Put differently, rather than thinking of the derivative as the slope of the tangent to ``f`` at ``x``, think of it as the function decribing the tangent itself.
Observe that up until now we had only considered inputs to ``D f [x]`` which were small (``\text{d} x``) -- here we extend it to the entire space ``\mathcal{X}`` and denote inputs in this space ``\dot{x}``.
Inputs ``\dot{x}`` should be thoughts of as "directions", in the directional derivative sense (why this is true will be discussed later).

Similarly, if ``\mathcal{X} = \RR^P`` and ``\mathcal{Y} = \RR^Q`` then this operator can be specified in terms of the Jacobian matrix: ``D f [x] (\dot{x}) := J[x] \dot{x}`` -- brackets are used to emphasise that ``D f [x]`` is a function, and is being applied to ``\dot{x}``.[^note_for_geometers]

The difference from usual is a little bit subtle.
We do not define the derivative to _be_ ``\alpha`` or ``J[x]``, rather we define it to be "multiply by ``\alpha``" or "multiply by ``J[x]``".
For the rest of this document we shall use this definition of the derivative.
So whenever you see the word "derivative", you should think "linear function".

_**The Chain Rule**_

The chain rule is _the_ result which makes AD work.
Fortunately, it applies to this version of the derivative:
```math
f = g \circ h \implies D f [x] = (D g [h(x)]) \circ (D h [x])
```
By induction this extends to a collection of ``N`` functions ``f_1, \dots, f_N``:
```math
f := f_N \circ \dots \circ f_1 \implies D f [x] = (D f_N [x_N]) \circ \dots \circ (D f_1 [x_1]),
```
where ``x_{n+1} := f(x_n)``, and ``x_1 := x``.


_**An aside: the definition of the Frechet Derivative**_

This definition of the derivative has a name: the Frechet derivative.
It is a generalisation of the Total Derivative.
Formally, we say that a function ``f : \mathcal{X} \to \mathcal{Y}`` is differentiable at a point ``x \in \mathcal{X}`` if there exists a linear operator ``D f [x] : \mathcal{X} \to \mathcal{Y}`` (the derivative) satisfying
```math
\lim_{\text{d} h \to 0} \frac{\| f(x + \text{d} h) - f(x) + D f [x] (\text{d} h)  \|_\mathcal{Y}}{\| \text{d}h \|_\mathcal{X}} = 0,
```
where ``\| \cdot \|_\mathcal{X}`` and ``\| \cdot \|_\mathcal{Y}`` are the norms associated to Hilbert spaces ``\mathcal{X}`` and ``\mathcal{Y}`` respectively.
It is a good idea to consider what this looks like when ``\mathcal{X} = \mathcal{Y} = \RR`` and when ``\mathcal{X} = \mathcal{Y} = \RR^D``.
It is sometimes helpful to refer to this definition to e.g. verify the correctness of the derivative of a function -- as with single-variable calculus, however, this is rare.



_**Another aside: what does Forwards-Mode AD compute?**_

At this point we have enough machinery to discuss forwards-mode AD.
Expressed in the language of linear operators and Hilbert spaces, the goal of forwards-mode AD is the following:
given a function ``f`` which is differentiable at a point ``x``, compute ``D f [x] (\dot{x})`` for a given vector ``\dot{x}``.
If ``f : \RR^P \to \RR^Q``, this is equivalent to computing ``J[x] \dot{x}``, where ``J[x]`` is the Jacobian of ``f`` at ``x``.
For the interested reader we provide a high-level explanation of _how_ forwards-mode AD does this in [_How_ does Forwards-Mode AD work?](@ref).



# Reverse-Mode AD: _what_ does it do?

In order to explain what reverse-mode AD does, we first consider the "vector-Jacobian product" definition in Euclidean space which will be familiar to many readers.
We then generalise.

_**Reverse-Mode AD: what does it do in Euclidean space?**_

In this setting, the goal of reverse-mode AD is the following: given a function ``f : \RR^P \to \RR^Q`` which is differentiable at ``x \in \RR^P`` with Jacobian ``J[x]`` at ``x``, compute ``J[x]^\top \bar{y}`` for any ``\bar{y} \in \RR^Q``.
This is useful because we can obtain the gradient from this when ``Q = 1`` by letting ``\bar{y} = 1``.

_**Adjoint Operators**_

In order to generalise this algorithm to work with linear operators, we must first generalise the idea of multiplying a vector by the transpose of the Jacobian.
The relevant concept here is that of the _adjoint_ _operator_.
Specifically, the adjoint ``A^\ast`` of linear operator ``A`` is the linear operator satisfying
```math
\langle A^\ast \bar{y}, \dot{x} \rangle = \langle \bar{y}, A \dot{x} \rangle.
```
The relationship between the adjoint and matrix transpose is this: if ``A (x) := J x`` for some matrix ``J``, then ``A^\ast (y) := J^\top y``.

Moreover, just as ``(A B)^\top = B^\top A^\top`` when ``A`` and ``B`` are matrices, ``(A B)^\ast = B^\ast A^\ast`` when ``A`` and ``B`` are linear operators.
This result follows in short order from the definition of the adjoint operator -- (and is a good exercise!)

_**Reverse-Mode AD: what does it do in general?**_

Equipped with adjoints, we can express reverse-mode AD only in terms of linear operators, dispensing with the need to express everything in terms of Jacobians.
The goal of reverse-mode AD is as follows: given a differentiable function ``f : \mathcal{X} \to \mathcal{Y}``, compute ``D f [x]^\ast (\bar{y})`` for some ``\bar{y}``.

Notation: ``D f [x]^\ast`` denotes the single mathematical object which is the adjoint of ``D f [x]``.
It is a linear function from ``\mathcal{Y}`` to ``\mathcal{X}``.
We may occassionally write it as ``(D f [x])^\ast`` if there is some risk of confusion.

We will explain _how_ reverse-mode AD goes about computing this after some worked examples.

### Some Worked Examples

We now present some worked examples in order to prime intuition, and to introduce the important classes of problems that will be encountered when doing AD in the Julia language.
We will put all of these problems in a single general framework later on.

#### An Example with Matrix Calculus

We have introduced some mathematical abstraction in order to simplify the calculations involved in AD.
To this end, we consider differentiating ``f(X) := X^\top X``.
Results for this and similar operations are given by [giles2008extended](@cite).
A similar operation, but which maps from matrices to ``\RR`` is discussed in Lecture 4 part 2 of the MIT course mentioned previouly.
Both [giles2008extended](@cite) and Lecture 4 part 2 provide approaches to obtaining the derivative of this function.

Following either resource will yield the derivative:
```math
D f [X] (\dot{X}) = \dot{X}^\top X + X^\top \dot{X}
```
Observe that this is indeed a linear operator (i.e. it is linear in its argument, ``\dot{X}``).
(You can always plug it in to the definition of the Frechet derivative to confirm that it is indeed the derivative.)

In order to perform reverse-mode AD, we need to find the adjoint operator.
Using the usual definition of the inner product between matrices,
```math
\langle X, Y \rangle := \textrm{tr} (X^\top Y)
```
we can rearrange the inner product as follows:
```math
\begin{align}
    \langle \bar{Y}, D f [X] (\dot{X}) \rangle &= \langle \bar{Y}, \dot{X}^\top X + X^\top \dot{X} \rangle \nonumber \\
        &= \textrm{tr} (\bar{Y}^\top \dot{X}^\top X) + \textrm{tr}(\bar{Y}^\top X^\top \dot{X}) \nonumber \\
        &= \textrm{tr} ( [\bar{Y} X^\top]^\top \dot{X}) + \textrm{tr}( [X \bar{Y}]^\top \dot{X}) \nonumber \\
        &= \langle \bar{Y} X^\top + X \bar{Y}, \dot{X} \rangle. \nonumber
\end{align}
```
We can read off the adjoint operator from the first argument to the inner product:
```math
D f [X]^\ast (\bar{Y}) = \bar{Y} X^\top + X \bar{Y}.
```

#### AD of a Julia function: a trivial example

We now turn to differentiating Julia `function`s.
The way that Tapir.jl handles immutable data is very similar to how Zygote / ChainRules do.
For example, consider the Julia function
```julia
f(x::Float64) = sin(x)
```
If you've previously worked with ChainRules / Zygote, without thinking too hard about the formalisms we introduced previously (perhaps by considering a variety of partial derivatives) you can probably arrive at the following adjoint for the derivative of `f`:
```julia
g -> g * cos(x)
```

Implicitly, you have performed three steps:
1. model `f` as a differentiable function,
2. compute its derivative, and
3. compute the adjoint of the derivative.

It is helpful to work through this simple example in detail, as the steps involved apply more generally.
The goal is to spell out the steps involved in detail, as this detail becomes helpful in more complicated examples.
If at any point this exercise feels pedantic, we ask you to stick with it.

_**Step 1: Differentiable Mathematical Model**_

Obviously, we model the Julia `function` `f` as the function ``f : \RR \to \RR`` where
```math
f(x) := \sin(x)
```
Observe that, we've made (at least) two modelling assumptions here:
1. a `Float64` is modelled as a real number,
2. the Julia `function` `sin` is modelled as the usual mathematical function ``\sin``.

As promised we're being quite pedantic.
While the first assumption is obvious and will remain true, we will shortly see examples where we have to work a bit harder to obtain a correspondence between a Julia `function` and a mathematical object.

_**Step 2: Compute Derivative**_

Now that we have a mathematical model, we can differentiate it:
```math
D f [x] (\dot{x}) = \cos(x) \dot{x}
```

_**Step 3: Compute Adjoint of Derivative**_

Given the derivative, we can find its adjoint:
```math
\langle \bar{f}, D f [x](\dot{x}) \rangle = \langle \bar{f}, \cos(x) \dot{x} \rangle = \langle \cos(x) \bar{f}, \dot{x} \rangle.
```
From here the adjoint can be read off from the first argument to the inner product:
```math
D f [x]^\ast (\bar{f}) = \cos(x) \bar{f}.
```


#### AD of a Julia function: a slightly less trivial example

Now consider the Julia function
```julia
f(x::Float64, y::Tuple{Float64, Float64}) = x + y[1] * y[2]
```
Its adjoint is going to be something along the lines of
```julia
g -> (g, (y[2] * g, y[1] * g))
```

As before, we work through in detail.



_**Step 1: Differentiable Mathematical Model**_

There are a couple of aspects of `f` which require thought:
1. it has two arguments -- we've only handled single argument functions previously, and
2. the second argument is a `Tuple` -- we've not yet decided how to model this.

To this end, we define a mathematical notion of a tuple.
A tuple is a collection of ``N`` elements, each of which is drawn from some set ``\mathcal{X}_n``.
We denote by ``\mathcal{X} := \{ \mathcal{X}_1 \times \dots \times \mathcal{X}_N \}`` the set of all ``N``-tuples whose ``n``th element is drawn from ``\mathcal{X}_n``.
Provided that each ``\mathcal{X}_n`` forms a finite Hilbert space, ``\mathcal{X}`` forms a Hilbert space with
1. ``\alpha x := (\alpha x_1, \dots, \alpha x_N)``,
2. ``x + y := (x_1 + y_1, \dots, x_N + y_N)``, and
3. ``\langle x, y \rangle := \sum_{n=1}^N \langle x_n, y_n \rangle``.

We can think of multi-argument functions as single-argument functions of a tuple, so a reasonable mathematical model for `f` might be a function ``f : \{ \RR \times \{ \RR \times \RR \} \} \to \RR``, where
```math
f(x, y) := x + y_1 y_2
```
Note that while the function is written with two arguments, you should treat them as a single tuple, where we've assigned the name ``x`` to the first element, and ``y`` to the second.

_**Step 2: Compute Derivative**_

Now that we have a mathematical object, we can differentiate it:
```math
D f [x, y](\dot{x}, \dot{y}) = \dot{x} + \dot{y}_1 y_2 + y_1 \dot{y}_2
```

_**Step 3: Compute Adjoint of Derivative**_

``D f[x, y]`` maps ``\{ \RR \times \{ \RR \times \RR \}\}`` to ``\RR``, so ``D f [x, y]^\ast`` must map the other way.
You should verify that the following follows quickly from the definition of the adjoint:
```math
D f [x, y]^\ast (\bar{f}) =  (\bar{f}, (\bar{f} y_2, \bar{f} y_1))
```


#### AD with mutable data

In the previous two examples there was an obvious mathematical model for the Julia function.
Indeed this model was sufficiently obvious that it required little explanation.
This is not always the case though, in particular, Julia functions which modify / mutate their inputs require a little more thought.

Consider the following Julia `function`:
```julia
function f!(x::Vector{Float64})
    x .*= x
    return sum(x)
end
```
This `function` squares each element of its input in-place, and returns the sum of the result.
So what is an appropriate mathematical model for this `function`?

_**Step 1: Differentiable Mathematical Model**_

The trick is to distingush between the state of `x` upon _entry_ to / _exit_ from `f!`.
In particular, let ``\phi_{\text{f!}} : \RR^N \to \{ \RR^N \times \RR \}`` be given by
```math
\phi_{\text{f!}}(x) = (x \odot x, \sum_{n=1}^N x_n^2)
```
where ``\odot`` denotes the Hadamard / elementwise product.
The point here is that the inputs to ``\phi_{\text{f!}}`` are the inputs to `x` upon entry to `f!`, and the value returned from ``\phi_{\text{f!}}`` is a tuple containing the both the inputs upon exit from `f!` and the value returned by `f!`.

The remaining steps are straightforward now that we have the model.


_**Step 2: Compute Derivative**_

The derivative of ``\phi_{\text{f!}}`` is
```math
D \phi_{\text{f!}} [x](\dot{x}) = (2 x \odot x, 2 \sum_{n=1}^N x_n \dot{x}_n).
```

_**Step 3: Compute Adjoint of Derivative**_

The argument to the adjoint of the derivative must be a 2-tuple whose elements are drawn from ``\{\RR^N \times \RR \}``.
Denote such a tuple as ``(\bar{y}_1, \bar{y}_2)``.
Plugging this into an inner product with the derivative and rearranging yields
```math
\begin{align}
    \langle (\bar{y}_1, \bar{y}_2), D \phi_{\text{f!}} [x] (\dot{x}) \rangle &= \langle (\bar{y}_1, \bar{y}_2), (2 x \odot \dot{x}, 2 \sum_{n=1}^N x_n \dot{x}_n) \rangle \nonumber \\
        &= \langle \bar{y}_1, 2 x \odot \dot{x} \rangle + \langle \bar{y}_2, 2 \sum_{n=1}^N x_n \dot{x}_n \rangle \nonumber \\
        &= \langle 2x \odot \bar{y}_1, \dot{x} \rangle + \langle 2 \bar{y}_2 x, \dot{x} \rangle \nonumber \\
        &= \langle 2 (x \odot \bar{y}_1 + \bar{y}_2 x), \dot{x} \rangle. \nonumber
\end{align}
```
So we can read off the adjoint to be
```math
D \phi_{\text{f!}} [x]^\ast (\bar{y}) = 2 (x \odot \bar{y}_1 + \bar{y}_2 x).
```

# Reverse-Mode AD: _how_ does it do it?

Now that we know _what_ it is that AD computes, we need a rough understanding of _how_ it computes it.

In short: reverse-mode AD breaks down a "complicated" function ``f`` into the composition of a collection of "simple" functions ``f_1, \dots, f_N``, applies the chain rule, and takes the adjoint.

Specifically, we assume that we can express any function ``f`` as ``f = f_N \circ \dots \circ f_1``, and that we can compute the adjoint of the derivative for each ``f_n``.
From this, we can obtain the adjoint of ``f`` by applying the chain rule to the derivatives and taking the adjoint:
```math
\begin{align}
D f [x]^\ast &= (D f_N [x_N] \circ \dots \circ D f_1 [x_1])^\ast \nonumber \\
    &= D f_1 [x_1]^\ast \circ \dots \circ D f_N [x_N]^\ast \nonumber
\end{align}
```

For example, suppose that ``f(x) := \sin(\cos(\text{tr}(X^\top X)))``.
One option to compute its adjoint is to figure it out by hand directly (probably using the chain rule somewhere).
Instead, we could notice that ``f = f_4 \circ f_3 \circ f_2 \circ f_1`` where ``f_4 := \sin``, ``f_3 := \cos``, ``f_2 := \text{tr}`` and ``f_1(X) = X^\top X``.
We could derive the adjoint for each of these functions (a fairly straightforward task), and then compute
```math
D f [x]^\ast (\bar{y}) = (D f_1 [x_1]^\ast \circ D f_2 [x_2]^\ast \circ D f_3 [x_3]^\ast \circ D f_4 [x_4]^\ast)(1)
```
in order to obtain the gradient of ``f``.
Reverse-mode AD essentially just does this.
Modern systems have hand-written adjoints for (hopefully!) all of the "simple" functions you may wish to build a function such as ``f`` from (often there are hundreds of these), and composes them to compute the adjoint of ``f``.
A sketch of a more generic algorithm is as follows.

Forwards-Pass:
1. ``x_1 = x``, ``n = 1``
2. construct ``D f_n [x_n]^\ast``
3. let ``x_{n+1} = f_n (x_n)``
4. let ``n = n + 1``
5. if ``n < N + 1`` then go to 2

Reverse-Pass:
1. let ``\bar{x}_{N+1} = \bar{y}``
2. let ``n = n - 1``
3. let ``\bar{x}_{n} = D f_n [x_n]^\ast (\bar{x}_{n+1})``
4. if ``n = 1`` return ``\bar{x}_1`` else go to 2.




_**How does this relate to vector-Jacobian products?**_

In Euclidean space, each derivative ``D f_n [x_n](\dot{x}_n) = J_n[x_n] \dot{x}_n``.
Applying the chain rule to ``D f [x]`` and substituting this in yields
```math
J[x] = J_N[x_N] \dots J_1[x_1] .
```
Taking the transpose and multiplying from the left by ``\bar{y}`` yields
```math
J[x]^\top \bar{y} = J[x_1]^\top_1 \dots J[x_N]^\top_N \bar{y} .
```
Comparing this with the expression in terms of adjoints and operators, we see that composition of adjoints of derivatives has been replaced with multiplying by transposed Jacobian matrices.
This "vector-Jacobian product" expression is commonly used to explain AD, and is likely familiar to many readers.

# Directional Derivatives and Gradients

Now we turn to using reverse-mode AD to compute the gradient of a function.
In short, given a function ``g : \mathcal{X} \to \RR`` with derivative ``D g [x]`` at ``x``, its gradient is equal to ``D g [x]^\ast (1)``.
We explain why in this section.

The derivative discussed here can be used to compute directional derivatives.
Consider a function ``f : \mathcal{X} \to \RR`` with Frechet derivative ``D f [x] : \mathcal{X} \to \RR`` at ``x \in \mathcal{X}``.
Then ``D f[x](\dot{x})`` returns the directional derivative in direction ``\dot{x}``.

Gradients are closely related to the adjoint of the derivative.
Recall that the gradient of ``f`` at ``x`` is defined to be the vector ``\nabla f (x) \in \mathcal{X}`` such that ``\langle \nabla f (x), \dot{x} \rangle`` gives the directional derivative of ``f`` at ``x`` in direction ``\dot{x}``.
Having noted that ``D f[x](\dot{x})`` is exactly this directional derivative, we can equivalently say that
```math
D f[x](\dot{x}) = \langle \nabla f (x), \dot{x} \rangle .
```

The role of the adjoint is revealed when we consider ``f := \mathcal{l} \circ g``, where ``g : \mathcal{X} \to \mathcal{Y}``, ``\mathcal{l}(y) := \langle \bar{y}, y \rangle``, and ``\bar{y} \in \mathcal{Y}`` is some fixed vector.
Noting that ``D \mathcal{l} [y](\dot{y}) = \langle \bar{y}, \dot{y} \rangle``, we apply the chain rule to obtain
```math
\begin{align}
D f [x] (\dot{x}) &= [(D \mathcal{l} [g(x)]) \circ (D g [x])](\dot{x}) \nonumber \\
    &= \langle \bar{y}, D g [x] (\dot{x}) \rangle \nonumber \\
    &= \langle D g [x]^\ast (\bar{y}), \dot{x} \rangle, \nonumber
\end{align}
```
from which we conclude that ``D g [x]^\ast (\bar{y})`` is the gradient of the composition ``l \circ g`` at ``x``.

The consequence is that we can always view the computation performed by reverse-mode AD as computing the gradient of the composition of the function in question and an inner product with the argument to the adjoint.

The above shows that if ``\mathcal{Y} = \RR`` and ``g`` is the function we wish to compute the gradient of, we can simply set ``\bar{y} = 1`` and compute ``D g [x]^\ast (\bar{y})`` to obtain the gradient of ``g`` at ``x``.




# Summary

This document explains the core mathematical foundations of AD.
It explains separately _what_ is does, and _how_ it goes about it.
Some basic examples are given which show how these mathematical foundations can be applied to differentiate functions of matrices, and Julia `function`s.

Subsequent sections will build on these foundations, to provide a more general explanation of what AD looks like for a Julia programme.



# Asides

### _How_ does Forwards-Mode AD work?

Forwards-mode AD achieves this by breaking down ``f`` into the composition ``f = f_N \circ \dots \circ f_1``, # where each ``f_n`` is a simple function whose derivative (function) ``D f_n [x_n]`` we know for any given ``x_n``. By the chain rule, we have that
```math
D f [x] (\dot{x}) = D f_N [x_N] \circ \dots \circ D f_1 [x_1] (\dot{x})
```
which suggests the following algorithm:
1. let ``x_1 = x``, ``\dot{x}_1 = \dot{x}``, and ``n = 1``
2. let ``\dot{x}_{n+1} = D f_n [x_n] (\dot{x}_n)``
3. let ``x_{n+1} = f(x_n)``
4. let ``n = n + 1``
5. if ``n = N+1`` then return ``\dot{x}_{N+1}``, otherwise go to 2.

When each function ``f_n`` maps between Euclidean spaces, the applications of derivatives ``D f_n [x_n] (\dot{x}_n)`` are given by ``J_n \dot{x}_n`` where ``J_n`` is the Jacobian of ``f_n`` at ``x_n``.v

```@bibliography
```

[^note_for_geometers]: in AD we only really need to discuss differentiatiable functions between vector spaces that are isomorphic to Euclidean space. Consequently, a variety of considerations which are usually required in differential geometry are not required here. Notably, the tangent space is assumed to be the same everywhere, and to be the same as the domain of the function. Avoiding these additional considerations helps keep the mathematics as simple as possible.
