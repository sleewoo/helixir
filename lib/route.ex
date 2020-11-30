
defmodule Helixir.Route do

  defmacro __using__(opts) when is_list(opts) do
    quote bind_quoted: [ opts: opts ] do

      blank_layout = EEx.compile_string("<%= @__template__ %>")

      @compiled_layout (
        case Keyword.has_key?(opts, :layout) do
          true ->
            case layout = opts[:layout] do
              true ->
                EEx.compile_file(layout)
              false ->
                blank_layout
            end
          false ->
            blank_layout
        end
      )

      @compiled_templates (
        Enum.reduce [ "get", "head", "post", "put", "patch", "delete", "options" ], %{}, fn(method, acc) ->
          file = Path.dirname(__ENV__.file) <> "/#{ method }.html.eex"
          template = case File.exists?(file) do
            true ->
              EEx.compile_file(file)
            false ->
              EEx.compile_string("")
          end
          Map.put(acc, String.upcase(method), template)
        end
      )

      defp render(conn, context \\ []) do
        assigns = case Keyword.keyword?(context) do
          true ->
            context
          false ->
            Keyword.new context, fn
              { k, v } when is_atom(k) -> { k, v }
              { k, v } -> { String.to_existing_atom(k), v }
            end
        end
        {template, _} = Code.eval_quoted(@compiled_templates[conn.method], assigns: assigns)
        {content, _} = Code.eval_quoted(@compiled_layout, assigns: assigns ++ [__template__: template])
        conn |> put_resp_content_type("text/html") |> send_resp(200, content)
      end

      defp send_json(conn, data) when data |> is_list do
        map = for {k,v} <- data, into: %{}, do: {k,v}
        conn |> send_json(map)
      end

      defp send_json(conn, data) when data |> is_map do
        conn |> send_json(data |> Jason.encode)
      end

      defp send_json(conn, {:ok, json}) when json |> is_binary do
        conn |> send_json(json)
      end

      defp send_json(conn, json) when json |> is_binary do
        conn |> put_resp_content_type("application/json") |> send_resp(200, json)
      end

    end
  end
end
