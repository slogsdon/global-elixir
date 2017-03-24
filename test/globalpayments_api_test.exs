defmodule GlobalPayments.ApiTest do
  alias GlobalPayments.Api.Builders.AuthorizationBuilder
  alias GlobalPayments.Api.Gateways.PorticoConnector
  alias GlobalPayments.Api.Entities.Errors.UnsupportedTransactionError
  alias GlobalPayments.Api.PaymentMethods.CreditCardData

  use ExUnit.Case
  doctest GlobalPayments.Api
  doctest PorticoConnector
  doctest GlobalPayments.Api.Util.Xml

  setup do
    %{config: %{secret_api_key: "skapi_cert_MTyMAQBiHVEAewvIzXVFcmUd2UcyBge_eCpaASUp0A",
                service_url: "https://cert.api2.heartlandportico.com"}}
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
    response =
      card
      |> CreditCardData.charge()
      |> AuthorizationBuilder.with_amount("10")
      |> AuthorizationBuilder.with_currency("USD")
      |> AuthorizationBuilder.execute(config)

    refute response == nil
    assert response.response_code == "00"
  end
end
