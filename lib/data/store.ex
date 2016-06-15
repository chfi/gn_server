# This module should only contain the MySQL calls to the backend to
# fetch data. Assembling more complex structures happens in
# the Assemble module.

defmodule GnServer.Data.Store do

  alias GnServer.Backend.MySQL, as: DB

  def species do
    {:ok, rows} = DB.query("SELECT speciesid,name,fullname FROM Species")
    nlist = Enum.map(rows, fn(x) -> {species_id,species_name,full_name} = x ; [species_id,species_name,full_name] end)
    nlist
  end

  def datasets do
    {:ok, rows} = DB.query("select InbredSet.inbredsetid,InbredSet.speciesid,InbredSet.name,ProbeFreeze.name from InbredSet,ProbeFreeze where InbredSet.inbredsetid=ProbeFreeze.inbredsetid")
    # IO.inspect rows
    nlist = Enum.map(rows, fn(x) -> {inbredset_id,species_id,inbredset_name,full_name} = x ; [inbredset_id,species_id,inbredset_name,full_name] end)
    nlist
  end

  def menu_species do
    {:ok, rows} = DB.query("SELECT speciesid,name,menuname FROM Species")
    # IO.inspect rows
    nlist = Enum.map(rows, fn(x) -> {species_id,species_name,full_name} = x ; [species_id,species_name,full_name] end)
    nlist
  end

  def menu_groups(species) do
    query = """
    select InbredSet.id,InbredSet.Name,InbredSet.FullName
    from InbredSet,Species,ProbeFreeze,GenoFreeze,PublishFreeze
    where Species.Name = '#{species}'
      and InbredSet.SpeciesId = Species.Id and InbredSet.Name != 'BXD300'
      and
                       (PublishFreeze.InbredSetId = InbredSet.Id
                        or GenoFreeze.InbredSetId = InbredSet.Id
                        or ProbeFreeze.InbredSetId = InbredSet.Id)
                        group by InbredSet.Name
                        order by InbredSet.Name
"""
      {:ok, rows} = DB.query(query)
      Enum.map(rows, fn(x) -> {id,name,fullname} = x ; [id,name,fullname] end)
  end

  def menu_types(species, group) do
    query = """
    select distinct Tissue.Name
    from ProbeFreeze,ProbeSetFreeze,InbredSet,Tissue,Species
    where Species.Name = '#{species}' and Species.Id = InbredSet.SpeciesId and
      InbredSet.Name = '#{group}' and
      ProbeFreeze.TissueId = Tissue.Id and
      ProbeFreeze.InbredSetId = InbredSet.Id and
      ProbeSetFreeze.ProbeFreezeId = ProbeFreeze.Id and
      ProbeSetFreeze.public > 0
      order by Tissue.Name
    """
    {:ok, rows} = DB.query(query)
    Enum.map(rows, fn(x) -> {tissue} = x ; [tissue] end)
  end
end
