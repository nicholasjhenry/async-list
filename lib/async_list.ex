defmodule AsyncList do

  defmodule Result do
    @type t(term) :: {:ok, term} :: {:error, term}

    use Currying

    def success(term), do: {:ok, term}
    def failure(term), do: {:error, term}

    def map(x_result, f) do
      case x_result do
        {:ok, x} ->
          success(curry(f).(x))
        {:error, errors} ->
          failure(errors)
        end
    end

    def f <|> x_result do
       map(x_result, f)
     end

    def return(x) do
      success(x)
    end

    def ap(x_result, f_result) do
      case {f_result, x_result} do
        {{:ok, f}, {:ok, x}} ->
          return(curry(f).(x))
        {{:error, errs}, {:ok, _x}} ->
          failure(errs)
        {{:ok, _f}, {:error, errs}} ->
          failure(errs)
        {{:error, errs_1}, {:error, errs_2}} ->
          failure(Enum.concat(List.wrap(errs_1), List.wrap(errs_2)))
      end
    end

    def result_f <<~ result_x, do: ap(result_x, result_f)

    def bind(result_x, f) do
      case result_x do
        {:ok, x} ->
          curry(f).(x)
        {:error, errs} ->
          failure(errs)
      end
    end

    def result_x >>> f, do: bind(result_x, f)
  end

  defmodule WebClient do
    def download_string(uri) do
      case HTTPoison.get(uri.host) do
        {:ok, response} ->
          Result.success(response.body)
        {:error, error} ->
          Result.failure("#{uri.host} => #{error.reason}")
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
    use Currying

    typedstruct do
      field :value, (... -> any), enforce: true
    end

    def run_synchronously(async) do
      async.value.()
    end

    def map(x_async, f) do
      return(fn ->
        # get the contents of x_async (i.e. run it and await the result)
        x = run_synchronously(x_async)

        # apply the function and lift the result
        f.(x)
      end)
    end

    def return(x) when is_function(x) do
      # lift x to an Async
      struct!(__MODULE__, value: x)
    end

    def return(x) do
      # lift x to an Async
      struct!(__MODULE__, value: fn -> x end)
    end

    def ap(x_async, f_async) do
      import Task, only: [await: 1]

      return(fn ->
        x_child = start_child(x_async)
        f_child = start_child(f_async)

        x = await(x_child)
        f = await(f_child)

        f.(x)
      end)
    end

    defp start_child(async) do
      async |> get_fun |> Task.async()
    end

    # Gets the function from Async.t. If the function has an arity of 0 then the function
    # can be passed directly to Task. If not, then wrap it inside of a function/0 so it
    # can be passed to Task. As well, ensure the function is curried so it can be
    # partially applied.
    defp get_fun(%{value: f}) when is_function(f, 0), do: f
    defp get_fun(%{value: f}), do: fn -> curry(f) end

    def f_async <<~ x_async, do: ap(x_async, f_async)

    def bind(x_async, f) do
      # get the contents of xAsync
      x = run_synchronously(x_async)
      # apply the function but don't lift the result
      # as f will return an Async
      f.(x)
    end
  end

  defmodule List do
    @type a :: any
    @type b :: any

    def id(x), do: x

    # Map a Async producing function over a list to get a new Async
    # using applicative style
    @spec traverse_async_a([a], (a -> Async.t(b))) :: Async.t([b])
    def traverse_async_a(list, f) do
      use Currying
      import Async, only: [return: 1, "<<~": 2]
      # right fold over the list
      init_state = return([])
      folder = fn(head, tail) -> return(&cons/2) <<~ f.(head) <<~ tail end

      Elixir.List.foldr(list, init_state, folder)
    end

    # Transform a "[Async.t]" into a "Async.t([...])"
    # and collect the results using apply.
    def sequence_async_a(x), do: traverse_async_a(x, &id/1)

    # Map a Async producing function over a list to get a new Async
    # using applicative style
    @spec traverse_result_a([a], (a -> Result.t(b))) :: Result.t([b])
    def traverse_result_a(list, f) do
      import Result, only: [return: 1, "<<~": 2]
      # right fold over the list
      init_state = return([])
      folder = fn(head, tail) -> return(&cons/2) <<~ f.(head) <<~ tail end

      Elixir.List.foldr(list, init_state, folder)
    end

    # Transform a "[Result.t]" into a "Result.t([...])"
    # and collect the results using apply.
    def sequence_result_a(x), do: traverse_result_a(x, &id/1)

    # define a "cons" function
    defp cons(head, tail), do: [head | tail]
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
        printf "FAILURE: %s\n", [Enum.join(Elixir.List.wrap(errors), ", ")]
    end
  end

  # Get the largest UriContentSize from a list
  @spec max_content_size(UriContentSize.t(list)) :: UriContentSize.t
  def max_content_size(list) do

    # extract the len field from a UriContentSize
    contentSize = fn %UriContentSize{value: {_, len}} -> len end

    # use maxBy to find the largest
    list |> Enum.max_by(contentSize)
  end

  # Get the largest page size from a list of websites
  def largest_page_size_a(urls) do
    urls
    # turn the list of strings into a list of Uris
    |> Enum.map(&SystemUri.new/1)

    # turn the list of Uris into a "[Async.t(Result.t(UriContentSize.t))]"
    |> Enum.map(&get_uri_content_size/1)

    # turn the "[Async.t(Result.t(UriContentSize.t))]"
    # into an "Async.t([Result.t(UriContentSize.t)])"
    |> List.sequence_async_a

    # turn the "Async.t([Result.t(UriContentSize.t)])"
    # into a "Async.t(Result.t([UriContentSize.t]))"
    |> Async.map(&List.sequence_result_a/1)

    # find the largest in the inner list to get
    # a "Async.t(Result.t(UriContentSize.t))"
    |> Async.map(map_result(&max_content_size/1))
  end

  defp map_result(f) do
    fn(x) -> Result.map(x, f) end
  end

  def try_happy do
    [
      "http://google.com",
      "http://bbc.co.uk",
      "http://fsharp.org",
      "http://microsoft.com"
    ]
    |> largest_page_size_a
    |> Async.run_synchronously
    |> show_content_size_result
  end

  def try_bad do
    [
      "http://example.com/nopage",
      "http://bad.example.com",
      "http://verybad.example.com",
      "http://veryverybad.example.com"
    ]
    |> largest_page_size_a
    |> Async.run_synchronously
    |> show_content_size_result
  end
end
