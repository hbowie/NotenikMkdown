Title:  MathJax Test - Built Up Structures

Seq:    254

Body: 

-   Fractions: $\frac{1}{2}$, $\frac{x-1}{x-2}$.

-   Binomial coefficients: $\binom{n}{2}$.

-   Sums and products. Do *not* use `\Sigma` and `\Pi`.

    $$
    \sum_{k=0}^\infty \frac{x^k}{k!} \not= \prod_{j=1}^{10} \frac{j}{j+1}.
    $$

    $$
    \bigcup_{k=0}^\infty A_k
    \qquad
    \bigoplus_{j=1}^\infty V_j
    $$

-   Integrals:

    $$
    \int_0^1 x^2 \, dx
    $$

    The extra bit of space before the $dx$ term is created with the `\,`
    command.

-   Limits:

    $$
    \lim_{h\to0} \frac{\sin(x+h) - \sin(x)}{h} = \cos x .
    $$

    Also $\limsup_{n\to\infty} a_n$.

-   Radicals: $\sqrt{3}$, $\sqrt[3]{12}$, $\sqrt{1+\sqrt{2}}$.

-   Matrices:

    $$
    A = \left[\begin{matrix} 3 & 4 & 0 \\ 2 & -1 & \pi \end{matrix}\right] .
    $$

    A big matrix:

    $$
    D = \left[ 
        \begin{matrix}
          \lambda_1 & 0 & 0 & \cdots & 0 \\
          0 & \lambda_2 & 0 & \cdots & 0 \\
          0 & 0 & \lambda_3 & \cdots & 0 \\
          \vdots & \vdots & \vdots & \ddots & \vdots \\
          0 & 0 & 0 & \cdots & \lambda_n
        \end{matrix}
        \right].
    $$
