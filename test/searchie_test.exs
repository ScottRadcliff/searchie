defmodule SearchieTest do
  use ExUnit.Case

  describe "filter/3" do
    test "returns lines containing the query" do
      path = write_file!("alpha\nbeta\nalphabet\ngamma\n")

      assert {:ok, %{matches: ["alpha", "alphabet"], modifiers: []}} =
               Searchie.filter(path, "alpha")
    end

    test "returns no matches when query is absent" do
      path = write_file!("alpha\nbeta\n")

      assert {:ok, %{matches: [], modifiers: []}} = Searchie.filter(path, "delta")
    end

    test "returns file-not-found for missing files" do
      assert {:error, :enoent} =
               Searchie.filter("/tmp/does-not-exist-#{System.unique_integer()}", "x")
    end

    test "carries modifiers for future behavior" do
      path = write_file!("red\nblue\n")
      modifiers = [{"count", true}, {"context", "2"}]

      assert {:ok, %{matches: ["red"], modifiers: ^modifiers}} =
               Searchie.filter(path, "red", modifiers)
    end

    test "supports recursive directory search" do
      dir = make_dir!()
      file_a = Path.join(dir, "a.txt")
      nested = Path.join(dir, "nested")
      file_b = Path.join(nested, "b.txt")
      File.mkdir_p!(nested)
      File.write!(file_a, "alpha one\nbeta two\n")
      File.write!(file_b, "gamma three\nalpha four\n")

      assert {:ok, %{matches: matches, modifiers: []}} = Searchie.filter(dir, "alpha")
      assert "#{file_a}:alpha one" in matches
      assert "#{file_b}:alpha four" in matches
    end
  end

  defp write_file!(contents) do
    path = Path.join(System.tmp_dir!(), "searchie-#{System.unique_integer([:positive])}.txt")
    File.write!(path, contents)
    path
  end

  defp make_dir! do
    path = Path.join(System.tmp_dir!(), "searchie-dir-#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    path
  end
end
