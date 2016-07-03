defmodule GnServer.Schema.GenoFreeze do
  use Ecto.Schema

  schema "GenoFreeze" do
    field :Name
    field :FullName
    field :ShortName
    field :public, :integer
    field :InbredSetId, :integer
    field :confidentiality, :integer
    field :AuthorisedUsers
  end
  
end
