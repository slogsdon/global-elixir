defmodule GlobalPayments.Api.Gateways.PorticoConnector do
  alias GlobalPayments.Api.Builders.AuthorizationBuilder
  alias GlobalPayments.Api.PaymentMethods.TransactionReference
  import GlobalPayments.Api.Gateways.XmlGateway
  import GlobalPayments.Api.Gateways.XmlGateway.XmlNode

  defmodule Transaction do
    @behaviour Access

    defstruct response_code: nil,
              response_text: nil,
              transaction_reference: nil,
              authorized_amount: nil,
              commercial_indicator: nil,
              token: nil,
              balance_amount: nil,
              points_balance_amount: nil,
              gift_card: nil

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

  defmodule GatewayError do
    defexception message: nil
  end

  defmodule NotImplementedError do
    defexception message: nil
  end

  defmodule UnsupportedTransactionError do
    defexception message: nil
  end

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

  def process_authorization(%AuthorizationBuilder{} = builder, config) do
    request_data =
      [
        {map_request_type(builder), [
          {:Block1, [
            {:CardData, [
              {:ManualEntry, maybe_add_elements([], builder.payment_method, [
                  number: :CardNbr,
                  exp_month: :ExpMonth,
                  exp_year: :ExpYear,
                  cvn: :CVV2,
                ])}
            ]},
            builder.amount && {:Amt, [builder.amount |> to_charlist]}
          ]}
        ]}
      ]
      |> build_envelope(config)

    config
    |> client()
    |> do_transaction("/Hps.Exchange.PosGateway/PosGatewayService.asmx", request_data)
    |> map_response(builder)
  end

  def build_envelope(transaction, config \\ %{}) do
    [
      {:'soap:Envelope',
        [
          {:'xmlns:soap', "http://schemas.xmlsoap.org/soap/envelope/"},
          {:xmlns, "http://Hps.Exchange.PosGateway"}
        ],
        [
          {:'soap:Body', [
            {:PosRequest, [
              {:'Ver1.0', [
                build_header(config),
                {:Transaction, transaction}
              ]}
            ]}
          ]}
        ]}
    ]
    |> :xmerl.export_simple(:xmerl_xml, [])
    |> Enum.join()
  end

  defp map_response(raw_response, builder) do
    {root, _} =
      raw_response
      |> to_charlist()
      |> :xmerl_scan.string()
    accepted_codes = ["00", "0", "85", "10"]

    gateway_response_code = node_value(root, "//GatewayRspCode")
    gateway_response_text = node_value(root, "//GatewayRspMsg")

    unless Enum.member?(accepted_codes, gateway_response_code) do
      raise GatewayError, message: "Unexpected gateway response: #{gateway_response_code} - #{gateway_response_text}"
    end

    response_code = node_value(root, "//RspCode") || gateway_response_code
    response_text =
      node_value(root, "//RspText")
      || gateway_response_text

    auth_code = node_value(root, "//AuthCode")
    transaction_reference =
      if builder.payment_method || auth_code do
        struct(TransactionReference,
          payment_method_type: builder.payment_method && builder.payment_method.payment_method_type,
          authorization_code: auth_code
        )
      end

    struct(Transaction,
      response_code: normalize_response_code(response_code),
      response_text: response_text,
      transaction_reference: transaction_reference
    )
  end

  def normalize_response_code(response_code) do
    if Enum.member?(["0", "85"], response_code) do
      "00"
    else
      response_code
    end
  end

  def node_value(root, path) when is_binary(path) do
    node_value(root, to_charlist(path))
  end
  def node_value(root, path) do
    :xmerl_xpath.string(path, root)
    |> List.first()
    |> get_node()
    |> Access.get(:content)
    |> get_value()
  end

  defp get_node(nil), do: nil
  defp get_node(node) do
    node |> xmlElement
  end

  defp get_value(nil), do: nil
  defp get_value([]), do: nil
  defp get_value([node | _]) do
    node
    |> xmlText()
    |> Access.get(:value)
    |> to_string()
  end

  defp build_header(config) do
    credentials =
      maybe_add_elements([], config, [
        secret_api_key: :SecretAPIKey,
        site_id: :SiteId,
        license_id: :LicenseId,
        device_id: :DeviceId,
        username: :UserName,
        password: :Password,
        developer_id: :DeveloperID,
        version_number: :VersionNumber
      ])

    {:Header, credentials}
  end

  @doc """
  Maps a Portico transaction type from a `builder`

  ## Examples

      iex> alias GlobalPayments.Api.Gateways.PorticoConnector
      iex> alias GlobalPayments.Api.Gateways.PorticoConnector.TransactionType
      iex> alias GlobalPayments.Api.Gateways.PorticoConnector.PaymentMethodType
      iex> PorticoConnector.map_request_type(%{transaction_type: TransactionType.BatchClose})
      :BatchClose
      iex> PorticoConnector.map_request_type(%{transaction_type: TransactionType.Verify})
      :CreditAccountVerify
      iex> PorticoConnector.map_request_type(%{transaction_type: TransactionType.Auth, payment_method: %{payment_method_type: PaymentMethodType.Recurring}})
      :RecurringBillingAuth

  """
  def map_request_type(builder) do
    case builder.transaction_type do
      TransactionType.BatchClose ->
        :BatchClose
      TransactionType.Decline ->
        if builder.payment_method and builder.payment_method.payment_method_type == PaymentMethodType.Gift do
          :GiftCardDeactivate
        else
          case builder.transaction_modifier do
            TransactionModifier.ChipDecline ->
              :ChipCardDecline
            TransactionModifier.FraudDecline ->
              :OverrideFraudDecline
            _ -> raise NotImplementedError
          end
        end
      TransactionType.Verify ->
        :CreditAccountVerify
      TransactionType.Capture ->
        :CreditAddToBatch
      TransactionType.Auth ->
        unless builder.payment_method do
          raise UnsupportedTransactionError, message: "Transaction not supported for this payment method."
        end

        case builder.payment_method.payment_method_type do
          PaymentMethodType.Credit ->
            case builder.transaction_modifier do
              TransactionModifier.Additional ->
                :CreditAdditionalAuth
              TransactionModifier.Incremental ->
                :CreditIncrementalAuth
              TransactionModifier.Offline ->
                :CreditOfflineAuth
              _ ->
                :CreditAuth
            end
          PaymentMethodType.Recurring ->
            :RecurringBillingAuth
          _ ->
            raise UnsupportedTransactionError, message: "Transaction not supported for this payment method."
        end
      TransactionType.Sale ->
        unless builder.payment_method do
          raise UnsupportedTransactionError, message: "Transaction not supported for this payment method."
        end

        case builder.payment_method.payment_method_type do
          PaymentMethodType.Credit ->
            if builder.transaction_modifier == TransactionModifier.Offline do
              :CreditOfflineSale
            else
              :CreditSale
            end
          PaymentMethodType.Debit ->
            :DebitSale
          PaymentMethodType.Cash ->
            :CashSale
          PaymentMethodType.ACH ->
            :CheckSale
          PaymentMethodType.EBT ->
            case builder.transaction_modifier do
              TransactionModifier.CashBack ->
                :EBTCashBackPurchase
              TransactionModifier.Vvoucher ->
                :EBTVoucherPurchase
              _ ->
                :EBTFSPurchase
            end
          PaymentMethodType.Gift ->
            :GiftCardSale
          _ ->
            raise UnsupportedTransactionError, message: "Transaction not supported for this payment method."
        end
      TransactionType.Refund ->
        unless builder.payment_method do
          raise UnsupportedTransactionError, message: "Transaction not supported for this payment method."
        end

        case builder.payment_method.payment_method_type do
          PaymentMethodType.Credit ->
            :CreditReturn
          PaymentMethodType.Debit ->
            :DebitReturn
          PaymentMethodType.Cash ->
            :CashReturn
          PaymentMethodType.Ebt ->
            :EBTFSReturn
          _ ->
            raise UnsupportedTransactionError, message: "Transaction not supported for this payment method."
        end
      TransactionType.Reversal ->
        unless builder.payment_method do
          raise UnsupportedTransactionError, message: "Transaction not supported for this payment method."
        end

        case builder.payment_method.payment_method_type do
          PaymentMethodType.Credit ->
            :CreditReversal
          PaymentMethodType.Debit ->
            :DebitReversal
          PaymentMethodType.Gift ->
            :GiftCardReversal
          _ ->
            raise UnsupportedTransactionError, message: "Transaction not supported for this payment method."
        end
      TransactionType.Edit ->
        if builder.transaction_modifier == TransactionModifier.LevelII do
          :CreditCPCEdit
        else
          :CreditTxnEdit
        end
      TransactionType.Boid ->
        unless builder.payment_method do
          raise UnsupportedTransactionError, message: "Transaction not supported for this payment method."
        end

        case builder.payment_method.payment_method_type do
          PaymentMethodType.Credit ->
            :CreditVoid
          PaymentMethodType.ACH ->
            :CheckVoid
          PaymentMethodType.Gift ->
            :GiftCardVoid
          _ ->
            raise UnsupportedTransactionError, message: "Transaction not supported for this payment method."
        end
      TransactionType.AddValue ->
        unless builder.payment_method do
          raise UnsupportedTransactionError, message: "Transaction not supported for this payment method."
        end

        case builder.payment_method.payment_method_type do
          PaymentMethodType.Credit ->
            :PrePaidAddValue
          PaymentMethodType.Debit ->
            :DebitAddValue
          PaymentMethodType.Gift ->
            :GiftCardAddValue
          _ ->
            raise UnsupportedTransactionError, message: "Transaction not supported for this payment method."
        end
      TransactionType.Balance ->
        unless builder.payment_method do
          raise UnsupportedTransactionError, message: "Transaction not supported for this payment method."
        end

        case builder.payment_method.payment_method_type do
          PaymentMethodType.Credit ->
            :PrePaidBalanceInquiry
          PaymentMethodType.EBT ->
            :EBTBalanceInquiry
          PaymentMethodType.Gift ->
            :GiftCardBalance
          _ ->
            raise UnsupportedTransactionError, message: "Transaction not supported for this payment method."
        end
      TransactionType.Activate ->
        :GiftCardActivate
      TransactionType.Alias ->
        :GiftCardAlias
      TransactionType.Replace ->
        :GiftCardReplace
      TransactionType.Reward ->
        :GiftCardReward
      _ ->
        raise UnsupportedTransactionError, message: "Unknown transaction"
    end
  end

  @doc """
  Adds terms from `container` to `elements` when a term's key is present in `key_map`

  ## Examples

      iex> alias GlobalPayments.Api.Gateways.PorticoConnector
      iex> PorticoConnector.maybe_add_elements([], %{}, [])
      []
      iex> PorticoConnector.maybe_add_elements([{:element, "value"}], %{}, [])
      [{:element, "value"}]
      iex> PorticoConnector.maybe_add_elements([], %{key: "term"}, [])
      []
      iex> PorticoConnector.maybe_add_elements([], %{key: "term"}, [key: :TagName])
      [{:TagName, ['term']}]
      iex> PorticoConnector.maybe_add_elements([{:element, "value"}], %{key: "term"}, [key: :TagName])
      [{:TagName, ['term']}, {:element, "value"}]

  """
  def maybe_add_elements(elements, container, key_map) when is_map(container) or is_map(container) do
    Enum.reduce(key_map, elements, fn ({key, tag}, acc) ->
      case Access.fetch(container, key) do
        :error -> acc
        {:ok, term} -> [{tag, [to_charlist(term)]} | acc]
      end
    end)
  end
  def maybe_add_elements(elements, nil, _key_map), do: elements
end
