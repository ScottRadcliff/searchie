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
              render_matches(matches, path, query, modifiers)
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

  defp render_matches(matches, path, query, modifiers) do
    context = context_size(modifiers)

    if context == 0 do
      render_simple_matches(matches, path, query, modifiers)
    else
      render_matches_with_context(matches, query, modifiers, context)
    end
  end

  defp render_simple_matches(matches, path, query, modifiers) do
    if File.regular?(path) do
      Enum.each(matches, fn match ->
        maybe_colorize_line(match.line_text, query, modifiers)
        |> Mix.shell().info()
      end)
    else
      Enum.each(matches, fn match ->
        line = maybe_colorize_line(match.line_text, query, modifiers)
        Mix.shell().info("#{match.file_path}:#{line}")
      end)
    end
  end

  defp render_matches_with_context(matches, query, modifiers, context) do
    file_cache = load_file_cache(matches)

    matches
    |> Enum.with_index(1)
    |> Enum.each(fn {match, index} ->
      Mix.shell().info("[#{index}] #{match.file_path}:#{match.line_number}")

      file_cache
      |> Map.fetch!(match.file_path)
      |> surrounding_lines(match.line_number, context)
      |> Enum.each(fn {line_number, text} ->
        marker = if line_number == match.line_number, do: ">", else: " "

        line =
          maybe_colorize_context_line(text, query, modifiers, line_number == match.line_number)

        Mix.shell().info("#{marker} #{line_number}: #{line}")
      end)
    end)
  end

  defp load_file_cache(matches) do
    matches
    |> Enum.map(& &1.file_path)
    |> Enum.uniq()
    |> Enum.reduce(%{}, fn file_path, acc ->
      lines =
        case File.read(file_path) do
          {:ok, content} -> String.split(content, "\n", trim: false)
          {:error, _reason} -> []
        end

      Map.put(acc, file_path, lines)
    end)
  end

  defp surrounding_lines(lines, center_line, context) do
    start_line = max(1, center_line - context)
    end_line = min(length(lines), center_line + context)

    start_line..end_line
    |> Enum.map(fn line_number ->
      {line_number, Enum.at(lines, line_number - 1)}
    end)
  end

  defp maybe_colorize_context_line(line, query, modifiers, true) do
    maybe_colorize_line(line, query, modifiers)
  end

  defp maybe_colorize_context_line(line, _query, _modifiers, false), do: line

  defp maybe_colorize_line(line, query, modifiers) do
    case color_from_modifiers(modifiers) do
      nil -> line
      color -> apply_color(line, query, color)
    end
  end

  defp apply_color(line, query, color) do
    case parse_regex_query(query) do
      {:regex, pattern} ->
        case Regex.compile(pattern) do
          {:ok, regex} ->
            Regex.replace(regex, line, fn match ->
              IO.ANSI.format([color, match, :reset], true) |> IO.iodata_to_binary()
            end)

          {:error, _reason} ->
            line
        end

      :literal ->
        colored_query = IO.ANSI.format([color, query, :reset], true) |> IO.iodata_to_binary()
        String.replace(line, query, colored_query)
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

  defp context_size(modifiers) do
    case modifiers |> Enum.filter(fn {name, _value} -> name == "context" end) |> List.last() do
      nil ->
        0

      {"context", true} ->
        Mix.raise("context modifier requires a number, e.g. --modifier context=2")

      {"context", value} ->
        case Integer.parse(value) do
          {number, ""} when number >= 0 ->
            number

          _ ->
            Mix.raise("context modifier must be a non-negative integer: #{value}")
        end
    end
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
