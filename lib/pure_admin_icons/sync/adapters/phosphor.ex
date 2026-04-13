defmodule PureAdminIcons.Sync.Adapters.Phosphor do
  @moduledoc """
  Sync adapter for Phosphor Icons.

  Downloads icons from https://github.com/phosphor-icons/core
  1500+ icons in 6 weights.

  Structure:
    assets/thin/<name>-thin.svg
    assets/light/<name>-light.svg
    assets/regular/<name>.svg
    assets/bold/<name>-bold.svg
    assets/fill/<name>-fill.svg
    assets/duotone/<name>-duotone.svg
  """

  @behaviour PureAdminIcons.Sync.Adapter

  require Logger

  @github_zip_url "https://github.com/phosphor-icons/core/archive/refs/heads/main.zip"
  @valid_styles ~w(thin light regular bold filled duotone)
  # Map canonical style code → native directory name under assets/
  @style_dirs %{
    "thin" => "thin",
    "light" => "light",
    "regular" => "regular",
    "bold" => "bold",
    "filled" => "fill",
    "duotone" => "duotone"
  }

  @impl true
  def icon_set_id, do: "phosphor"

  @impl true
  def name, do: "Phosphor Icons"

  @impl true
  def license, do: "MIT"

  @impl true
  def homepage_url, do: "https://phosphoricons.com/"

  @impl true
  def github_url, do: "https://github.com/phosphor-icons/core"

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
        Logger.info("[Phosphor] Using cached extraction at #{cached_path}")
        {:ok, cached_path}

      :miss ->
        download_fresh()
    end
  end

  defp download_fresh do
    alias PureAdminIcons.Sync.Adapter

    temp_zip = Path.join(System.tmp_dir!(), "phosphor-icons-#{:os.system_time(:millisecond)}.zip")
    temp_dir = Path.join(System.tmp_dir!(), "phosphor-extract-#{:os.system_time(:millisecond)}")

    Logger.info("[Phosphor] Fetching ZIP from GitHub...")

    try do
      case Req.get(@github_zip_url, receive_timeout: 300_000, into: File.stream!(temp_zip)) do
        {:ok, %{status: 200}} ->
          Logger.info("[Phosphor] ZIP downloaded, extracting...")
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
    assets_base = Path.join([extracted_path, "core-main", "assets"])

    if File.dir?(assets_base) do
      Logger.info("[Phosphor] Parsing icons from #{assets_base}...")

      icons =
        @style_dirs
        |> Enum.flat_map(fn {style, native_dir} ->
          style_dir = Path.join(assets_base, native_dir)

          if File.dir?(style_dir) do
            style_dir
            |> File.ls!()
            |> Enum.filter(&String.ends_with?(&1, ".svg"))
            |> Enum.map(fn filename ->
              base = String.replace_suffix(filename, ".svg", "")
              name = strip_native_suffix(base, native_dir)
              display_name = name |> String.replace("-", " ") |> title_case()

              %{
                icon_set: icon_set_id(),
                name: display_name,
                name_lower: name,
                style: style,
                is_scalable: true,
                sizes: [],
                filenames: %{"0" => filename},
                ios_identifiers: %{"0" => to_camel_case(name)},
                android_identifiers: %{"0" => "ic_phosphor_#{String.replace(name, "-", "_")}"},
                svg_hash: hash_file(Path.join(style_dir, filename))
              }
            end)
          else
            []
          end
        end)

      Logger.info("[Phosphor] Parsed #{length(icons)} icons")
      {:ok, %{icons: icons, synonyms: %{}, discrepancies: []}}
    else
      Logger.warning("[Phosphor] Assets directory not found: #{assets_base}")
      {:error, "Assets directory not found"}
    end
  end

  @impl true
  def move_svgs(extracted_path, output_dir) do
    assets_base = Path.join([extracted_path, "core-main", "assets"])
    icon_set_dir = Path.join(output_dir, icon_set_id())

    moved_counts =
      Enum.map(@style_dirs, fn {style, native_dir} ->
        source_dir = Path.join(assets_base, native_dir)
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
    Logger.info("[Phosphor] Moved #{ok_count} SVGs to #{icon_set_dir}")
    {:ok, ok_count}
  end

  @impl true
  def cleanup(extracted_path) do
    alias PureAdminIcons.Sync.Adapter

    if Adapter.is_cached_path?(extracted_path) do
      Logger.debug("[Phosphor] Keeping cached extraction")
      :ok
    else
      File.rm_rf(extracted_path)
      :ok
    end
  end

  # Private helpers

  defp strip_native_suffix(base, "regular"), do: base
  defp strip_native_suffix(base, native_dir), do: String.replace_suffix(base, "-#{native_dir}", "")

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
      "x", zip_path, "-o#{temp_dir}", "core-main/assets/*", "-y"
    ], stderr_to_stdout: true)

    if exit_code == 0, do: :ok, else: {:error, "7zip failed: #{output}"}
  end

  defp extract_with_unzip(zip_path, temp_dir) do
    {output, exit_code} = System.cmd("unzip", [
      "-q", "-o", zip_path, "core-main/assets/*", "-d", temp_dir
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
