defmodule GnServer.Schema.ProbeFreeze do
  use Ecto.Schema

  schema "probefreeze" do
    field :ProbeFreezeId, :integer
    field :ChipId, :integer
    field :TissueId, :integer
    field :Name
    field :FullName
    field :ShortName
    field :InbredSetId, :integer
  end
  
end