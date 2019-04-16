defmodule AbacusSql.Completion.Item do
  @moduledoc """
  Represents a completion item that would appear in an autocompletion list.

   * `code` - Code necessary to complete the expression from the last `.`
   * `filtered_code` - Code necessary to complete the expression from the cursor position
   * `display` - The name to display in the list
   * `description` - A short line of documentation for the completion
   * `type` - Schema or struct of that the code will return
  """

  defstruct [:code, :display, :description, :type]
end
