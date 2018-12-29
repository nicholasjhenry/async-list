defmodule AsyncList do

  defmodule Result do
    @type t(term) :: {:ok, term} :: {:error, term}

    def success(term), do: {:ok, term}
    def failure(term), do: {:error, term}

    def bind(result, fun) do
      case result do
        {:ok, term} ->
          fun.(term)
        other -> other
      end
    end
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

    def new(uri, len) do
      struct!(__MODULE__, value: {uri, len})
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
        x = xasync.value.()
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
      x = xasync.value
      # apply the function but don't lift the result
      # as f will return an Async
      f.(x)
    end
  end

  import ExPrintf

  # Get the contents of the page at the given Uri
  @spec get_uri_content(SystemUri.t) :: Async.t
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

  # Make a UriContentSize from a UriContent
  @spec make_content_size(UriContent.t) :: Result.t(UriContentSize.t)
  def make_content_size(%UriContent{value: {uri, html}}) do
    if is_nil(html) do
      Result.failure(["empty page"])
    else
      uri_content_size = UriContentSize.new(uri, String.length(html))
      Result.success(uri_content_size)
    end
  end

  # Get the size of the contents of the page at the given Uri
  @spec get_uri_content_size(SystemUri.t) :: Async.t(Result.t(UriContentSize.t))
  def get_uri_content_size(uri) do
    uri
    |> get_uri_content
    |> Async.map(bind_result(&make_content_size/1))
  end

  defp bind_result(fun) do
    fn(result) -> Result.bind(result, fun) end
  end

  def show_content_result(result) do
    case result do
      {:ok, %{value: {uri, html}}} ->
        printf "SUCCESS: [%s] First 100 chars: %s\n", [uri.host, (String.slice(html, 0, 100))]
      {:error, errors} ->
        printf "FAILURE: %s\n", [errors]
    end
  end

  def show_content_size_result(result) do
    case result do
      {:ok, %{value: {uri, len}}} ->
        printf "SUCCESS: [%s] Content size is %i\n", [uri.host, len]
      {:error, errors} ->
        printf "FAILURE: %s\n", [errors]
    end
  end

  def try_happy do
    "http://google.com"
    |> SystemUri.new()
    |> get_uri_content_size
    |> Async.run_synchronously
    |> show_content_size_result
  end

  def try_bad do
    "http://example.bad"
    |> SystemUri.new()
    |> get_uri_content_size
    |> Async.run_synchronously
    |> show_content_size_result
  end
end
