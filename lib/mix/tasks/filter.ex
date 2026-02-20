defmodule Mix.Tasks.Filter do
  @moduledoc """
  Search a file or directory for matching lines.

  Usage:

      mix filter PATH QUERY [--modifier key=value]...
  """

  use Mix.Task

  @shortdoc "Filters a file by a query string"
  @supported_colors %{
    "black" => :black,
    "red" => :red,
    "green" => :green,
    "yellow" => :yellow,
    "blue" => :blue,
    "magenta" => :magenta,
    "cyan" => :cyan,
    "white" => :white
  }

  @impl Mix.Task
  def run(args) do
    case parse_args(args) do
      {:ok, path, query, modifiers} ->
        case Searchie.filter(path, query, modifiers) do
          {:ok, %{matches: matches}} ->
            if count_enabled?(modifiers) do
              Mix.shell().info(Integer.to_string(length(matches)))
            else
              matches
              |> maybe_colorize_matches(query, modifiers)
              |> Enum.each(&Mix.shell().info/1)
            end

          {:error, :enoent} ->
            Mix.raise("Path not found: #{path}")

          {:error, :unsupported_path} ->
            Mix.raise("Unsupported path type: #{path}")

          {:error, :invalid_regex} ->
            Mix.raise("Invalid regex query: #{query}")
        end

      {:error, message} ->
        Mix.raise(message)
    end
  end

  defp parse_args(args) do
    {opts, positional, invalid} = OptionParser.parse(args, strict: [modifier: :keep])

    cond do
      invalid != [] ->
        {:error, "Invalid options: #{inspect(invalid)}"}

      length(positional) < 2 ->
        {:error, "Usage: mix filter PATH QUERY [--modifier key=value]..."}

      true ->
        [path, query | _] = positional
        modifiers = parse_modifiers(Keyword.get_values(opts, :modifier))
        {:ok, path, query, modifiers}
    end
  end

  defp parse_modifiers(values) do
    Enum.map(values, fn value ->
      case String.split(value, "=", parts: 2) do
        [key, val] when key != "" and val != "" -> {key, val}
        [flag] when flag != "" -> {flag, true}
        _ -> Mix.raise("Invalid modifier format: #{value}")
      end
    end)
  end

  defp maybe_colorize_matches(matches, query, modifiers) do
    case color_from_modifiers(modifiers) do
      nil ->
        matches

      color ->
        apply_color(matches, query, color)
    end
  end

  defp apply_color(matches, query, color) do
    case parse_regex_query(query) do
      {:regex, pattern} ->
        case Regex.compile(pattern) do
          {:ok, regex} ->
            Enum.map(matches, fn line ->
              Regex.replace(regex, line, fn match ->
                IO.ANSI.format([color, match, :reset], true) |> IO.iodata_to_binary()
              end)
            end)

          {:error, _reason} ->
            matches
        end

      :literal ->
        colored_query = IO.ANSI.format([color, query, :reset], true) |> IO.iodata_to_binary()
        Enum.map(matches, &String.replace(&1, query, colored_query))
    end
  end

  defp color_from_modifiers(modifiers) do
    case Enum.find(modifiers, fn {name, _value} -> name == "color" end) do
      nil ->
        nil

      {"color", true} ->
        :yellow

      {"color", value} when is_binary(value) ->
        case Map.fetch(@supported_colors, String.downcase(value)) do
          {:ok, color} -> color
          :error -> Mix.raise("Unsupported color modifier: #{value}")
        end
    end
  end

  defp count_enabled?(modifiers) do
    Enum.any?(modifiers, fn {name, _value} -> name == "count" end)
  end

  defp parse_regex_query(query) do
    if String.length(query) >= 2 and String.starts_with?(query, "/") and
         String.ends_with?(query, "/") do
      pattern = String.slice(query, 1, String.length(query) - 2)
      {:regex, pattern}
    else
      :literal
    end
  end
end
