defmodule AsyncList.AsyncTest do
  use ExUnit.Case

  alias AsyncList.Async

  test "returing" do
    x_async = Async.return(fn -> 10 end)
    result = Async.run_synchronously(x_async)
    assert result == 10
  end

  test "mapping" do
    x_async = Async.return(fn -> 10 end)
    f = fn(x) -> x * 2 end

    mapped_async = Async.map(x_async, f)

    result = Async.run_synchronously(mapped_async)
    assert result == 20
  end

  test "applying to one arg" do
    x_async = Async.return(fn -> 10 end)
    f_async = Async.return(fn(a) -> a * 2 end)

    applied_to_x = Async.ap(x_async, f_async)

    result = Async.run_synchronously(applied_to_x)
    assert result == 20
  end

  test "applying to two args" do
    x_async = Async.return(fn -> 10 end)
    y_async = Async.return(fn -> 2 end)
    f_async = Async.return(fn(a, b) -> a * b end)

    applied_to_x = Async.ap(x_async, f_async)
    applied_to_y = Async.ap(y_async, applied_to_x)

    result = Async.run_synchronously(applied_to_y)
    assert result == 20
  end

  test "binding" do
    x_async = Async.return(fn -> 10 end)
    f = fn(x) -> Async.return(fn -> x * 2 end) end

    binded_async = Async.bind(x_async, f)

    result = Async.run_synchronously(binded_async)
    assert result == 20
  end
end
