defmodule PureAdminIcons.Sync.Adapters.Heroicons do
  @moduledoc """
  Sync adapter for Heroicons.

  Downloads icons from https://github.com/tailwindlabs/heroicons
  Beautiful hand-crafted SVG icons by the Tailwind CSS team.

  Structure:
    src/24/outline/*.svg   (24px outline)
    src/24/solid/*.svg     (24px solid)
    src/20/solid/*.svg     (20px solid - "mini")
    src/16/solid/*.svg     (16px solid - "micro")
  """

  @behaviour PureAdminIcons.Sync.Adapter

  require Logger

  @github_zip_url "https://github.com/tailwindlabs/heroicons/archive/refs/heads/master.zip"

  # Style configurations: {style_name, [{size, folder_name}]}
  @style_configs [
    {"outline", [{24, "24/outline"}]},
    {"solid", [{24, "24/solid"}, {20, "20/solid"}, {16, "16/solid"}]}
  ]

  # Adapter callbacks

  @impl true
  def icon_set_id, do: "heroicons"

  @impl true
  def name, do: "Heroicons"

  @impl true
  def license, do: "MIT"

  @impl true
  def homepage_url, do: "https://heroicons.com/"

  @impl true
  def github_url, do: "https://github.com/tailwindlabs/heroicons"

  @impl true
  def styles, do: ["outline", "solid"]

  @impl true
  def sizes, do: [16, 20, 24]

  @impl true
  def default_size, do: 24

  @impl true
  def download do
    alias PureAdminIcons.Sync.Adapter

    # Check cache first
    case Adapter.get_cached_path(icon_set_id()) do
      {:ok, cached_path} ->
        Logger.info("[Heroicons] Using cached extraction at #{cached_path}")
        {:ok, cached_path}

      :miss ->
        download_fresh()
    end
  end

  defp download_fresh do
    alias PureAdminIcons.Sync.Adapter

    temp_zip = Path.join(System.tmp_dir!(), "heroicons-#{:os.system_time(:millisecond)}.zip")
    temp_dir = Path.join(System.tmp_dir!(), "heroicons-extract-#{:os.system_time(:millisecond)}")

    Logger.info("[Heroicons] Fetching ZIP from GitHub...")

    try do
      case Req.get(@github_zip_url, receive_timeout: 300_000, into: File.stream!(temp_zip)) do
        {:ok, %{status: 200}} ->
          Logger.info("[Heroicons] ZIP downloaded, extracting...")
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
    src_dir = Path.join([extracted_path, "heroicons-master", "src"])

    if File.dir?(src_dir) do
      Logger.info("[Heroicons] Parsing icons from #{src_dir}...")

      # Group icons by name and style, aggregating sizes
      icons_by_key =
        @style_configs
        |> Enum.flat_map(fn {style, size_folders} ->
          Enum.flat_map(size_folders, fn {size, folder} ->
            folder_path = Path.join(src_dir, folder)

            if File.dir?(folder_path) do
              folder_path
              |> File.ls!()
              |> Enum.filter(&String.ends_with?(&1, ".svg"))
              |> Enum.map(fn filename ->
                name = String.replace_suffix(filename, ".svg", "")
                {name, style, size}
              end)
            else
              []
            end
          end)
        end)
        |> Enum.group_by(fn {name, style, _size} -> {name, style} end)
        |> Enum.map(fn {{name, style}, entries} ->
          sizes = Enum.map(entries, fn {_, _, size} -> size end) |> Enum.sort()
          display_name = name |> String.replace("-", " ") |> title_case()

          %{
            icon_set: icon_set_id(),
            name: display_name,
            name_lower: name,
            style: style,
            sizes: sizes,
            filenames: build_filenames(name, sizes),
            ios_identifiers: build_ios_identifiers(name, sizes),
            android_identifiers: build_android_identifiers(name, sizes, style)
          }
        end)

      Logger.info("[Heroicons] Parsed #{length(icons_by_key)} icon variants")
      {:ok, %{icons: icons_by_key, synonyms: %{}, discrepancies: []}}
    else
      Logger.warning("[Heroicons] Source directory not found: #{src_dir}")
      {:error, "Source directory not found"}
    end
  end

  @impl true
  def move_svgs(extracted_path, output_dir) do
    src_dir = Path.join([extracted_path, "heroicons-master", "src"])
    icon_set_dir = Path.join(output_dir, icon_set_id())

    total_moved =
      @style_configs
      |> Enum.map(fn {style, size_folders} ->
        # Create style directory
        style_dir = Path.join(icon_set_dir, style)
        File.rm_rf(style_dir)
        File.mkdir_p!(style_dir)

        # Copy files from all size folders into style directory
        # Rename to include size: icon-name.svg -> icon-name-24.svg
        Enum.map(size_folders, fn {size, folder} ->
          source_dir = Path.join(src_dir, folder)

          if File.dir?(source_dir) do
            svg_files =
              source_dir
              |> File.ls!()
              |> Enum.filter(&String.ends_with?(&1, ".svg"))

            moved =
              Enum.map(svg_files, fn filename ->
                source = Path.join(source_dir, filename)
                # Add size suffix: arrow-left.svg -> arrow-left-24.svg
                base_name = String.replace_suffix(filename, ".svg", "")
                target_filename = "#{base_name}-#{size}.svg"
                target = Path.join(style_dir, target_filename)

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
        |> Enum.sum()
      end)
      |> Enum.sum()

    Logger.info("[Heroicons] Moved #{total_moved} SVGs to #{icon_set_dir}")
    {:ok, total_moved}
  end

  @impl true
  def cleanup(extracted_path) do
    alias PureAdminIcons.Sync.Adapter

    # Don't delete if it's a cached path
    if Adapter.is_cached_path?(extracted_path) do
      Logger.debug("[Heroicons] Keeping cached extraction")
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
      "x", zip_path, "-o#{temp_dir}", "heroicons-master/src/*", "-y"
    ], stderr_to_stdout: true)

    if exit_code == 0, do: :ok, else: {:error, "7zip failed: #{output}"}
  end

  defp extract_with_unzip(zip_path, temp_dir) do
    {output, exit_code} = System.cmd("unzip", [
      "-q", "-o", zip_path, "heroicons-master/src/*", "-d", temp_dir
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

  defp build_filenames(name, sizes) do
    sizes
    |> Enum.map(fn size -> {Integer.to_string(size), "#{name}-#{size}.svg"} end)
    |> Map.new()
  end

  defp build_ios_identifiers(name, sizes) do
    camel = to_camel_case(name)
    sizes
    |> Enum.map(fn size -> {Integer.to_string(size), "#{camel}#{size}"} end)
    |> Map.new()
  end

  defp build_android_identifiers(name, sizes, style) do
    snake = String.replace(name, "-", "_")
    sizes
    |> Enum.map(fn size -> {Integer.to_string(size), "ic_heroicons_#{snake}_#{size}_#{style}"} end)
    |> Map.new()
  end
end
