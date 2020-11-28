
defmodule Helixir.Router do

  defmacro __using__(opts) when is_list(opts) do

    if !opts[:root] do
      raise "Please provide :root"
    end

    root = Path.join(File.cwd!, opts[:root])

    if !File.dir?(root) do
      raise "Given :root does not exists or is not a directory"
    end

    if root == File.cwd! do
      raise "Given :root should be a sub-folder of #{ File.cwd! }"
    end

    quote bind_quoted: [
      root: root,
      original_root: opts[:root],
      mountpoint: opts[:mountpoint] || "",
      request_methods: [ :get, :head, :post, :put, :patch, :delete, :options ],
    ] do

      path_filter = fn(path) ->
        !Regex.match?(~r|/_|, path)
      end

      endpoints_reducer = fn({ method, _, defs }, acc) ->
        cond do
          method in request_methods ->
            [ params, _ ] = defs
            [
              [
                method |> Atom.to_string |> String.upcase,
                String.replace(params, ~r|^/+|, ""),
              ] | acc
            ]
          true ->
            acc
        end
      end

      module_loader = fn(file) ->

        {{:module, module, _, _}, _} = Code.eval_file(file)

        {:ok, ast} = file
        |> File.read!
        |> Code.string_to_quoted

        {:defmodule, _, [_, [ do: {:__block__, _, defs} ]]} = ast

        path = String.replace(file, ~r/#{ root }|((\/index)+)?\.ex$/, "")
        endpoints = defs |> Enum.reduce([], endpoints_reducer)

        longest_method_sorter = fn([ method, _ ]) -> String.length(method) end
        longest_params_sorter = fn([ _, params ]) -> String.length(path <> params) end

        [[ longest_method, _ ] | _] = endpoints |> Enum.sort_by(longest_method_sorter, :desc)
        [[ _, longest_params ] | _] = endpoints |> Enum.sort_by(longest_params_sorter, :desc)

        %{
          module: module,
          path: path,
          endpoints: endpoints,
          weight: length(Regex.scan(~r|/|, path)),
          longest_method: String.length(longest_method),
          longest_endpoint: String.length(path <> longest_params),
          longest_module: String.length(inspect(module))
        }
      end

      module_mounter = fn(%{ path: path, endpoints: endpoints, module: module }) ->
        match mountpoint <> path <> "/*glob", to: module, private: %{ module: module } do
          Plug.forward(var!(conn), var!(glob), var!(conn).private.module, [])
        end
      end

      IO.puts("")
      IO.puts("Mounting routes from #{ IO.ANSI.cyan <> original_root <> IO.ANSI.reset }")

      modules = Path.wildcard("#{ root }/**/*.ex*")
      |> Enum.filter(path_filter)
      |> Enum.map(module_loader)
      |> Enum.sort_by(& &1[:weight], :desc)

      [%{ longest_method: longest_method } | _] = modules |> Enum.sort_by(& &1[:longest_method], :desc)
      [%{ longest_endpoint: longest_endpoint } | _] = modules |> Enum.sort_by(& &1[:longest_endpoint], :desc)
      [%{ longest_module: longest_module } | _] = modules |> Enum.sort_by(& &1[:longest_module], :desc)

      for %{ path: path, endpoints: endpoints, module: module } <- modules do

        head = if mountpoint <> path == "" do
          "/"
        else
          mountpoint <> path
        end

        for [ method, params ] <- endpoints do

          path = if params == "" do
            head <> IO.ANSI.magenta <> IO.ANSI.reset
          else
            Path.join(head, IO.ANSI.magenta <> params <> IO.ANSI.reset)
          end

          IO.write("› " <> IO.ANSI.green <> IO.ANSI.italic <> String.pad_leading(method, longest_method) <> IO.ANSI.reset <> " ")
          IO.write(String.pad_trailing(path, longest_endpoint + 20, "·"))
          IO.puts("[ " <> IO.ANSI.blue <> String.pad_trailing(inspect(module), longest_module) <> IO.ANSI.reset <> " ]")
        end
      end

      IO.puts("")

      modules |> Enum.map(module_mounter)
    end
  end
end
