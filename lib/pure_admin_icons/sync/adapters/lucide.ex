defmodule PureAdminIcons.Sync.Adapters.Lucide do
  @moduledoc """
  Sync adapter for Lucide Icons.

  Downloads icons from https://github.com/lucide-icons/lucide
  Lucide is a fork of Feather Icons with 1500+ icons.

  Structure: icons/*.svg (flat folder, single style, 24px size)
  """

  @behaviour PureAdminIcons.Sync.Adapter

  require Logger

  alias PureAdminIcons.Naming

  @github_zip_url "https://github.com/lucide-icons/lucide/archive/refs/heads/main.zip"

  # Adapter callbacks

  @impl true
  def icon_set_id, do: "lucide"

  @impl true
  def name, do: "Lucide Icons"

  @impl true
  def license, do: "ISC"

  @impl true
  def homepage_url, do: "https://lucide.dev/"

  @impl true
  def github_url, do: "https://github.com/lucide-icons/lucide"

  @impl true
  def styles, do: ["outline"]

  @impl true
  def sizes, do: [24]

  @impl true
  def default_size, do: 24

  @impl true
  def download do
    alias PureAdminIcons.Sync.Adapter

    # Check cache first
    case Adapter.get_cached_path(icon_set_id()) do
      {:ok, cached_path} ->
        Logger.info("[Lucide] Using cached extraction at #{cached_path}")
        {:ok, cached_path}

      :miss ->
        download_fresh()
    end
  end

  defp download_fresh do
    alias PureAdminIcons.Sync.Adapter

    temp_zip = Path.join(System.tmp_dir!(), "lucide-icons-#{:os.system_time(:millisecond)}.zip")
    temp_dir = Path.join(System.tmp_dir!(), "lucide-extract-#{:os.system_time(:millisecond)}")

    Logger.info("[Lucide] Fetching ZIP from GitHub...")

    try do
      case Req.get(@github_zip_url, receive_timeout: 300_000, into: File.stream!(temp_zip)) do
        {:ok, %{status: 200}} ->
          Logger.info("[Lucide] ZIP downloaded, extracting...")
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
    icons_dir = Path.join([extracted_path, "lucide-main", "icons"])

    if File.dir?(icons_dir) do
      Logger.info("[Lucide] Parsing icons from #{icons_dir}...")

      {icons, synonyms} =
        icons_dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".svg"))
        |> Enum.map_reduce(%{}, fn filename, syn_acc ->
          name = String.replace_suffix(filename, ".svg", "")
          display_name = Naming.title_case(name)

          icon = %{
            icon_set: icon_set_id(),
            name: display_name,
            name_lower: name,
            style: "outline",
            sizes: [24],
            filenames: %{"24" => filename},
            ios_identifiers: %{"24" => Naming.camel_case(name)},
            android_identifiers: %{"24" => "ic_lucide_#{String.replace(name, "-", "_")}"},
            svg_hash: hash_file(Path.join(icons_dir, filename))
          }

          # Lucide ships a <name>.json sibling file next to every SVG with
          # `tags[]` + `categories[]` (see icon.schema.json). Merge both into
          # the synonym list so search finds icons by theme as well as name.
          terms = read_lucide_tags(icons_dir, name)
          syn_acc = if terms != [], do: Map.put(syn_acc, display_name, terms), else: syn_acc

          {icon, syn_acc}
        end)

      Logger.info("[Lucide] Parsed #{length(icons)} icons, #{map_size(synonyms)} with synonyms")
      {:ok, %{icons: icons, synonyms: synonyms, discrepancies: []}}
    else
      Logger.warning("[Lucide] Icons directory not found: #{icons_dir}")
      {:error, "Icons directory not found"}
    end
  end

  # Reads icons/<name>.json; returns deduped, non-empty `tags ++ categories`.
  defp read_lucide_tags(icons_dir, name) do
    path = Path.join(icons_dir, "#{name}.json")

    with {:ok, body} <- File.read(path),
         {:ok, %{} = meta} <- Jason.decode(body) do
      tags = meta["tags"] || []
      cats = meta["categories"] || []

      (tags ++ cats)
      |> Enum.map(&to_string/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
    else
      _ -> []
    end
  end

  @impl true
  def move_svgs(extracted_path, output_dir) do
    icons_dir = Path.join([extracted_path, "lucide-main", "icons"])
    target_dir = Path.join([output_dir, icon_set_id(), "outline"])

    File.rm_rf(target_dir)
    File.mkdir_p!(target_dir)

    svg_files =
      icons_dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".svg"))

    Logger.info("[Lucide] Moving #{length(svg_files)} SVG files...")

    moved =
      Enum.map(svg_files, fn filename ->
        source = Path.join(icons_dir, filename)
        target = Path.join(target_dir, filename)

        case File.copy(source, target) do
          {:ok, _} -> :ok
          {:error, _} -> :error
        end
      end)

    ok_count = Enum.count(moved, &(&1 == :ok))
    Logger.info("[Lucide] Moved #{ok_count} SVGs to #{target_dir}")
    {:ok, ok_count}
  end

  @impl true
  def cleanup(extracted_path) do
    alias PureAdminIcons.Sync.Adapter

    # Don't delete if it's a cached path
    if Adapter.is_cached_path?(extracted_path) do
      Logger.debug("[Lucide] Keeping cached extraction")
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
      "x", zip_path, "-o#{temp_dir}", "lucide-main/icons/*", "-y"
    ], stderr_to_stdout: true)

    if exit_code == 0, do: :ok, else: {:error, "7zip failed: #{output}"}
  end

  defp extract_with_unzip(zip_path, temp_dir) do
    {output, exit_code} = System.cmd("unzip", [
      "-q", "-o", zip_path, "lucide-main/icons/*", "-d", temp_dir
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
