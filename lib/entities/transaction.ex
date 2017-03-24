defmodule GlobalPayments.Api.Entities.Transaction do
  @behaviour Access
  use GlobalPayments.Api.Util.Accessible

  defstruct response_code: nil,
            response_text: nil,
            transaction_reference: nil,
            authorized_amount: nil,
            commercial_indicator: nil,
            token: nil,
            balance_amount: nil,
            points_balance_amount: nil,
            gift_card: nil
end
