defmodule PureAdminIcons.Sync.Adapters.Fluentui do
  @moduledoc """
  Sync adapter for Microsoft FluentUI System Icons.

  Downloads icons from https://github.com/microsoft/fluentui-system-icons
  """

  @behaviour PureAdminIcons.Sync.Adapter

  require Logger

  @github_zip_url "https://github.com/microsoft/fluentui-system-icons/archive/refs/heads/main.zip"
  # Native style names used by FluentUI filenames (ic_fluent_foo_24_<native>.svg).
  @valid_styles ~w(regular filled color light)
  # Translate native → canonical for emitted icon records and on-disk dirs.
  @native_to_canonical %{
    "regular" => "outline",
    "filled" => "filled",
    "color" => "color",
    "light" => "light"
  }
  @canonical_styles ~w(outline filled color light)

  # Adapter callbacks

  @impl true
  def icon_set_id, do: "fluentui"

  @impl true
  def name, do: "FluentUI System Icons"

  @impl true
  def license, do: "MIT"

  @impl true
  def homepage_url, do: "https://github.com/microsoft/fluentui-system-icons"

  @impl true
  def github_url, do: "https://github.com/microsoft/fluentui-system-icons"

  @impl true
  def styles, do: @canonical_styles

  @impl true
  def sizes, do: [16, 20, 24, 28, 32, 48]

  @impl true
  def default_size, do: 24

  @impl true
  def download do
    alias PureAdminIcons.Sync.Adapter

    # Check cache first
    case Adapter.get_cached_path(icon_set_id()) do
      {:ok, cached_path} ->
        Logger.info("[FluentUI] Using cached extraction at #{cached_path}")
        {:ok, cached_path}

      :miss ->
        download_fresh()
    end
  end

  defp download_fresh do
    alias PureAdminIcons.Sync.Adapter

    temp_zip = Path.join(System.tmp_dir!(), "fluentui-icons-#{:os.system_time(:millisecond)}.zip")
    temp_dir = Path.join(System.tmp_dir!(), "fluentui-extract-#{:os.system_time(:millisecond)}")

    Logger.info("[FluentUI] Fetching ZIP from GitHub...")

    try do
      case Req.get(@github_zip_url, receive_timeout: 300_000, into: File.stream!(temp_zip)) do
        {:ok, %{status: 200}} ->
          Logger.info("[FluentUI] ZIP downloaded, extracting...")
          File.mkdir_p!(temp_dir)

          case extract_zip(temp_zip, temp_dir) do
            :ok ->
              File.rm(temp_zip)
              # Save to cache if enabled
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
    assets_dir = Path.join([extracted_path, "fluentui-system-icons-main", "assets"])

    if File.dir?(assets_dir) do
      Logger.info("[FluentUI] Parsing icons from #{assets_dir}...")

      {icons, synonyms, discrepancies} =
        assets_dir
        |> File.ls!()
        |> Enum.filter(&File.dir?(Path.join(assets_dir, &1)))
        |> Enum.reduce({[], %{}, []}, fn icon_folder, {icons_acc, syn_acc, disc_acc} ->
          icon_path = Path.join(assets_dir, icon_folder)

          case parse_icon_folder(icon_path) do
            {:ok, parsed_icons, icon_name, icon_synonyms, icon_discrepancies} ->
              syn_acc = if icon_synonyms != [], do: Map.put(syn_acc, icon_name, icon_synonyms), else: syn_acc
              {icons_acc ++ parsed_icons, syn_acc, disc_acc ++ icon_discrepancies}

            :skip ->
              {icons_acc, syn_acc, disc_acc}
          end
        end)

      Logger.info("[FluentUI] Parsed #{length(icons)} icon variants")
      {:ok, %{icons: icons, synonyms: synonyms, discrepancies: discrepancies}}
    else
      Logger.warning("[FluentUI] Assets directory not found: #{assets_dir}")
      {:error, "Assets directory not found"}
    end
  end

  @impl true
  def move_svgs(extracted_path, output_dir) do
    icon_set_dir = Path.join(output_dir, icon_set_id())

    # Clean up and recreate style directories (canonical names on disk)
    for style <- @canonical_styles do
      style_dir = Path.join(icon_set_dir, style)
      File.rm_rf(style_dir)
      File.mkdir_p!(style_dir)
    end

    # Find and move SVGs
    normalized_path = extracted_path |> Path.expand() |> String.replace("\\", "/")
    svg_pattern = "#{normalized_path}/**/*.svg"

    svg_files =
      Path.wildcard(svg_pattern)
      |> Enum.filter(fn path ->
        String.contains?(path, "/SVG/") or String.contains?(path, "\\SVG\\")
      end)

    total = length(svg_files)
    Logger.info("[FluentUI] Moving #{total} SVG files...")

    moved =
      svg_files
      |> Enum.with_index(1)
      |> Enum.map(fn {svg_path, idx} ->
        if rem(idx, 5000) == 0 do
          Logger.info("[FluentUI] Progress: #{idx}/#{total}")
        end

        filename = Path.basename(svg_path)
        native_style = extract_style_from_filename(filename)

        if native_style do
          target_path = Path.join([icon_set_dir, Map.fetch!(@native_to_canonical, native_style), filename])
          case File.copy(svg_path, target_path) do
            {:ok, _} -> :ok
            {:error, _} -> :error
          end
        else
          :skipped
        end
      end)

    ok_count = Enum.count(moved, &(&1 == :ok))
    Logger.info("[FluentUI] Moved #{ok_count} SVGs to #{icon_set_dir}")
    {:ok, ok_count}
  end

  @impl true
  def cleanup(extracted_path) do
    alias PureAdminIcons.Sync.Adapter

    # Don't delete if it's a cached path
    if Adapter.is_cached_path?(extracted_path) do
      Logger.debug("[FluentUI] Keeping cached extraction")
      :ok
    else
      File.rm_rf(extracted_path)
      :ok
    end
  end

  # Private helpers

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

  @doc """
  Find 7zip executable.
  """
  def find_7zip do
    cond do
      exe = System.find_executable("7z") -> {:ok, exe}
      File.exists?("C:/Program Files/7-Zip/7z.exe") -> {:ok, "C:/Program Files/7-Zip/7z.exe"}
      File.exists?("C:/Program Files (x86)/7-Zip/7z.exe") -> {:ok, "C:/Program Files (x86)/7-Zip/7z.exe"}
      true -> :not_found
    end
  end

  defp extract_with_7zip(exe, zip_path, temp_dir) do
    {output, exit_code} = System.cmd(exe, [
      "x", zip_path, "-o#{temp_dir}", "fluentui-system-icons-main/assets/*", "-y"
    ], stderr_to_stdout: true)

    if exit_code == 0, do: :ok, else: {:error, "7zip failed: #{output}"}
  end

  defp extract_with_unzip(zip_path, temp_dir) do
    {output, exit_code} = System.cmd("unzip", [
      "-q", "-o", zip_path, "fluentui-system-icons-main/assets/*", "-d", temp_dir
    ], stderr_to_stdout: true)

    if exit_code == 0, do: :ok, else: {:error, "unzip failed: #{output}"}
  end

  defp extract_with_erlang(zip_path, temp_dir) do
    case :zip.unzip(String.to_charlist(zip_path), [{:cwd, String.to_charlist(temp_dir)}]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "Erlang unzip failed: #{inspect(reason)}"}
    end
  end

  defp parse_icon_folder(icon_path) do
    metadata_path = Path.join(icon_path, "metadata.json")
    svg_dir = Path.join(icon_path, "SVG")

    case read_metadata(metadata_path) do
      {:ok, metadata} ->
        name = metadata["name"]
        claimed_sizes = metadata["size"] || []
        claimed_styles = metadata["style"] || []
        synonyms = metadata["metaphor"] || []

        if name && claimed_sizes != [] && claimed_styles != [] do
          actual_svgs = list_svg_files(svg_dir)
          {icons, discrepancies} = build_verified_icons(name, claimed_sizes, claimed_styles, actual_svgs, svg_dir)

          if icons != [] do
            {:ok, icons, name, synonyms, discrepancies}
          else
            :skip
          end
        else
          :skip
        end

      :error ->
        :skip
    end
  end

  defp read_metadata(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"name" => _} = data} -> {:ok, data}
          _ -> :error
        end
      _ -> :error
    end
  end

  defp list_svg_files(svg_dir) do
    if File.dir?(svg_dir) do
      case File.ls(svg_dir) do
        {:ok, files} -> Enum.filter(files, &String.ends_with?(&1, ".svg"))
        _ -> []
      end
    else
      []
    end
  end

  defp build_verified_icons(name, claimed_sizes, claimed_styles, actual_svgs, svg_dir) do
    name_snake = to_snake_case(name)
    normalized_styles = Enum.map(claimed_styles, &String.downcase/1)
    actual_combinations = parse_svg_combinations(actual_svgs)

    {icons, discrepancies} =
      Enum.reduce(normalized_styles, {[], []}, fn style, {icons_acc, disc_acc} ->
        actual_sizes = for {size, s} <- actual_combinations, s == style, do: size
        missing_sizes = claimed_sizes -- actual_sizes

        new_discrepancies =
          Enum.map(missing_sizes, fn size ->
            %{
              icon_name: name,
              style: style,
              size: size,
              issue: "missing_svg",
              expected_file: "ic_fluent_#{name_snake}_#{size}_#{style}.svg"
            }
          end)

        if actual_sizes != [] do
          filenames = build_filenames(name_snake, actual_sizes, style)
          svg_hash = hash_multi_svg(svg_dir, filenames)

          icon = %{
            icon_set: icon_set_id(),
            name: name,
            name_lower: String.downcase(name),
            style: Map.fetch!(@native_to_canonical, style),
            sizes: Enum.sort(actual_sizes),
            filenames: filenames,
            ios_identifiers: build_ios_identifiers(name, actual_sizes, style),
            android_identifiers: build_android_identifiers(name_snake, actual_sizes, style),
            svg_hash: svg_hash
          }
          {[icon | icons_acc], disc_acc ++ new_discrepancies}
        else
          {icons_acc, disc_acc ++ new_discrepancies}
        end
      end)

    {Enum.reverse(icons), discrepancies}
  end

  defp parse_svg_combinations(svg_files) do
    svg_files
    |> Enum.flat_map(fn filename ->
      case Regex.run(~r/ic_fluent_.*_(\d+)_(regular|filled|color|light)\.svg$/, filename) do
        [_, size_str, style] -> [{String.to_integer(size_str), style}]
        _ -> []
      end
    end)
    |> MapSet.new()
  end

  defp build_filenames(name_snake, sizes, style) do
    sizes
    |> Enum.map(fn size ->
      {Integer.to_string(size), "ic_fluent_#{name_snake}_#{size}_#{style}.svg"}
    end)
    |> Map.new()
  end

  defp build_ios_identifiers(name, sizes, style) do
    camel_name = to_lower_camel_case(name)
    style_suffix = String.capitalize(style)

    sizes
    |> Enum.map(fn size ->
      {Integer.to_string(size), "#{camel_name}#{size}#{style_suffix}"}
    end)
    |> Map.new()
  end

  defp build_android_identifiers(name_snake, sizes, style) do
    sizes
    |> Enum.map(fn size ->
      {Integer.to_string(size), "ic_fluent_#{name_snake}_#{size}_#{style}"}
    end)
    |> Map.new()
  end

  defp to_lower_camel_case(name) do
    name
    |> String.split(~r/[\s_-]+/)
    |> Enum.with_index()
    |> Enum.map(fn {word, idx} ->
      if idx == 0, do: String.downcase(word), else: String.capitalize(word)
    end)
    |> Enum.join()
  end

  defp to_snake_case(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[\s-]+/, "_")
  end

  defp extract_style_from_filename(filename) do
    Enum.find(@valid_styles, fn style ->
      String.ends_with?(filename, "_#{style}.svg")
    end)
  end

  # Hash all SVG files for one icon variant (sorted by filename for determinism)
  defp hash_multi_svg(svg_dir, filenames) do
    contents =
      filenames
      |> Enum.sort_by(fn {size, _} -> size end)
      |> Enum.map(fn {_size, filename} ->
        case File.read(Path.join(svg_dir, filename)) do
          {:ok, data} -> data
          _ -> ""
        end
      end)
      |> Enum.join()

    if contents == "", do: nil, else: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
  end
end
