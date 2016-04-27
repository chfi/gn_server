defmodule MySQLTest do
  use ExUnit.Case
  # doctest GnServer

  test "Test MySQL connection" do
    {:ok, pid} = Mysqlex.Connection.start_link(username: "test", database: "test", password: "test", hostname: "localhost")
    {:ok, result} = Mysqlex.Connection.query(pid, "SELECT title FROM posts", [])
    # rec = Map.from_struct(result)
    %Mysqlex.Result{rows: rows} = result
    IO.inspect(rows)
    nlist = Enum.map(rows, fn(x) -> {s} = x ; s end)
    IO.puts Poison.encode_to_iodata!(nlist)
    IO.puts Enum.join(nlist,"\n")
    true
  end
end
