defmodule GlobalPayments.Api.PaymentMethods.CreditCardData do
  alias GlobalPayments.Api.Builders.AuthorizationBuilder
  alias GlobalPayments.Api.Gateways.PorticoConnector.PaymentMethodType
  alias GlobalPayments.Api.Gateways.PorticoConnector.TransactionType
  @behaviour Access

  defstruct number: nil,
            exp_month: nil,
            exp_year: nil,
            cvn: nil,
            cvn_presence_indicator: nil,
            card_holder_name: nil,
            card_present: nil,
            reader_present: nil,
            payment_method_type: PaymentMethodType.Credit

  def charge(card, amount \\ nil) do
    struct!(AuthorizationBuilder, transaction_type: TransactionType.Sale)
    |> AuthorizationBuilder.with_amount(amount)
    |> AuthorizationBuilder.with_payment_method(card)
  end

  ## `Access` behaviour implementations

  def fetch(term, key) do
    Map.fetch(term, key)
  end

  def get(term, key, default) do
    Map.get(term, key, default)
  end

  def get_and_update(term, key, list) do
    Map.get(term, key, list)
  end

  def pop(term, key) do
    Map.pop(term, key)
  end
end
