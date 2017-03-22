defmodule GlobalPayments.ApiTest do
  use ExUnit.Case
  doctest GlobalPayments.Api
  doctest GlobalPayments.Api.Gateways.PorticoConnector

  alias GlobalPayments.Api.Builders.AuthorizationBuilder
  alias GlobalPayments.Api.Gateways.PorticoConnector
  alias GlobalPayments.Api.Gateways.PorticoConnector.UnsupportedTransactionError
  alias GlobalPayments.Api.PaymentMethods.CreditCardData

  defmodule XmlNode do
    require Record
    import Record, only: [defrecord: 2, extract: 2]

    @hrl "xmerl/include/xmerl.hrl"

    # XML
    defrecord :xmlAttribute, extract(:xmlAttribute, from_lib: @hrl)
    defrecord :xmlComment, extract(:xmlComment, from_lib: @hrl)
    defrecord :xmlDecl, extract(:xmlDecl, from_lib: @hrl)
    defrecord :xmlDocument, extract(:xmlDocument, from_lib: @hrl)
    defrecord :xmlElement, extract(:xmlElement, from_lib: @hrl)
    defrecord :xmlNamespace, extract(:xmlNamespace, from_lib: @hrl)
    defrecord :xmlNsNode, extract(:xmlNsNode, from_lib: @hrl)
    defrecord :xmlPI, extract(:xmlPI, from_lib: @hrl)
    defrecord :xmlText, extract(:xmlText, from_lib: @hrl)

    # XPATH
    defrecord :xmlContext, extract(:xmlContext, from_lib: @hrl)
    defrecord :xmlNode, extract(:xmlNode, from_lib: @hrl)
    defrecord :xmlObj, extract(:xmlObj, from_lib: @hrl)
  end

  setup do
    %{config: %{secret_api_key: "secret api key"}}
  end

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "xml", %{config: config} do
    assert_raise UnsupportedTransactionError, fn ->
      struct(AuthorizationBuilder) # transaction
      |> PorticoConnector.process_authorization(config)
    end
  end

  test "builder", %{config: config} do
    card = struct(CreditCardData,
      number: "4111111111111111",
      exp_month: "12",
      exp_year: "2025",
      cvn: "123")
    _response =
      card
      |> CreditCardData.charge()
      |> AuthorizationBuilder.with_amount("10")
      |> AuthorizationBuilder.with_currency("USD")
      |> AuthorizationBuilder.execute(config)
      |> IO.puts
    assert 1 + 1 == 2
  end
end
