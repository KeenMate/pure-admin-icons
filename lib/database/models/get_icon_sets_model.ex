# This code has been auto-generated
# Changes to this file will be lost on next generation

defmodule Database.Models.GetIconSetsModel do
  @moduledoc """
  Model representing the result of public.get_icon_sets
  """

  @fields [
    :code,
    :title,
    :display_title,
    :description,
    :notes,
    :license,
    :homepage_url,
    :github_url,
    :styles,
    :sizes,
    :default_size,
    :has_single_source,
    :is_scalable,
    :style_color_methods,
    :native_style_names,
    :brand_color,
    :icon_count,
    :last_sync_started_at,
    :last_synced_at
  ]

  @enforce_keys @fields

  @derive Jason.Encoder
  defstruct @fields

  @type t() :: %__MODULE__{
    code: String.t(),
    title: String.t(),
    display_title: String.t(),
    description: String.t(),
    notes: String.t(),
    license: String.t(),
    homepage_url: String.t(),
    github_url: String.t(),
    styles: list(String.t()),
    sizes: list(integer()),
    default_size: integer(),
    has_single_source: boolean(),
    is_scalable: boolean(),
    style_color_methods: map() | list(),
    native_style_names: map() | list(),
    brand_color: String.t(),
    icon_count: integer(),
    last_sync_started_at: DateTime.t(),
    last_synced_at: DateTime.t()
  }

  use Accessible
end
