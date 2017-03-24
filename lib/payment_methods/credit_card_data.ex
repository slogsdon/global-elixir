defmodule GlobalPayments.Api.PaymentMethods.CreditCardData do
  alias GlobalPayments.Api.Builders.AuthorizationBuilder
  alias GlobalPayments.Api.Entities.Enums.{PaymentMethodType, TransactionType}
  use GlobalPayments.Api.Util.Accessible

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
end
