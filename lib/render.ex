
defmodule Helixir.Render do

  defmacro __using__(opts) when is_list(opts) do
    quote bind_quoted: [ opts: opts ] do

      blank_layout = EEx.compile_string("<%= @__template__ %>")

      @compiled_layout (
        cond do
          Keyword.has_key?(opts, :layout) ->
            cond do
              opts[:layout] ->
                EEx.compile_file(opts[:layout])
              true ->
                blank_layout
            end
          true ->
            blank_layout
        end
      )

      @compiled_templates (
        Enum.reduce [ "get", "post" ], %{}, fn(method, acc) ->
          file = Path.dirname(__ENV__.file) <> "/#{ method }.html.eex"
          template = cond do
            File.exists?(file) ->
              EEx.compile_file(file)
            true ->
              EEx.compile_string("")
          end
          Map.put(acc, String.upcase(method), template)
        end
      )

      defp render conn, context \\ [] do
        assigns = cond do
          Keyword.keyword?(context) ->
            context
          true ->
            Keyword.new context, fn
              { k, v } when is_atom(k) -> { k, v }
              { k, v } -> { String.to_existing_atom(k), v }
            end
        end
        {template, _} = Code.eval_quoted(@compiled_templates[conn.method], assigns: assigns)
        {content, _} = Code.eval_quoted(@compiled_layout, assigns: assigns ++ [__template__: template])
        send_resp(conn, 200, content)
      end
    end
  end
end
