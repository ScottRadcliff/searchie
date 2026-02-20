defmodule Searchie do
  @moduledoc """
  Search utilities for finding matching lines in text files.
  """

  @type modifier :: {String.t(), String.t() | true}
  @type result :: %{matches: [String.t()], modifiers: [modifier()]}

  @doc """
  Filters `path` for lines containing `query`.

  Supports both files and directories. Directory searches are recursive and
  return lines formatted as `path:line`. If `query` is wrapped in `/.../`,
  it is treated as a regular expression.
  """
  @spec filter(Path.t(), String.t(), [modifier()]) ::
          {:ok, result()} | {:error, :enoent | :unsupported_path | :invalid_regex}
  def filter(path, query, modifiers \\ []) when is_binary(path) and is_binary(query) do
    with {:ok, matcher} <- build_matcher(query) do
      case File.stat(path) do
        {:ok, %File.Stat{type: :regular}} ->
          {:ok, %{matches: file_matches(path, matcher), modifiers: modifiers}}

        {:ok, %File.Stat{type: :directory}} ->
          {:ok, %{matches: directory_matches(path, matcher), modifiers: modifiers}}

        {:ok, _other} ->
          {:error, :unsupported_path}

        {:error, :enoent} ->
          {:error, :enoent}
      end
    end
  end

  defp file_matches(file_path, matcher) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: false)
        |> Enum.filter(matcher)

      {:error, _reason} ->
        []
    end
  end

  defp directory_matches(directory_path, matcher) do
    directory_path
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.flat_map(fn file_path ->
      file_path
      |> file_matches(matcher)
      |> Enum.map(fn line -> "#{file_path}:#{line}" end)
    end)
  end

  defp build_matcher(query) do
    case parse_regex_query(query) do
      {:regex, pattern} ->
        case Regex.compile(pattern) do
          {:ok, regex} -> {:ok, &Regex.match?(regex, &1)}
          {:error, _reason} -> {:error, :invalid_regex}
        end

      :literal ->
        {:ok, &String.contains?(&1, query)}
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
