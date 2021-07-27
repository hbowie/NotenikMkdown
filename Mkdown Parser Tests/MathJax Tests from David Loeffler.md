Title:  MathJax Tests from David Loeffler

Seq:    249

Body: 

The nvUltra uses either MathJax or KaTeX for rending mathematical expressions. I set it to MathJax and had the HTML header meta data (see above) so I get equation numbers for LaTeX environments like `equation`. 

\\[
\begin{equation}
 \label{energy_mass_eq}
E=mc^{2} 
\end{equation}
\\]

The equation $\ref{energy_mass_eq}$ represents the relationship between mass and energy.

or `align`

$$\begin{align}
\ddot{\underline{\mathbf{r}}} &= \frac{d{^2}\underline{\mathbf{r}}}{dt^2}\\
	&= 0
\end{align}$$

or `align` with `\nonumber`  to block numbering certain lines.

$$\begin{align}
\ddot{\underline{\mathbf{r}}} &= \frac{d{^2}\underline{\mathbf{r}}}{dt^2}\nonumber\\
                              &= 0
\end{align}$$

or `eqarray`

$$\begin{eqnarray}
   7x + 4y & =  & 0 \\
   2x - 5y & =  & 0
\end{eqnarray}$$

or `eqnarray` with `\nonumber`

$$\begin{eqnarray}
  -\Delta  u & =  & f \\
  u & =  & 0 \nonumber 
\end{eqnarray}$$

`cases`  gets one number 

$$\begin{equation}
   \begin{cases}
   \frac{1}{ T(t)} \partial_{tt} T(t) = - \lambda^2,  \\
     \\
     c^2  \frac{1}{R(r)} \partial_{rr} R(r) + \frac{1}{R(r)} \frac{1}{r}
     \partial_{r} R(r) + \frac{1}{r^2} \partial_{\theta \theta} \frac{1}{\Theta
     ( \theta) } \Theta( \theta ) = - \lambda^2. \label{eq:sep_var2} \\
   \end{cases}
\end{equation}$$

or `gather` 

$$\begin{gather}
    \frac{dS(t)}{dt} = -\beta.(\frac{S(t)}{P}).I(t) + \alpha R(t) + \mu (P-S(t))\\
    \frac{dI(t)}{dt} = \beta.(\frac{S(t)}{P}).I(t) - \gamma I(t) - \mu I(t)\\
    \frac{dR(t)}{dt} = \gamma.I(t) - \alpha R(t) - \mu R(t)
\end{gather}$$

or `multline`

$$\begin{multline} 
f(x) = 4x^{12} -7x^{11} - x^{10} - 3x^9 + 31x^8 + x^7 + 4x^6 + 50x^5 \\ +21x^4 + 9x^3 + x^2   
 +201x +4
\end{multline}$$

## Syntax Highlighting

```scheme
(define (double x)
  (+ x x))
```
