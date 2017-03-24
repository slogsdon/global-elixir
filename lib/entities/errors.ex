defmodule GlobalPayments.Api.Entities.Errors.GatewayError do
  defexception message: nil
end

defmodule GlobalPayments.Api.Entities.Errors.NotImplementedError do
  defexception message: nil
end

defmodule GlobalPayments.Api.Entities.Errors.UnsupportedTransactionError do
  defexception message: nil
end
