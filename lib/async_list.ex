defmodule AsyncList do

  defmodule Result do
    def success(term), do: {:ok, term}
    def failure(term), do: {:error, term}
  end

  defmodule WebClient do
    def download_string(uri) do
      case HTTPoison.get(uri.host) do
        {:ok, response} ->
          Result.success(response.body)
        {:error, error} ->
          Result.failure(error.reason)
      end
    end
  end

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

    def new(uri, html) do
      struct!(__MODULE__, value: {uri, html})
    end
  end

  defmodule UriContentSize do
    # type UriContentSize = UriContentSize of System.Uri * int
    use TypedStruct

    typedstruct do
      field :value, {SystemURI, non_neg_integer}, enforce: true
    end
  end

  defmodule Async do
    use TypedStruct

    typedstruct do
      field :value, (... -> any), enforce: true
    end

    def run_synchronously(async) do
      async.value.()
    end

    def map(xasync, f) do
      Async.return(fn ->
        # get the contents of xasync
        x = xasync.fun.()
        # apply the function and lift the result
        f.(x)
      end)
    end

    def return(x) do
      # lift x to an Async
      struct!(__MODULE__, value: x)
    end

    def apply(fasync, xasync) do
      Async.return(fn ->
        # start the two asyncs in parallel
        fchild = Task.async(fasync)
        xchild = Task.async(xasync)

        # wait for the results
        f = Task.await(fchild)
        x = Task.await(xchild)

        # apply the function to the results
        return f.(x)
      end)
    end

    def bind(xasync, f) do
      # get the contents of xAsync
      x = xasync
      # apply the function but don't lift the result
      # as f will return an Async
      f.(x)
    end
  end

  import ExPrintf

  # Get the contents of the page at the given Uri
  @spec get_uri_content(SystemUri.t) :: Task.t
  def get_uri_content(uri) do
    Async.return(fn ->
      printf "[%s] Started ...\n", [uri.host]
      with {:ok, html} <- WebClient.download_string(uri) do
        printf "[%s] ... finished\n", [uri.host]
        uri_content = UriContent.new(uri, html)
        Result.success(uri_content)
      end
    end)
  end

  def show_content_result(result) do
    case result do
      {:ok, %{value: {uri, html}}} ->
        printf "SUCCESS: [%s] First 100 chars: %s\n", [uri.host, (String.slice(html, 0, 100))]
      {:error, errors} ->
        printf "FAILURE: %s\n", [errors]
    end
  end

  def try_happy do
    "http://google.com"
    |> SystemUri.new()
    |> get_uri_content()
    |> Async.run_synchronously
    |> show_content_result
  end

  def try_bad do
    "http://example.bad"
    |> SystemUri.new()
    |> get_uri_content()
    |> Async.run_synchronously
    |> show_content_result
  end
end
