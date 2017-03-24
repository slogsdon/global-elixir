defmodule GlobalPayments.Api.Util.Accessible do
  defmacro __using__(_) do
    quote do
      defdelegate fetch(term, key), to: Map
      defdelegate get(term, key, default), to: Map
      defdelegate get_and_update(term, key, list), to: Map
      defdelegate pop(term, key), to: Map
    end
  end
end