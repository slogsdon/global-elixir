defmodule GlobalPayments.Api.Gateways.XmlGateway do
  use Tesla
  alias GlobalPayments.Api.Entities.Errors.GatewayError

  plug Tesla.Middleware.DebugLogger
  plug Tesla.Middleware.FollowRedirects
  plug Tesla.Middleware.Headers, %{
    "Content-Type" => "text/xml; charset=\"utf-8\"",
    "SoapAction" => "\"\"",
  }

  def client(config) do
    Tesla.build_client [
      {Tesla.Middleware.BaseUrl, config.service_url}
    ]
  end

  def do_transaction(client, url, body) do
    response = post(client, url, body)

    unless response.status == 200 do
      raise GatewayError, message: "Unexpected gateway status code `#{response.status}`"
    end

    response.body
  end
end