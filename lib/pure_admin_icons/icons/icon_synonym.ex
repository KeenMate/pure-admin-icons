defmodule PureAdminIcons.Icons.IconSynonym do
  use Ecto.Schema
  import Ecto.Changeset

  schema "icon_synonyms" do
    field :icon_set, :string, default: "fluentui"
    field :icon_name_lower, :string
    field :icon_style, :string
    field :synonym, :string

    timestamps()
  end

  @doc false
  def changeset(synonym, attrs) do
    synonym
    |> cast(attrs, [:icon_set, :icon_name_lower, :icon_style, :synonym])
    |> validate_required([:icon_set, :icon_name_lower, :icon_style, :synonym])
    |> unique_constraint([:icon_set, :icon_name_lower, :icon_style, :synonym])
  end
end
