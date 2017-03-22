defmodule GlobalPayments.Api.Builders.AuthorizationBuilder do
  defstruct address: nil,
            alias: nil,
            alias_action: nil,
            allow_partial_auth: nil,
            amount: nil,
            cash_back_amount: nil,
            currency: nil,
            customer_id: nil,
            description: nil,
            dynamic_descriptor: nil,
            gratuity: nil,
            invoice_number: nil,
            level_2_request: nil,
            offline_auth_code: nil,
            order_id: nil,
            request_multi_use_token: nil,
            balance_inquiry_type: nil,
            replacement_card: nil,
            payment_method: nil,
            transaction_type: nil,
            transaction_modifier: nil

  def execute(%__MODULE__{} = builder, config) do
    builder
    |> GlobalPayments.Api.Gateways.PorticoConnector.process_authorization(config)
  end

  def with_payment_method(%__MODULE__{} = builder, payment_method) do
    %{builder | payment_method: payment_method}
  end

  def with_address(%__MODULE__{} = builder, address) do
    %{builder | address: address}
  end

  def with_alias(%__MODULE__{} = builder, alias) do
    %{builder | alias: alias}
  end

  def with_alias_action(%__MODULE__{} = builder, alias_action) do
    %{builder | alias_action: alias_action}
  end

  def with_allow_partial_auth(%__MODULE__{} = builder, allow_partial_auth) do
    %{builder | allow_partial_auth: allow_partial_auth}
  end

  def with_amount(%__MODULE__{} = builder, amount) do
    %{builder | amount: amount}
  end

  def with_cash_back_amount(%__MODULE__{} = builder, cash_back_amount) do
    %{builder | cash_back_amount: cash_back_amount}
  end

  def with_currency(%__MODULE__{} = builder, currency) do
    %{builder | currency: currency}
  end

  def with_customer_id(%__MODULE__{} = builder, customer_id) do
    %{builder | customer_id: customer_id}
  end

  def with_description(%__MODULE__{} = builder, description) do
    %{builder | description: description}
  end

  def with_dynamic_descriptor(%__MODULE__{} = builder, dynamic_descriptor) do
    %{builder | dynamic_descriptor: dynamic_descriptor}
  end

  def with_gratuity(%__MODULE__{} = builder, gratuity) do
    %{builder | gratuity: gratuity}
  end

  def with_invoice_number(%__MODULE__{} = builder, invoice_number) do
    %{builder | invoice_number: invoice_number}
  end

  def with_commercial_request(%__MODULE__{} = builder, level_2_request) do
    %{builder | level_2_request: level_2_request}
  end

  def with_offline_auth_code(%__MODULE__{} = builder, offline_auth_code) do
    %{builder | offline_auth_code: offline_auth_code}
  end

  def with_order_id(%__MODULE__{} = builder, order_id) do
    %{builder | order_id: order_id}
  end

  def with_request_multi_use_token(%__MODULE__{} = builder, request_multi_use_token) do
    %{builder | request_multi_use_token: request_multi_use_token}
  end

  def with_balance_inquiry_type(%__MODULE__{} = builder, balance_inquiry_type) do
    %{builder | balance_inquiry_type: balance_inquiry_type}
  end

  def with_replacement_card(%__MODULE__{} = builder, replacement_card) do
    %{builder | replacement_card: replacement_card}
  end
end
