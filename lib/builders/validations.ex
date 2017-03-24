defmodule GlobalPayments.Api.Builders.Validations do
  use Bitwise, only_operators: true

  @callback validations() :: Map.t

  defmodule Validations do
    @behaviour Access
    use GlobalPayments.Api.Util.Accessible

    defstruct rules: [],
              current: nil
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
    Enum.map(validations.rules, fn validation ->
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
  end
end
