defmodule GlobalPayments.Api.Gateways.XmlGateway do
  use Tesla

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

  defmodule GatewayError do
    defexception message: nil
  end

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