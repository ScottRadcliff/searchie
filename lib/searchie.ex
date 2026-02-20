defmodule Searchie do
  @moduledoc """
  Search utilities for finding matching lines in text files.
  """

  @type modifier :: {String.t(), String.t() | true}
  @type result :: %{matches: [String.t()], modifiers: [modifier()]}

  @doc """
  Filters `path` for lines containing `query`.

  Supports both files and directories. Directory searches are recursive and
  return lines formatted as `path:line`.
  """
  @spec filter(Path.t(), String.t(), [modifier()]) ::
          {:ok, result()} | {:error, :enoent | :unsupported_path}
  def filter(path, query, modifiers \\ []) when is_binary(path) and is_binary(query) do
    case File.stat(path) do
      {:ok, %File.Stat{type: :regular}} ->
        {:ok, %{matches: file_matches(path, query), modifiers: modifiers}}

      {:ok, %File.Stat{type: :directory}} ->
        {:ok, %{matches: directory_matches(path, query), modifiers: modifiers}}

      {:ok, _other} ->
        {:error, :unsupported_path}

      {:error, :enoent} ->
        {:error, :enoent}
    end
  end

  defp file_matches(file_path, query) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: false)
        |> Enum.filter(&String.contains?(&1, query))

      {:error, _reason} ->
        []
    end
  end

  defp directory_matches(directory_path, query) do
    directory_path
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.flat_map(fn file_path ->
      file_path
      |> file_matches(query)
      |> Enum.map(fn line -> "#{file_path}:#{line}" end)
    end)
  end
end
