defmodule Mix.Tasks.FilterTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  test "prints matching lines without color by default" do
    path = write_file!("alpha beta\nbeta\n")

    output =
      capture_io(fn ->
        Mix.Task.reenable("filter")
        Mix.Tasks.Filter.run([path, "alpha"])
      end)

    assert output == "alpha beta\n"
  end

  test "colors matched text when color modifier is set as a flag" do
    path = write_file!("alpha beta\nbeta\n")

    output =
      capture_io(fn ->
        Mix.Task.reenable("filter")
        Mix.Tasks.Filter.run([path, "alpha", "--modifier", "color"])
      end)

    assert output =~ "\e[33malpha\e[0m"
  end

  test "supports named colors" do
    path = write_file!("alpha beta\n")

    output =
      capture_io(fn ->
        Mix.Task.reenable("filter")
        Mix.Tasks.Filter.run([path, "alpha", "--modifier", "color=red"])
      end)

    assert output =~ "\e[31malpha\e[0m"
  end

  test "raises for unsupported color values" do
    path = write_file!("alpha beta\n")

    assert_raise Mix.Error, "Unsupported color modifier: orange", fn ->
      capture_io(fn ->
        Mix.Task.reenable("filter")
        Mix.Tasks.Filter.run([path, "alpha", "--modifier", "color=orange"])
      end)
    end
  end

  test "searches directories recursively" do
    dir = make_dir!()
    nested = Path.join(dir, "nested")
    File.mkdir_p!(nested)
    file_a = Path.join(dir, "a.txt")
    file_b = Path.join(nested, "b.txt")
    File.write!(file_a, "alpha beta\n")
    File.write!(file_b, "gamma\nalpha delta\n")

    output =
      capture_io(fn ->
        Mix.Task.reenable("filter")
        Mix.Tasks.Filter.run([dir, "alpha"])
      end)

    assert output =~ "#{file_a}:alpha beta"
    assert output =~ "#{file_b}:alpha delta"
  end

  test "prints only match count when count modifier is present for a file" do
    path = write_file!("alpha beta\nalpha gamma\nbeta\n")

    output =
      capture_io(fn ->
        Mix.Task.reenable("filter")
        Mix.Tasks.Filter.run([path, "alpha", "--modifier", "count"])
      end)

    assert output == "2\n"
  end

  test "prints only match count when count modifier is present for a directory" do
    dir = make_dir!()
    nested = Path.join(dir, "nested")
    File.mkdir_p!(nested)
    file_a = Path.join(dir, "a.txt")
    file_b = Path.join(nested, "b.txt")
    File.write!(file_a, "alpha beta\n")
    File.write!(file_b, "alpha delta\nalpha zeta\n")

    output =
      capture_io(fn ->
        Mix.Task.reenable("filter")
        Mix.Tasks.Filter.run([dir, "alpha", "--modifier", "count"])
      end)

    assert output == "3\n"
  end

  test "supports regex queries in CLI" do
    path = write_file!("alpha one\nbeta one\nalpha two\n")

    output =
      capture_io(fn ->
        Mix.Task.reenable("filter")
        Mix.Tasks.Filter.run([path, "/[a-z]+ one/"])
      end)

    assert output =~ "alpha one"
    assert output =~ "beta one"
    refute output =~ "alpha two"
  end

  test "raises for invalid regex query" do
    path = write_file!("alpha\n")

    assert_raise Mix.Error, "Invalid regex query: /(unclosed/", fn ->
      capture_io(fn ->
        Mix.Task.reenable("filter")
        Mix.Tasks.Filter.run([path, "/(unclosed/"])
      end)
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
