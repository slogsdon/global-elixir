defmodule GlobalPayments.Api.Builders.AuthorizationBuilder do
  @behaviour GlobalPayments.Api.Builders.Validations
  @behaviour Access
  alias GlobalPayments.Api.Gateways.PorticoConnector.TransactionType
  use Bitwise, only_operators: true

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

  defmodule Validations do
    @behaviour Access

    defstruct rules: [],
              current: nil

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

  defmodule ValidationTarget do
    defstruct parent: nil,
              type: nil,
              property: nil,
              clause: nil,
              constraint: nil,
              constraint_property: nil,
              enum_name: nil
  end

  defmodule ValidationClause do
    defstruct parent: nil,
              target: nil,
              callback: nil,
              message: nil
  end

  def validations() do
    of(:transaction_type, [
      TransactionType.Auth,
      TransactionType.Sale,
      TransactionType.Refund,
      TransactionType.AddValue
    ])
    |> check(:amount, &not_nil?/1)
    |> check(:currency, &not_nil?/1)
    |> check(:payment_method, &not_nil?/1)

    |> of(:transaction_type, [
      TransactionType.Auth,
      TransactionType.Sale
    ])
    |> constrained_by(:transaction_modifier, TransactionModifier.Offline)
    |> check(:amount, &not_nil?/1)
    |> check(:currency, &not_nil?/1)
    |> check(:offline_auth_code, &not_nil?/1)
    |> check(:offline_auth_code, &not_empty?/1)
  end

  def of(property, values) do
    of(
      struct(Validations,
        current: nil
      ),
      property,
      values
    )
  end
  def of(%Validations{current: nil} = validations, property, values) do
    target =
      struct(ValidationTarget,
        enum_name: property,
        type: Enum.reduce(values, 0, fn (v, acc) ->
          acc ||| apply(v, :value, [])
        end)
      )
    Map.put(validations, :current, target)
  end
  def of(%Validations{} = validations, property, values) do
    validations
    |> Map.put(:current, nil)
    |> of(property, values)
  end

  def constrained_by(%Validations{} = validations, property, value) do
    update_in(validations.current, &(
      &1
      |> Map.put(:constraint_property, property)
      |> Map.put(:constraint, value)
    ))
  end

  def check(%Validations{} = validations, property, callback) do
    validations
    |> Map.update!(:current, fn target ->
      t = Map.put(target, :property, property)
      Map.put(t, :clause, callback.(t))
    end)
    |> Map.update!(:rules, &([validations.current | &1]))
  end

  def not_nil?(target) do
    callback =
      fn builder ->
        value = builder[target.property]
        value != nil
      end
    struct(ValidationClause,
      message: "#{target.property |> to_string()} cannot be null",
      callback: callback
    )
  end

  def not_empty?(target) do
    callback =
      fn builder ->
        value = builder[target.property]
        case value do
          v when is_map(v)
              or is_list(v) -> !Enum.empty?(v)
          v when is_binary(v) -> v != ""
          _ -> false
        end
      end
    struct(ValidationClause,
      message: "#{target.property |> inspect()} cannot be empty",
      callback: callback
    )
  end

  def validate!(builder, validations) do
    validations.rules
    |> Enum.map(fn validation ->
      value = builder[validation.enum_name]
      value =
        if value == nil and Map.has_key?(builder, :payment_method) do
          builder.payment_method[validation.enum_name].value
        else
          value.value
        end

      enum_value = validation.type
      constraint = validation.constraint
      constraint_value = builder[validation.constraint_property]
      clause = validation.clause

      cond do
        is_nil(value) ->
          nil
        (enum_value &&& value) != value ->
          nil
        is_nil(clause) ->
          nil
        not is_nil(constraint) and constraint != constraint_value ->
          nil
        true ->
          unless validation.clause.callback.(builder) do
            raise ArgumentError, message: validation.clause.message
          end
      end
    end)
    builder
  end

  def execute(%__MODULE__{} = builder, config) do
    builder
    |> validate!(validations())
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
