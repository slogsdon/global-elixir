defmodule GlobalPayments.Api.Util.Xml.Nodes do
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

defmodule GlobalPayments.Api.Util.Xml do
  import GlobalPayments.Api.Util.Xml.Nodes

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

  @doc """
  Adds terms from `container` to `elements` when a term's key is present in `key_map`

  ## Examples

      iex> alias GlobalPayments.Api.Util.Xml
      iex> Xml.maybe_add_elements([], %{}, [])
      []
      iex> Xml.maybe_add_elements([{:element, "value"}], %{}, [])
      [{:element, "value"}]
      iex> Xml.maybe_add_elements([], %{key: "term"}, [])
      []
      iex> Xml.maybe_add_elements([], %{key: "term"}, [key: :TagName])
      [{:TagName, ['term']}]
      iex> Xml.maybe_add_elements([{:element, "value"}], %{key: "term"}, [key: :TagName])
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
