# Searchie

Searchie is a small grep-like utility that searches a file or directory and prints matching lines.

## Command line usage

```bash
mix filter path/to/file.txt "needle"
```

Search a directory recursively:

```bash
mix filter path/to/directory "needle"
```

With modifiers (accepted now, behavior can be added later):

```bash
mix filter path/to/file.txt "needle" --modifier count --modifier context=2
```

Colorize matched text:

```bash
mix filter path/to/file.txt "needle" --modifier color
mix filter path/to/file.txt "needle" --modifier color=red
```

Return only the number of matches:

```bash
mix filter path/to/file.txt "needle" --modifier count
mix filter path/to/directory "needle" --modifier count
```

## Notes

- `--modifier` can be provided multiple times.
- Supported formats are `key=value` and `flag`.
- When searching a directory, output is formatted as `path/to/file:matching line`.
- `count` prints only the total number of matches.
- `color` now highlights the matched text. If provided as a flag, it defaults to yellow.
- Modifiers other than `color` are currently parsed and passed through for future feature work.
