defmodule AsyncList do
  defmodule SystemUri do
    use TypedStruct

    typedstruct do
      field :host, String.t, enforce: true
    end

    def new(host), do: struct!(__MODULE__, host: host)
  end

  defmodule UriContent do
    # type UriContent = UriContent of System.Uri * string
    use TypedStruct

    typedstruct do
      field :value, {SystemURI, String.t}, enforce: true
    end
  end

  defmodule UriContentSize do
    # type UriContentSize = UriContentSize of System.Uri * int
    use TypedStruct

    typedstruct do
      field :value, {SystemURI, non_neg_integer}, enforce: true
    end
  end

  # Get the contents of the page at the given Uri
  @spec get_uri_content(SystemUri.t) :: Task.t
  def get_uri_content(uri) do
    import ExPrintf
     printf "[%s] Started ...", [uri.host]
  end

  def try do
    "http://google.com"
    |> SystemUri.new()
    |> get_uri_content()
  end
end
