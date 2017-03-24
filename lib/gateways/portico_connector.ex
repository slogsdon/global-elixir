defmodule GlobalPayments.Api.Gateways.PorticoConnector do
  alias GlobalPayments.Api.Builders.AuthorizationBuilder
  alias GlobalPayments.Api.Entities.Enums.{PaymentMethodType, TransactionModifier, TransactionType}
  alias GlobalPayments.Api.Entities.Errors.{GatewayError, NotImplementedError, UnsupportedTransactionError}
  alias GlobalPayments.Api.Entities.Transaction
  alias GlobalPayments.Api.PaymentMethods.TransactionReference
  import GlobalPayments.Api.Gateways.XmlGateway
  import GlobalPayments.Api.Util.Xml

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
      iex> alias GlobalPayments.Api.Entities.Enums.{PaymentMethodType, TransactionType}
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
end
