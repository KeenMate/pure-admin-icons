defmodule PureAdminIcons.Sync.Adapters.Tabler do
  @moduledoc """
  Sync adapter for Tabler Icons.

  Downloads icons from https://github.com/tabler/tabler-icons
  5800+ icons with outline and filled styles.

  Structure:
    icons/outline/*.svg
    icons/filled/*.svg
  """

  @behaviour PureAdminIcons.Sync.Adapter

  require Logger

  @github_zip_url "https://github.com/tabler/tabler-icons/archive/refs/heads/main.zip"
  @valid_styles ~w(outline filled)

  # Adapter callbacks

  @impl true
  def icon_set_id, do: "tabler"

  @impl true
  def name, do: "Tabler Icons"

  @impl true
  def license, do: "MIT"

  @impl true
  def homepage_url, do: "https://tabler.io/icons"

  @impl true
  def github_url, do: "https://github.com/tabler/tabler-icons"

  @impl true
  def styles, do: @valid_styles

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
        Logger.info("[Tabler] Using cached extraction at #{cached_path}")
        {:ok, cached_path}

      :miss ->
        download_fresh()
    end
  end

  defp download_fresh do
    alias PureAdminIcons.Sync.Adapter

    temp_zip = Path.join(System.tmp_dir!(), "tabler-icons-#{:os.system_time(:millisecond)}.zip")
    temp_dir = Path.join(System.tmp_dir!(), "tabler-extract-#{:os.system_time(:millisecond)}")

    Logger.info("[Tabler] Fetching ZIP from GitHub...")

    try do
      case Req.get(@github_zip_url, receive_timeout: 300_000, into: File.stream!(temp_zip)) do
        {:ok, %{status: 200}} ->
          Logger.info("[Tabler] ZIP downloaded, extracting...")
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
    icons_base = Path.join([extracted_path, "tabler-icons-main", "icons"])

    if File.dir?(icons_base) do
      Logger.info("[Tabler] Parsing icons from #{icons_base}...")

      icons =
        @valid_styles
        |> Enum.flat_map(fn style ->
          style_dir = Path.join(icons_base, style)

          if File.dir?(style_dir) do
            style_dir
            |> File.ls!()
            |> Enum.filter(&String.ends_with?(&1, ".svg"))
            |> Enum.map(fn filename ->
              name = String.replace_suffix(filename, ".svg", "")
              display_name = name |> String.replace("-", " ") |> title_case()

              %{
                icon_set: icon_set_id(),
                name: display_name,
                name_lower: name,
                style: style,
                sizes: [24],
                filenames: %{"24" => filename},
                ios_identifiers: %{"24" => to_camel_case(name)},
                android_identifiers: %{"24" => "ic_tabler_#{String.replace(name, "-", "_")}"}
              }
            end)
          else
            []
          end
        end)

      Logger.info("[Tabler] Parsed #{length(icons)} icons")
      {:ok, %{icons: icons, synonyms: %{}, discrepancies: []}}
    else
      Logger.warning("[Tabler] Icons directory not found: #{icons_base}")
      {:error, "Icons directory not found"}
    end
  end

  @impl true
  def move_svgs(extracted_path, output_dir) do
    icons_base = Path.join([extracted_path, "tabler-icons-main", "icons"])
    icon_set_dir = Path.join(output_dir, icon_set_id())

    moved_counts =
      Enum.map(@valid_styles, fn style ->
        source_dir = Path.join(icons_base, style)
        target_dir = Path.join(icon_set_dir, style)

        File.rm_rf(target_dir)
        File.mkdir_p!(target_dir)

        if File.dir?(source_dir) do
          svg_files =
            source_dir
            |> File.ls!()
            |> Enum.filter(&String.ends_with?(&1, ".svg"))

          moved =
            Enum.map(svg_files, fn filename ->
              source = Path.join(source_dir, filename)
              target = Path.join(target_dir, filename)

              case File.copy(source, target) do
                {:ok, _} -> :ok
                {:error, _} -> :error
              end
            end)

          Enum.count(moved, &(&1 == :ok))
        else
          0
        end
      end)

    ok_count = Enum.sum(moved_counts)
    Logger.info("[Tabler] Moved #{ok_count} SVGs to #{icon_set_dir}")
    {:ok, ok_count}
  end

  @impl true
  def cleanup(extracted_path) do
    alias PureAdminIcons.Sync.Adapter

    # Don't delete if it's a cached path
    if Adapter.is_cached_path?(extracted_path) do
      Logger.debug("[Tabler] Keeping cached extraction")
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
      "x", zip_path, "-o#{temp_dir}", "tabler-icons-main/icons/*", "-y"
    ], stderr_to_stdout: true)

    if exit_code == 0, do: :ok, else: {:error, "7zip failed: #{output}"}
  end

  defp extract_with_unzip(zip_path, temp_dir) do
    {output, exit_code} = System.cmd("unzip", [
      "-q", "-o", zip_path, "tabler-icons-main/icons/*", "-d", temp_dir
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
end
