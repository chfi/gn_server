# This module should only contain the MySQL calls to the backend to
# fetch data. Assembling more complex structures should happen in the
# Assemble modules.
#
# All functions return lists of lists, rather than lists of
# tuples. Main reason is that tuples do not go nicely with JSON.

defmodule GnServer.Data.Store do

  alias GnServer.Backend.MySQL, as: DB
  import Ecto.Query
  alias GnServer.Repo
  alias GnServer.Schema.Species

  defp use_type(id) do
    try do
      { :integer, String.to_integer(id) }
    rescue
      _ in ArgumentError -> { :string, id }
    end
  end

  defp authorize_group(group_name) do
    if group_name != "BXD" do
      raise "Authorization error for " <> group_name
    end
  end

  defp authorize_dataset(dataset_name) do
    subq =
      case use_type(dataset_name) do
        { :integer, i } -> "D.id = #{i}"
        { :string, s }  -> "D.Name = '#{s}'"
      end
    query = """
SELECT DISTINCT D.confidentiality,D.public FROM ProbeSetFreeze AS D
WHERE #{subq}
"""
    {:ok, rows} = DB.query(query)
    if Enum.count(rows) != 1 do
      raise "Access error"
    end
    [{confidentiality,public}] = rows
    if public == 0 or confidentiality > 0 do
      raise "Authorization error"
    end
  end

  def species do
    #{:ok, rows} = DB.query("SELECT speciesid,name,fullname FROM Species")
    query = from s in Species,
    select: {s.id, s."Name", s."FullName"}

    # for r <- Repo.all(query), do: ( [r.id,r."Name",r."FullName"] )
    Repo.all(query)
  end

  def groups(species) do
    subq =
      case use_type(species) do
        { :integer, i } -> "Species.id = #{i}"
        { :string, s }  -> "Species.Name = '#{s}'"
      end

    # note this query can be simplified
    query = """
SELECT distinct InbredSet.id,InbredSet.Name,InbredSet.FullName
FROM InbredSet,Species,ProbeFreeze,GenoFreeze,PublishFreeze
WHERE #{subq}
and InbredSet.SpeciesId = Species.Id and InbredSet.Name != 'BXD300'
and (PublishFreeze.InbredSetId = InbredSet.Id
     or GenoFreeze.InbredSetId = InbredSet.Id
     or ProbeFreeze.InbredSetId = InbredSet.Id)
"""
    {:ok, rows} = DB.query(query)
    for r <- rows, do: ( {id,name,full_name} = r ; [id,name,full_name] )
  end

  def group_info(group) do
    subq =
      case use_type(group) do
        { :integer, i } -> "C.id = #{i}"
        { :string, s }  -> "C.Name = '#{s}'"
      end
    query = "
SELECT DISTINCT Species.speciesid,Species.Name,C.InbredSetid,C.name,C.mappingmethodid,C.genetictype
FROM Species, InbredSet as C
WHERE #{subq} and C.SpeciesId = Species.Id"
    {:ok, rows} = DB.query(query)
    for r <- rows, do: ( {species_id,species,group_id,group_name,method_id,genetic_type} = r; [group_id,group_name,species_id,species,method_id,genetic_type] )
  end

  def chr_info(dataset_name) do
    subq =
      case use_type(dataset_name) do
        { :integer, i } -> "C.id = #{i}"
        { :string, s }  -> "C.Name = '#{s}'"
      end

      query = """
SELECT Chr_Length.Name, Length
FROM Chr_Length, InbredSet as C
WHERE #{subq}
AND Chr_Length.SpeciesId = C.SpeciesId
ORDER BY Chr_Length.OrderId
      """
    {:ok, rows} = DB.query(query)
    for r <- rows, do: ( {chr_name,chr_len} = r; [chr_name,chr_len] )
  end

  def datasets(group) do
    authorize_group(group)
    query = """
SELECT DISTINCT D.Id,D.Name,D.FullName
FROM ProbeSetFreeze AS D, ProbeFreeze as D2, InbredSet, Tissue, Species
WHERE
    InbredSet.Name = '#{group}' and
    D.ProbeFreezeId = D2.Id
    AND D2.TissueId = Tissue.Id
    AND D2.InbredSetId = InbredSet.Id
    AND D.confidentiality < 1
    AND D.public > 0
"""
    {:ok, rows} = DB.query(query)
    for r <- rows, do: ( {id,name,full_name} = r ; [id,name,full_name] )
  end

  def dataset_info(dataset_name) do
    authorize_dataset(dataset_name)
    subq =
      case use_type(dataset_name) do
        { :integer, i } -> "D.id = #{i}"
        { :string, s }  -> "D.Name = '#{s}'"
      end

    query = """
SELECT D.Id, D.Name, D.FullName, D.ShortName, D.DataScale, D2.TissueId, Tissue.Name, D.public, D.confidentiality
FROM ProbeSetFreeze as D, ProbeFreeze as D2, Tissue
WHERE #{subq}
    AND D.public > 0
    AND D.ProbeFreezeId = D2.Id
    AND D2.TissueId = Tissue.Id
    """
    {:ok, rows} = DB.query(query)
    for r <- rows, do: ( {id,name,full_name,short_name,data_scale,tissue_id,tissue_name,public,confidential} = r; [id,name,full_name,short_name,data_scale,tissue_id,tissue_name,public,confidential] )
  end

  def phenotypes(dataset_name, start, stop) do
    authorize_dataset(dataset_name)
    dataset_id =
      case use_type(dataset_name) do
        { :integer, i } -> i
        { :string, _ }  -> ( [[id | tail_]] = dataset_info(dataset_name)
                           id )
      end

    start2 =
      if start == nil do
        0
      else
        start
      end

    stop2 =
      if stop == nil do
        100
      else
        stop
      end

    limit = stop2 - start2 + 1
    query = """
SELECT distinct ProbeSet.Name,
  ProbeSetXRef.Mean, ProbeSetXRef.LRS,
  ProbeSetXRef.PVALUE, ProbeSetXRef.additive, ProbeSetXRef.locus, ProbeSet.Chr_num,
  ProbeSet.Mb, ProbeSet.Symbol,
  ProbeSet.name_num
FROM ProbeSetXRef, ProbeSet
WHERE ProbeSet.Id = ProbeSetXRef.ProbeSetId
  and ProbeSetXRef.ProbeSetFreezeId = #{dataset_id}
  ORDER BY ProbeSet.symbol ASC LIMIT #{limit}
    """
    {:ok, rows} = DB.query(query)
    for r <- rows, do: ( {name,mean,lrs,pvalue,additive,locus,chr,mb,symbol,name_num} = r ;
      %{ name: name,
         name_id: name_num,
         mean: mean,
         "MAX_LRS": lrs,
         "p_value": pvalue,
         additive: additive,
         locus: locus,
         chr: chr,
         "Mb": mb,
         symbol: symbol
      })
  end

  def marker_info(species,marker) do
      query = """
SELECT Geno.Chr, Geno.Mb, Species.Id,Geno.source FROM Geno, Species
WHERE Species.Name = '#{species}'
AND Geno.Name = '#{marker}'
     """
    {:ok, rows} = DB.query(query)
    for r <- rows, do: ( {chr_name,chr_len,species_id,source} = r;
      %{
        species: species,
        species_id: species_id,
        source: source,
        marker: marker,
        chr:     chr_name,
        chr_len: chr_len
      } )
  end


  def phenotype_info(dataset_name,marker) do
    authorize_dataset(dataset_name)
    # The GN1 querly looks like
    # query = "SELECT Strain.Name, %sData.value from %sData, Strain, %s, %sXRef WHERE %s.Name = '%s' and %sXRef.%sId = %s.Id and %sXRef.%sFreezeId = %d and  %sXRef.DataId = %sData.Id and %sData.StrainId = Strain.Id order by Strain.Id"
    # but it does not pick up the stderr.
      query = """
SELECT DISTINCT Strain.id, Strain.Name, ProbeSetData.value, ProbeSetSE.error,
  ProbeSetData.Id
FROM (ProbeSetData, ProbeSetFreeze, Strain, ProbeSet, ProbeSetXRef)
LEFT JOIN ProbeSetSE on (ProbeSetSE.DataId = ProbeSetData.Id
  AND ProbeSetSE.StrainId = ProbeSetData.StrainId)
WHERE ProbeSet.Name = '#{marker}'
  AND ProbeSetXRef.ProbeSetId = ProbeSet.Id
  AND ProbeSetXRef.ProbeSetFreezeId = ProbeSetFreeze.Id
  AND ProbeSetFreeze.Name = '#{dataset_name}'
  AND ProbeSetXRef.DataId = ProbeSetData.Id
  AND ProbeSetData.StrainId = Strain.Id
  ORDER BY Strain.Id
      """
    # IO.puts(query)
    {:ok, rows} = DB.query(query)
    for r <- rows, do: ( {strain_id,strain_name,value,stderr,_} = r;
      [strain_id,strain_name,value,stderr]
    )
  end

  def phenotype_info(dataset_name,marker,group) do
    authorize_dataset(dataset_name)
    authorize_group(group)
    [[group_id | _ ] | _] = group_info(group)
    query = """
SELECT DISTINCT Strain.Id, SX.InbredSetId, Strain.Name, V.value, ProbeSetSE.error,
  V.Id
FROM (ProbeSetData as V, ProbeSetFreeze as D, ProbeFreeze as D2, Strain, StrainXRef as SX, ProbeSet, ProbeSetXRef as Locus)
LEFT JOIN ProbeSetSE on (ProbeSetSE.DataId = V.Id
  AND ProbeSetSE.StrainId = V.StrainId)
WHERE ProbeSet.Name = '#{marker}'
  AND Locus.ProbeSetId = ProbeSet.Id
  AND Locus.ProbeSetFreezeId = D.Id
  AND SX.StrainId = Strain.Id
  AND SX.InbredSetId = #{group_id}
  AND D.Name = '#{dataset_name}'
  AND Locus.DataId = V.Id
  AND V.StrainId = Strain.Id
  AND SX.StrainId = Strain.Id
  ORDER BY Strain.Id
    """

    # IO.puts(query)
    {:ok, rows} = DB.query(query)
    for r <- rows, do: ( {strain_id,_,strain_name,value,stderr,_} = r;
      [strain_id,strain_name,value,stderr]
    )
  end

  def menu_species do
    {:ok, rows} = DB.query("SELECT speciesid,name,menuname FROM Species")
    for r <- rows, do: ( {id,name,fullname} = r; [id,name,fullname] )
  end

  def menu_groups(species) do

    query = """
    select distinct InbredSet.id,InbredSet.Name,InbredSet.FullName
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
    for r <- rows, do: ( {id,name,fullname} = r; [id,name,fullname] )
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
    for r <- rows, do: ( {tissue} = r; [tissue] )
  end

  def menu_datasets(species, group, type) do
    query = """
    select ProbeSetFreeze.Id,ProbeSetFreeze.Name,ProbeSetFreeze.FullName
    from ProbeSetFreeze, ProbeFreeze, InbredSet, Tissue, Species
    where
    Species.Name = '#{species}' and Species.Id = InbredSet.SpeciesId and
    InbredSet.Name = '#{group}' and
    ProbeSetFreeze.ProbeFreezeId = ProbeFreeze.Id and
    Tissue.Name = '#{type}' and
    ProbeFreeze.TissueId = Tissue.Id and ProbeFreeze.InbredSetId = InbredSet.Id and
    ProbeSetFreeze.confidentiality < 1 and ProbeSetFreeze.public > 0 order by
    ProbeSetFreeze.CreateTime desc
    """
    {:ok, rows} = DB.query(query)
    for r <- rows, do: ( {id,name,fullname} = r; [id,name,fullname] )
  end

end
