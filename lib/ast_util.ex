defmodule AbacusSql.AstUtil do
  def join_right_operator(expressions, operator)
  def join_right_operator([one], _operator) do
    one
  end
  def join_right_operator([first | rest], operator) do
    {operator, [], [first, join_right_operator(rest, operator)]}
  end
end
