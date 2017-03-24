defmodule GlobalPayments.Api.Entities.Enums do
  defmodule EnumeratedType do
    def create(module, values) do
      for {name, value} <- values do
        module_name = Module.concat(module, name)
        contents =
          quote do
            def value, do: unquote(value)
          end
        Module.create(module_name, contents, Macro.Env.location(__ENV__))
      end
    end
  end

  defmodule PaymentMethodType do
    use Bitwise, only_operators: true
    EnumeratedType.create(__MODULE__,
      Reference: 1 <<< 0,
      Credit: 1 <<< 1,
      Debit: 1 <<< 2,
      EBT: 1 <<< 3,
      Cash: 1 <<< 4,
      ACH: 1 <<< 5,
      Gift: 1 <<< 6,
      Recurring: 1 <<< 7
    )
  end

  defmodule TransactionModifier do
    use Bitwise, only_operators: true
    EnumeratedType.create(__MODULE__,
      None: 1 <<< 0,
      Incremental: 1 <<< 1,
      Additional: 1 <<< 2,
      Offline: 1 <<< 3,
      LevelII: 1 <<< 4,
      FraudDecline: 1 <<< 5,
      ChipDecline: 1 <<< 6,
      CashBack: 1 <<< 7,
      Voucher: 1 <<< 8,
    )
  end

  defmodule TransactionType do
    use Bitwise, only_operators: true
    EnumeratedType.create(__MODULE__,
      Decline: 1 <<< 0,
      Verify: 1 <<< 1,
      Capture: 1 <<< 2,
      Auth: 1 <<< 3,
      Refund: 1 <<< 4,
      Reversal: 1 <<< 5,
      Sale: 1 <<< 6,
      Edit: 1 <<< 7,
      Void: 1 <<< 8,
      AddValue: 1 <<< 9,
      Balance: 1 <<< 10,
      Activate: 1 <<< 11,
      Alias: 1 <<< 12,
      Replace: 1 <<< 13,
      Reward: 1 <<< 14,
      Deactivate: 1 <<< 15,
      BatchClose: 1 <<< 16,
      Create: 1 <<< 17,
      Delete: 1 <<< 18,
      BenefitWithDrawal: 1 <<< 19,
      Fetch: 1 <<< 20,
    )
  end
end
