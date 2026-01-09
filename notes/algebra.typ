#set page(flipped: true, columns: 3, margin: 10pt)
#set text(lang: "pl")
#set heading(numbering: "1.")
#show math.equation: set block(breakable: false)
#show math.equation.where(block: false): box
#let hrule = line(length: 100%, stroke: 0.5pt + black)

Postać kanoniczna:

$
k: (x - x_0)/l = (y - y_0)/m = (z - z_0)/n \
arrow(u) = [l, m, n] parallel k \
(x_0, y_0, z_0) in k 
$

#hrule

Postać parametryczna:

$
k: cases(
  x = x_0 + l dot t,
  y = y_0 + m dot t,
  z = z_0 + n dot t
) wide t in RR
$

#hrule

Postać krawędziowa:

$
cases(
  H_1 : A_1 x + B_1 y + C_1 z + D_1 = 0,
  H_2 : A_2 x + B_2 y + C_2 z + D_2 = 0
)
$

#hrule

Odległość punktu $A(x_0, y_0, z_0)$ od prostej $k$:

$
d = (| mat(delim: "|",
  i, j, k;
  x_1 - x_0, y_1 - y_0, z_1 - z_0;
  l, m, n
) |) / sqrt(l^2 + m^2 + n^2)
$

#hrule

$k_1: (x - x_1)/l_1 = (y - y_1)/m_1 = (z - z_1)/n_1, k_2: (x - x_2)/l_2 = (y - y_2)/m_2 = (z - z_2)/n_2$ leżą w jednej płaszczyźnie, jeśli:

$
det mat(delim: "[",
  x_2 - x_1, y_2 - y_1, z_2 - z_2;
  l_1, m_1, n_1;
  l_2, m_2, n_2
) = 0
$
