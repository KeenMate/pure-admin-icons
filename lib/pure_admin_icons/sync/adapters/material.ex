defmodule PureAdminIcons.Sync.Adapters.Material do
  @moduledoc """
  Sync adapter for Material Icons (Google).

  Downloads icons from https://github.com/google/material-design-icons
  ~2000 icons × 5 styles (filled, outlined, round, sharp, two-tone).

  Structure:
    src/<category>/<name>/materialicons/24px.svg         → filled
    src/<category>/<name>/materialiconsoutlined/24px.svg → outlined
    src/<category>/<name>/materialiconsround/24px.svg    → round
    src/<category>/<name>/materialiconssharp/24px.svg    → sharp
    src/<category>/<name>/materialiconstwotone/24px.svg  → twotone

  Note: the repo is large (several hundred MB) — first sync can be slow.
  """

  @behaviour PureAdminIcons.Sync.Adapter

  require Logger

  alias PureAdminIcons.Naming

  @github_zip_url "https://github.com/google/material-design-icons/archive/refs/heads/master.zip"

  # Map variant-dir name to our canonical style code
  @style_dirs %{
    "materialicons" => "filled",
    "materialiconsoutlined" => "outline",
    "materialiconsround" => "rounded",
    "materialiconssharp" => "sharp",
    "materialiconstwotone" => "duotone"
  }

  @valid_styles ~w(filled outline rounded sharp duotone)

  @impl true
  def icon_set_id, do: "material"

  @impl true
  def name, do: "Material Icons"

  @impl true
  def license, do: "Apache-2.0"

  @impl true
  def homepage_url, do: "https://fonts.google.com/icons"

  @impl true
  def github_url, do: "https://github.com/google/material-design-icons"

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
        Logger.info("[Material] Using cached extraction at #{cached_path}")
        {:ok, cached_path}

      :miss ->
        download_fresh()
    end
  end

  defp download_fresh do
    alias PureAdminIcons.Sync.Adapter

    temp_zip = Path.join(System.tmp_dir!(), "material-icons-#{:os.system_time(:millisecond)}.zip")
    temp_dir = Path.join(System.tmp_dir!(), "material-extract-#{:os.system_time(:millisecond)}")

    Logger.info("[Material] Fetching ZIP from GitHub (this is a large download)...")

    try do
      case Req.get(@github_zip_url, receive_timeout: 1_800_000, into: File.stream!(temp_zip)) do
        {:ok, %{status: 200}} ->
          Logger.info("[Material] ZIP downloaded, extracting...")
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
    src_base = find_src_root(extracted_path)

    if src_base && File.dir?(src_base) do
      Logger.info("[Material] Parsing icons from #{src_base}...")

      icons =
        src_base
        |> all_icon_variants()
        # Dedupe on the DB's normalized identity (lowercased, separators stripped),
        # since variants like `add_chart` and `addchart` collide on `nrm_original_name`.
        |> Enum.uniq_by(fn {name, style, _cat, _path} -> {normalize_name(name), style} end)
        |> Enum.map(fn {name, style, category, source_path} ->
          display_name = Naming.title_case(name)

          %{
            icon_set: icon_set_id(),
            name: display_name,
            name_lower: String.replace(name, "_", "-"),
            style: style,
            is_scalable: true,
            sizes: [],
            filenames: %{"0" => "#{name}.svg"},
            # iOS:     UIImage(named: "close")      → "close"   (snake_case name)
            # Android: @drawable/close_24           → "close_24" (Google Fonts Icons default)
            ios_identifiers: %{"0" => name},
            android_identifiers: %{"0" => "#{name}_24"},
            categories: [category],
            svg_hash: hash_file(source_path)
          }
        end)

      Logger.info("[Material] Parsed #{length(icons)} icons")
      {:ok, %{icons: icons, synonyms: %{}, discrepancies: []}}
    else
      Logger.warning("[Material] src directory not found under #{extracted_path}")
      {:error, "src directory not found"}
    end
  end

  @impl true
  def move_svgs(extracted_path, output_dir) do
    src_base = find_src_root(extracted_path)
    icon_set_dir = Path.join(output_dir, icon_set_id())

    Enum.each(@valid_styles, fn style ->
      target_dir = Path.join(icon_set_dir, style)
      File.rm_rf(target_dir)
      File.mkdir_p!(target_dir)
    end)

    moved =
      src_base
      |> all_icon_variants()
      |> Enum.uniq_by(fn {name, style, _cat, _path} -> {normalize_name(name), style} end)
      |> Enum.map(fn {name, style, _category, source} ->
        target = Path.join([icon_set_dir, style, "#{name}.svg"])
        write_themed_svg(source, target)
      end)

    ok_count = Enum.count(moved, &(&1 == :ok))
    Logger.info("[Material] Moved #{ok_count} SVGs to #{icon_set_dir}")
    {:ok, ok_count}
  end

  @impl true
  def cleanup(extracted_path) do
    alias PureAdminIcons.Sync.Adapter

    if Adapter.is_cached_path?(extracted_path) do
      Logger.debug("[Material] Keeping cached extraction")
      :ok
    else
      File.rm_rf(extracted_path)
      :ok
    end
  end

  # Private helpers

  # Mirror of the DB's nrm_original_name: lowercase, strip separators.
  defp normalize_name(name) do
    name |> String.downcase() |> String.replace(~r/[_\-\s]/, "")
  end

  # Material SVGs ship without a fill on their root <svg>, so paths fall back
  # to the SVG default (black) and don't respond to CSS color theming.
  # Inject `fill="currentColor"` on the root tag during copy so the icons
  # inherit text color like Lucide/Tabler/etc do.
  defp write_themed_svg(source, target) do
    with {:ok, content} <- File.read(source),
         themed = inject_current_color(content),
         :ok <- File.write(target, themed) do
      :ok
    else
      _ -> :error
    end
  end

  defp inject_current_color(svg) do
    cond do
      # Already has a root-level fill — leave it alone.
      Regex.match?(~r/\A\s*<svg\b[^>]*\sfill\s*=/, svg) ->
        svg

      # Insert fill="currentColor" right after the opening <svg tag.
      true ->
        String.replace(svg, ~r/<svg\b/, ~S(<svg fill="currentColor"), global: false)
    end
  end

  # Finds the `src/` dir under material-design-icons-{master,main}.
  defp find_src_root(extracted_path) do
    extracted_path
    |> File.ls!()
    |> Enum.map(&Path.join([extracted_path, &1, "src"]))
    |> Enum.find(&File.dir?/1)
  end

  # Walks src/<category>/<name>/<variant_dir>/24px.svg and returns
  # {name, style, category, source_path} for each found variant.
  defp all_icon_variants(src_base) do
    src_base
    |> File.ls!()
    |> Enum.flat_map(fn category ->
      category_dir = Path.join(src_base, category)

      if File.dir?(category_dir) do
        category_dir
        |> File.ls!()
        |> Enum.flat_map(fn name ->
          icon_dir = Path.join(category_dir, name)

          if File.dir?(icon_dir) do
            @style_dirs
            |> Enum.flat_map(fn {variant_dir, style} ->
              svg_path = Path.join([icon_dir, variant_dir, "24px.svg"])
              if File.regular?(svg_path), do: [{name, style, category, svg_path}], else: []
            end)
          else
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
    # Only extract the src/ tree — skips the giant font/catalog/android assets.
    {output, exit_code} = System.cmd(exe, [
      "x", zip_path, "-o#{temp_dir}", "material-design-icons-master/src/*", "-y"
    ], stderr_to_stdout: true)

    if exit_code == 0, do: :ok, else: {:error, "7zip failed: #{output}"}
  end

  defp extract_with_unzip(zip_path, temp_dir) do
    {output, exit_code} = System.cmd("unzip", [
      "-q", "-o", zip_path, "material-design-icons-master/src/*", "-d", temp_dir
    ], stderr_to_stdout: true)

    if exit_code == 0, do: :ok, else: {:error, "unzip failed: #{output}"}
  end

  defp extract_with_erlang(zip_path, temp_dir) do
    case :zip.unzip(String.to_charlist(zip_path), [{:cwd, String.to_charlist(temp_dir)}]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "Erlang unzip failed: #{inspect(reason)}"}
    end
  end

  defp hash_file(path) do
    case File.read(path) do
      {:ok, content} -> :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
      _ -> nil
    end
  end
end
