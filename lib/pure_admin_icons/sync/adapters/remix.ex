defmodule PureAdminIcons.Sync.Adapters.Remix do
  @moduledoc """
  Sync adapter for Remix Icon.

  Downloads icons from https://github.com/Remix-Design/RemixIcon
  ~3000 icons in line and fill styles.

  Structure:
    icons/<Category>/<name>-line.svg
    icons/<Category>/<name>-fill.svg
  """

  @behaviour PureAdminIcons.Sync.Adapter

  require Logger

  @github_zip_url "https://github.com/Remix-Design/RemixIcon/archive/refs/heads/master.zip"
  @valid_styles ~w(outline filled)
  # canonical style → native suffix in filenames (e.g. foo-line.svg → outline)
  @native_suffix %{"outline" => "line", "filled" => "fill"}

  @impl true
  def icon_set_id, do: "remix"

  @impl true
  def name, do: "Remix Icon"

  @impl true
  def license, do: "Apache-2.0"

  @impl true
  def homepage_url, do: "https://remixicon.com/"

  @impl true
  def github_url, do: "https://github.com/Remix-Design/RemixIcon"

  @impl true
  def styles, do: @valid_styles

  @impl true
  def sizes, do: [24]

  @impl true
  def default_size, do: 24

  @impl true
  def download do
    alias PureAdminIcons.Sync.Adapter

    case Adapter.get_cached_path(icon_set_id()) do
      {:ok, cached_path} ->
        Logger.info("[Remix] Using cached extraction at #{cached_path}")
        {:ok, cached_path}

      :miss ->
        download_fresh()
    end
  end

  defp download_fresh do
    alias PureAdminIcons.Sync.Adapter

    temp_zip = Path.join(System.tmp_dir!(), "remix-icons-#{:os.system_time(:millisecond)}.zip")
    temp_dir = Path.join(System.tmp_dir!(), "remix-extract-#{:os.system_time(:millisecond)}")

    Logger.info("[Remix] Fetching ZIP from GitHub...")

    try do
      case Req.get(@github_zip_url, receive_timeout: 300_000, into: File.stream!(temp_zip)) do
        {:ok, %{status: 200}} ->
          Logger.info("[Remix] ZIP downloaded, extracting...")
          File.mkdir_p!(temp_dir)

          case extract_zip(temp_zip, temp_dir) do
            :ok ->
              File.rm(temp_zip)
              Adapter.save_to_cache(icon_set_id(), temp_dir)

            {:error, reason} ->
              File.rm(temp_zip)
              File.rm_rf(temp_dir)
              {:error, reason}
          end

        {:ok, %{status: status}} ->
          File.rm(temp_zip)
          {:error, "Failed to download ZIP: HTTP #{status}"}

        {:error, reason} ->
          File.rm(temp_zip)
          {:error, "Failed to download ZIP: #{inspect(reason)}"}
      end
    rescue
      e ->
        File.rm(temp_zip)
        {:error, "Download failed: #{inspect(e)}"}
    end
  end

  @impl true
  def parse(extracted_path) do
    icons_base = find_icons_root(extracted_path)

    if icons_base && File.dir?(icons_base) do
      Logger.info("[Remix] Parsing icons from #{icons_base}...")

      icons =
        icons_base
        |> all_svgs()
        # Dedupe on the DB's normalized identity (lowercased, separators stripped).
        |> Enum.uniq_by(fn {style, _cat, filename, _path} -> {normalize_filename(filename, style), style} end)
        |> Enum.flat_map(fn {style, category, filename, full_path} ->
          base = String.replace_suffix(filename, ".svg", "")
          name = String.replace_suffix(base, "-#{@native_suffix[style]}", "")
          display_name = name |> String.replace("-", " ") |> title_case()

          [%{
            icon_set: icon_set_id(),
            name: display_name,
            name_lower: name,
            style: style,
            is_scalable: true,
            sizes: [],
            filenames: %{"0" => "#{name}.svg"},
            ios_identifiers: %{"0" => to_camel_case(name)},
            android_identifiers: %{"0" => "ic_remix_#{String.replace(name, "-", "_")}"},
            categories: [category],
            svg_hash: hash_file(full_path)
          }]
        end)

      Logger.info("[Remix] Parsed #{length(icons)} icons")
      {:ok, %{icons: icons, synonyms: %{}, discrepancies: []}}
    else
      Logger.warning("[Remix] Icons directory not found under #{extracted_path}")
      {:error, "Icons directory not found"}
    end
  end

  @impl true
  def move_svgs(extracted_path, output_dir) do
    icons_base = find_icons_root(extracted_path)
    icon_set_dir = Path.join(output_dir, icon_set_id())

    Enum.each(@valid_styles, fn style ->
      target_dir = Path.join(icon_set_dir, style)
      File.rm_rf(target_dir)
      File.mkdir_p!(target_dir)
    end)

    moved =
      icons_base
      |> all_svgs()
      |> Enum.uniq_by(fn {style, _cat, filename, _path} -> {normalize_filename(filename, style), style} end)
      |> Enum.map(fn {style, _category, filename, source} ->
        base = String.replace_suffix(filename, ".svg", "")
        name = String.replace_suffix(base, "-#{@native_suffix[style]}", "")
        target = Path.join([icon_set_dir, style, "#{name}.svg"])

        case File.copy(source, target) do
          {:ok, _} -> :ok
          {:error, _} -> :error
        end
      end)

    ok_count = Enum.count(moved, &(&1 == :ok))
    Logger.info("[Remix] Moved #{ok_count} SVGs to #{icon_set_dir}")
    {:ok, ok_count}
  end

  @impl true
  def cleanup(extracted_path) do
    alias PureAdminIcons.Sync.Adapter

    if Adapter.is_cached_path?(extracted_path) do
      Logger.debug("[Remix] Keeping cached extraction")
      :ok
    else
      File.rm_rf(extracted_path)
      :ok
    end
  end

  # Private helpers

  # Mirror of the DB's nrm_original_name: strip ".svg" + style suffix, lowercase, drop separators.
  defp normalize_filename(filename, style) do
    filename
    |> String.replace_suffix(".svg", "")
    |> String.replace_suffix("-#{@native_suffix[style]}", "")
    |> String.downcase()
    |> String.replace(~r/[_\-\s]/, "")
  end

  # Finds the `icons/` dir under either RemixIcon-main or RemixIcon-master (branch name may vary).
  defp find_icons_root(extracted_path) do
    extracted_path
    |> File.ls!()
    |> Enum.map(&Path.join([extracted_path, &1, "icons"]))
    |> Enum.find(&File.dir?/1)
  end

  # Walks <icons_base>/<Category>/*-{line,fill}.svg and returns {style, category, filename, full_path}.
  defp all_svgs(icons_base) do
    icons_base
    |> File.ls!()
    |> Enum.flat_map(fn category ->
      category_dir = Path.join(icons_base, category)

      if File.dir?(category_dir) do
        category_dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".svg"))
        |> Enum.flat_map(fn filename ->
          base = String.replace_suffix(filename, ".svg", "")

          cond do
            String.ends_with?(base, "-line") ->
              [{"outline", category, filename, Path.join(category_dir, filename)}]
            String.ends_with?(base, "-fill") ->
              [{"filled", category, filename, Path.join(category_dir, filename)}]
            true ->
              []
          end
        end)
      else
        []
      end
    end)
  end

  defp extract_zip(zip_path, temp_dir) do
    case find_7zip() do
      {:ok, exe} ->
        extract_with_7zip(exe, zip_path, temp_dir)

      :not_found ->
        case System.find_executable("unzip") do
          nil -> extract_with_erlang(zip_path, temp_dir)
          _unzip -> extract_with_unzip(zip_path, temp_dir)
        end
    end
  end

  defp find_7zip do
    cond do
      exe = System.find_executable("7z") -> {:ok, exe}
      File.exists?("C:/Program Files/7-Zip/7z.exe") -> {:ok, "C:/Program Files/7-Zip/7z.exe"}
      File.exists?("C:/Program Files (x86)/7-Zip/7z.exe") -> {:ok, "C:/Program Files (x86)/7-Zip/7z.exe"}
      true -> :not_found
    end
  end

  defp extract_with_7zip(exe, zip_path, temp_dir) do
    {output, exit_code} = System.cmd(exe, [
      "x", zip_path, "-o#{temp_dir}", "-y"
    ], stderr_to_stdout: true)

    if exit_code == 0, do: :ok, else: {:error, "7zip failed: #{output}"}
  end

  defp extract_with_unzip(zip_path, temp_dir) do
    {output, exit_code} = System.cmd("unzip", [
      "-q", "-o", zip_path, "-d", temp_dir
    ], stderr_to_stdout: true)

    if exit_code == 0, do: :ok, else: {:error, "unzip failed: #{output}"}
  end

  defp extract_with_erlang(zip_path, temp_dir) do
    case :zip.unzip(String.to_charlist(zip_path), [{:cwd, String.to_charlist(temp_dir)}]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "Erlang unzip failed: #{inspect(reason)}"}
    end
  end

  defp title_case(string) do
    string
    |> String.split(~r/[\s-]+/)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp to_camel_case(name) do
    name
    |> String.split("-")
    |> Enum.with_index()
    |> Enum.map(fn {word, idx} ->
      if idx == 0, do: word, else: String.capitalize(word)
    end)
    |> Enum.join()
  end

  defp hash_file(path) do
    case File.read(path) do
      {:ok, content} -> :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
      _ -> nil
    end
  end
end
