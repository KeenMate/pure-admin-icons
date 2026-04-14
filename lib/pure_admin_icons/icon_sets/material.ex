defmodule PureAdminIcons.IconSets.Material do
  @moduledoc """
  Identifier and package formatting for Google Material Symbols.

  - CSS class: modern Material Symbols convention —
    `material-symbols-{outlined,rounded,sharp}`. The filled vs outlined
    distinction is controlled via `font-variation-settings: 'FILL' 0|1` on
    the same class, so `filled` and `outline` both map to
    `material-symbols-outlined` (the canonical default). `duotone` falls
    back to the legacy `material-icons-two-tone` class — Material Symbols
    doesn't ship a two-tone variant.
  - HTML tag: `<span class="material-symbols-outlined">iconname</span>`
    (ligature — icon name as the text content, not an attribute).
  - React: `@mui/icons-material` — PascalCase base + style suffix
    (e.g. `import HomeOutlined from '@mui/icons-material/HomeOutlined'`).
  - iOS / Android: no package, naming conventions only
    (`UIImage(named: "close")`, `@drawable/close_24`).

  Vue and Svelte have no single canonical Material package — multiple
  community libraries exist; we don't pick one here.
  """
  @behaviour PureAdminIcons.IconSets.Formatter

  # canonical style → CSS class family
  # Material Symbols uses three classes (outlined/rounded/sharp); FILL is an
  # axis on the variable font, not a separate class. Legacy Material Icons
  # two-tone is still the right answer for duotone.
  @css_class %{
    "filled" => "material-symbols-outlined",
    "outline" => "material-symbols-outlined",
    "rounded" => "material-symbols-rounded",
    "sharp" => "material-symbols-sharp",
    "duotone" => "material-icons-two-tone"
  }

  # canonical style → @mui/icons-material PascalCase suffix
  @mui_suffix %{
    "filled" => "",
    "outline" => "Outlined",
    "rounded" => "Rounded",
    "sharp" => "Sharp",
    "duotone" => "TwoTone"
  }

  # --- Identifiers -------------------------------------------------------

  @impl true
  def react_identifier(icon, _size) do
    case mui_component(icon) do
      nil -> nil
      component -> "import #{component} from '@mui/icons-material/#{component}'\n<#{component} />"
    end
  end

  @impl true
  def vue_identifier(_icon, _size), do: nil

  @impl true
  def svelte_identifier(_icon, _size), do: nil

  @impl true
  def cssclass_identifier(icon, _size) do
    case @css_class[icon.style_code] do
      nil -> nil
      class -> class
    end
  end

  # Override the default `<i class="...">` wrapping — Material Symbols use
  # `<span class="material-symbols-outlined">iconname</span>` with the icon
  # name as the ligature text content.
  @impl true
  def htmltag_identifier(icon, _size) do
    case @css_class[icon.style_code] do
      nil ->
        nil

      class ->
        ligature = String.replace(icon.name_lower, "-", "_")
        ~s(<span class="#{class}">#{ligature}</span>)
    end
  end

  # --- Packages ----------------------------------------------------------

  @impl true
  def react_package(_),
    do: {"@mui/icons-material", "https://mui.com/material-ui/material-icons/"}

  @impl true
  def vue_package(_), do: {nil, nil}

  @impl true
  def svelte_package(_), do: {nil, nil}

  @impl true
  def cssclass_package(_),
    do: {"material-icons", "https://fonts.google.com/icons"}

  # Material doesn't ship as a package on iOS/Android — users download the
  # assets from Google Fonts Icons and drop them into the asset catalog /
  # res/drawable. The identifier is the name convention for each platform:
  #   iOS:     UIImage(named: "close")       → "close"
  #   Android: @drawable/close_24            → "close_24"
  @impl true
  def ios_package(_),
    do: {"Google Fonts Icons (iOS asset catalog)", "https://fonts.google.com/icons"}

  @impl true
  def android_package(_),
    do: {"Google Fonts Icons (vector drawable)", "https://fonts.google.com/icons"}

  # --- Identifier sizes (copy row per size in the modal) -----------------
  # Material is scalable — a single identifier regardless of size.

  @impl true
  def react_identifier_sizes(_icon), do: [0]

  @impl true
  def vue_identifier_sizes(_icon), do: [0]

  @impl true
  def svelte_identifier_sizes(_icon), do: [0]

  # --- helpers ----------------------------------------------------------

  # e.g. "add-home" + "outline" → "AddHomeOutlined"
  defp mui_component(icon) do
    case @mui_suffix[icon.style_code] do
      nil ->
        nil

      suffix ->
        base =
          icon.name_lower
          |> String.split(~r/[-_\s]+/)
          |> Enum.map(&String.capitalize/1)
          |> Enum.join()

        base <> suffix
    end
  end
end
