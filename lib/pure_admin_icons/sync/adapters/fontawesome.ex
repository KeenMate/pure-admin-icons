defmodule PureAdminIcons.Sync.Adapters.Fontawesome do
  @moduledoc """
  Sync adapter for Font Awesome Free.

  Downloads icons from the npm registry (no GitHub ZIP available).
  Font Awesome Free includes solid, regular, and brands styles.

  Structure (inside npm tarball):
    package/svgs/solid/*.svg      (~1400 icons)
    package/svgs/regular/*.svg    (~150 icons, free subset)
    package/svgs/brands/*.svg     (~500 brand icons)
  """

  @behaviour PureAdminIcons.Sync.Adapter

  require Logger

  @npm_registry_url "https://registry.npmjs.org/@fortawesome/fontawesome-free"

  # Adapter callbacks

  @impl true
  def icon_set_id, do: "fontawesome"

  @impl true
  def name, do: "Font Awesome Free"

  @impl true
  def license, do: "CC BY 4.0 / MIT"

  @impl true
  def homepage_url, do: "https://fontawesome.com/"

  @impl true
  def github_url, do: "https://github.com/FortAwesome/Font-Awesome"

  @impl true
  def styles, do: ["solid", "regular", "brands"]

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
        Logger.info("[FontAwesome] Using cached extraction at #{cached_path}")
        {:ok, cached_path}

      :miss ->
        download_fresh()
    end
  end

  defp download_fresh do
    alias PureAdminIcons.Sync.Adapter

    Logger.info("[FontAwesome] Fetching latest version from npm registry...")

    with {:ok, tarball_url} <- get_latest_tarball_url(),
         {:ok, extracted_path} <- download_and_extract(tarball_url) do
      Adapter.save_to_cache(icon_set_id(), extracted_path)
    end
  end

  defp get_latest_tarball_url do
    case Req.get(@npm_registry_url, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        latest_version = body["dist-tags"]["latest"]
        tarball_url = body["versions"][latest_version]["dist"]["tarball"]
        Logger.info("[FontAwesome] Latest version: #{latest_version}, tarball: #{tarball_url}")
        {:ok, tarball_url}

      {:ok, %{status: status}} ->
        {:error, "Failed to fetch npm registry: HTTP #{status}"}

      {:error, reason} ->
        {:error, "Failed to fetch npm registry: #{inspect(reason)}"}
    end
  end

  defp download_and_extract(tarball_url) do
    temp_tgz = Path.join(System.tmp_dir!(), "fontawesome-free-#{:os.system_time(:millisecond)}.tgz")
    temp_dir = Path.join(System.tmp_dir!(), "fontawesome-extract-#{:os.system_time(:millisecond)}")

    Logger.info("[FontAwesome] Downloading tarball...")

    try do
      case Req.get(tarball_url, receive_timeout: 300_000, into: File.stream!(temp_tgz)) do
        {:ok, %{status: 200}} ->
          Logger.info("[FontAwesome] Tarball downloaded, extracting...")
          File.mkdir_p!(temp_dir)

          case extract_tgz(temp_tgz, temp_dir) do
            :ok ->
              File.rm(temp_tgz)
              {:ok, temp_dir}

            {:error, reason} ->
              File.rm(temp_tgz)
              File.rm_rf(temp_dir)
              {:error, reason}
          end

        {:ok, %{status: status}} ->
          File.rm(temp_tgz)
          {:error, "Failed to download tarball: HTTP #{status}"}

        {:error, reason} ->
          File.rm(temp_tgz)
          {:error, "Failed to download tarball: #{inspect(reason)}"}
      end
    rescue
      e ->
        File.rm(temp_tgz)
        {:error, "Download failed: #{inspect(e)}"}
    end
  end

  @impl true
  def parse(extracted_path) do
    svgs_dir = Path.join([extracted_path, "package", "svgs"])

    if File.dir?(svgs_dir) do
      Logger.info("[FontAwesome] Parsing icons from #{svgs_dir}...")

      icons =
        styles()
        |> Enum.flat_map(fn style ->
          style_dir = Path.join(svgs_dir, style)

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
                ios_identifiers: %{"24" => to_fa_camel_case(name)},
                android_identifiers: %{"24" => "ic_fa_#{String.replace(name, "-", "_")}_#{style}"}
              }
            end)
            # Deduplicate aliases: FA has e.g. "thumbtack" and "thumb-tack" which
            # normalize to the same name in the DB. Keep the shorter (canonical) name.
            |> Enum.sort_by(fn icon -> String.length(icon.name_lower) end)
            |> Enum.uniq_by(fn icon -> String.replace(icon.name_lower, "-", "") end)
          else
            Logger.warning("[FontAwesome] Style directory not found: #{style_dir}")
            []
          end
        end)

      Logger.info("[FontAwesome] Parsed #{length(icons)} icon variants")
      {:ok, %{icons: icons, synonyms: %{}, discrepancies: []}}
    else
      Logger.warning("[FontAwesome] SVGs directory not found: #{svgs_dir}")
      {:error, "SVGs directory not found"}
    end
  end

  @impl true
  def move_svgs(extracted_path, output_dir) do
    svgs_dir = Path.join([extracted_path, "package", "svgs"])
    icon_set_dir = Path.join(output_dir, icon_set_id())

    total_moved =
      styles()
      |> Enum.map(fn style ->
        source_dir = Path.join(svgs_dir, style)
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
      |> Enum.sum()

    Logger.info("[FontAwesome] Moved #{total_moved} SVGs to #{icon_set_dir}")
    {:ok, total_moved}
  end

  @impl true
  def cleanup(extracted_path) do
    alias PureAdminIcons.Sync.Adapter

    if Adapter.is_cached_path?(extracted_path) do
      Logger.debug("[FontAwesome] Keeping cached extraction")
      :ok
    else
      File.rm_rf(extracted_path)
      :ok
    end
  end

  # Private helpers

  defp extract_tgz(tgz_path, temp_dir) do
    # npm tarballs are .tgz (gzipped tar)
    # Try system tar first, then 7zip, then Erlang
    cond do
      System.find_executable("tar") != nil ->
        extract_with_tar(tgz_path, temp_dir)

      match?({:ok, _}, find_7zip()) ->
        {:ok, exe} = find_7zip()
        extract_with_7zip(exe, tgz_path, temp_dir)

      true ->
        extract_with_erlang_tgz(tgz_path, temp_dir)
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

  defp extract_with_tar(tgz_path, temp_dir) do
    {output, exit_code} = System.cmd("tar", [
      "xzf", tgz_path, "-C", temp_dir, "--include=package/svgs/*"
    ], stderr_to_stdout: true)

    if exit_code == 0 do
      :ok
    else
      # Some tar implementations don't support --include, retry without filter
      {output2, exit_code2} = System.cmd("tar", [
        "xzf", tgz_path, "-C", temp_dir
      ], stderr_to_stdout: true)

      if exit_code2 == 0, do: :ok, else: {:error, "tar failed: #{output2}"}
    end
  end

  defp extract_with_7zip(exe, tgz_path, temp_dir) do
    # 7zip needs two steps for .tgz: first decompress .gz, then extract .tar
    intermediate_tar = String.replace_suffix(tgz_path, ".tgz", ".tar")

    # Step 1: decompress .tgz -> .tar
    {output1, exit1} = System.cmd(exe, [
      "x", tgz_path, "-o#{Path.dirname(tgz_path)}", "-y"
    ], stderr_to_stdout: true)

    if exit1 != 0 do
      {:error, "7zip decompress failed: #{output1}"}
    else
      # Step 2: extract .tar
      {output2, exit2} = System.cmd(exe, [
        "x", intermediate_tar, "-o#{temp_dir}", "package/svgs/*", "-y"
      ], stderr_to_stdout: true)

      File.rm(intermediate_tar)

      if exit2 == 0, do: :ok, else: {:error, "7zip extract failed: #{output2}"}
    end
  end

  defp extract_with_erlang_tgz(tgz_path, temp_dir) do
    case :erl_tar.extract(String.to_charlist(tgz_path), [:compressed, {:cwd, String.to_charlist(temp_dir)}]) do
      :ok -> :ok
      {:error, reason} -> {:error, "Erlang tgz extract failed: #{inspect(reason)}"}
    end
  end

  defp title_case(string) do
    string
    |> String.split(~r/[\s-]+/)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  # Font Awesome uses `fa` prefix + camelCase: arrow-right -> faArrowRight
  defp to_fa_camel_case(name) do
    camel =
      name
      |> String.split("-")
      |> Enum.map(&String.capitalize/1)
      |> Enum.join()

    "fa#{camel}"
  end
end
