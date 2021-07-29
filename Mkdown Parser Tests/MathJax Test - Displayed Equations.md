Title:  MathJax Test - Displayed Equations

Seq:    252

Code: 

Displayed equations
-------------------

When an equation becomes too large to run in-line, you display it in a “Math”
paragraph by itself.

$$
f(x) = 5x^{10}-9x^9 + 77x^8 + 12x^7 + 4x^6 - 8x^5 + 7x^4 + x^3 -2x^2 + 3x + 11.
$$

The `\begin{aligned}...\end{aligned}` environment is superb for lining up
equations.

$$
\begin{aligned}
  (x-y)^2
  &= (x-y)(x-y) \\
  &= x^2 -yx - xy + y^2 \\
  &= x^2 -2xy +y^2.
\end{aligned}
$$

$$
\begin{aligned}
  3x-y&=0 & 2a+b &= 4 \\
  x+y &=1 & a-3b &=10
\end{aligned}
$$

To insert ordinary text inside of mathematics mode, use `\text`:

$$
f(x) = \frac{x}{x-1} \text{ for $x\not=1$}.
$$

This is the $3^{\text{rd}}$ time I’ve asked for my money back.

The `\begin{cases}...\end{cases}` environment is perfect for defining functions
piecewise:

$$
|x| =
\begin{cases}
x & \text{when $x \ge 0$ and} \\
-x & \text{otherwise.}
\end{cases}
$$

Body: 

Displayed equations
-------------------

When an equation becomes too large to run in-line, you display it in a “Math”
paragraph by itself.

$$
f(x) = 5x^{10}-9x^9 + 77x^8 + 12x^7 + 4x^6 - 8x^5 + 7x^4 + x^3 -2x^2 + 3x + 11.
$$

The `\begin{aligned}...\end{aligned}` environment is superb for lining up
equations.

$$
\begin{aligned}
  (x-y)^2
  &= (x-y)(x-y) \\
  &= x^2 -yx - xy + y^2 \\
  &= x^2 -2xy +y^2.
\end{aligned}
$$

$$
\begin{aligned}
  3x-y&=0 & 2a+b &= 4 \\
  x+y &=1 & a-3b &=10
\end{aligned}
$$

To insert ordinary text inside of mathematics mode, use `\text`:

$$
f(x) = \frac{x}{x-1} \text{ for $x\not=1$}.
$$

This is the $3^{\text{rd}}$ time I’ve asked for my money back.

The `\begin{cases}...\end{cases}` environment is perfect for defining functions
piecewise:

$$
|x| =
\begin{cases}
x & \text{when $x \ge 0$ and} \\
-x & \text{otherwise.}
\end{cases}
$$
