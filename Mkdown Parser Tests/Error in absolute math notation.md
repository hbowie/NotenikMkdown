Title:  Error in absolute math notation

Seq:    255

Code: 

This expression $|x-y|$ does not render correctly in certain situations.

As an equation  

$$|x-y|$$

it does NOT render correctly if the `$$` immediately follows the last `|`.

This works:

$$|x-y| $$

This works

$$
|x-y|
$$

as well as using the `equation` environment.

$$
\begin{equation}
|x-y|
\end{equation}
$$

But if you don't have two `returns` this line ends up BELOW the equation.
$$
|x-y|
$$


Body: 

This expression $|x-y|$ does not render correctly in certain situations.

As an equation  

$$|x-y|$$

it does NOT render correctly if the `$$` immediately follows the last `|`.

This works:

$$|x-y| $$

This works

$$
|x-y|
$$

as well as using the `equation` environment.

$$
\begin{equation}
|x-y|
\end{equation}
$$

But if you don't have two `returns` this line ends up BELOW the equation.
$$
|x-y|
$$
