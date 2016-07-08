defmodule GnServer.Router.Main do

  use Maru.Router

  IO.puts "Setup routing"

  alias GnServer.Data.Store, as: Store
  alias GnServer.Logic.Assemble, as: Assemble

  get "/species" do
    json(conn, Store.species)
  end

  namespace :groups do
    route_param :species, type: String do
      get do
        json(conn, Store.groups(params[:species]))
      end
    end
  end

  namespace :group do
    route_param :name, type: String do
      get do
        [_,group] = Regex.run ~r/(.*)\.json$/, params[:name]
        json(conn, Assemble.group_info(group))
      end
    end
  end

  namespace :cross do
    route_param :name, type: String do
      get do
        [_,group] = Regex.run ~r/(.*)\.json$/, params[:name]
        json(conn, Assemble.group_info(group))
      end
    end
  end

  namespace :datasets do
    route_param :group, type: String do
      get do
        json(conn, Store.datasets(params[:group]))
      end
    end
  end

  namespace :dataset do
    route_param :dataset_name, type: String do
      get do
        [_,dataset_name] = Regex.run ~r/(.*)\.json$/, params[:dataset_name]
        json(conn, Assemble.dataset_info(dataset_name))
      end
    end
  end

  namespace :phenotypes do
    route_param :dataset_name, type: String do
      params do
        optional :start, type: Integer
        optional :stop, type: Integer
      end
      get do
        [_,dataset_name] = Regex.run ~r/(.*)\.json$/, params[:dataset_name]
        json(conn, Store.phenotypes(dataset_name,params[:start],params[:stop]))
      end
    end
  end

  namespace :phenotype do
    route_param :dataset, type: String do
      route_param :group, type: String do
        route_param :trait, type: String do
          get do
            [_,trait] = Regex.run ~r/(.*)\.json$/, params[:trait]
            json(conn, Store.phenotype_info(params[:dataset],trait,params[:group]))
          end
        end
      end
    end
  end

  namespace :phenotype do
    route_param :dataset, type: String do
      route_param :trait, type: String do
        get do
          [_,trait] = Regex.run ~r/(.*)\.json$/, params[:trait]
          json(conn, Store.phenotype_info(params[:dataset],trait))
        end
      end
    end
  end

  namespace :genotype do
    route_param :species, type: String do
      namespace :marker do
        route_param :marker, type: String do
          get do
            [_,marker] = Regex.run ~r/(.*)\.json$/, params[:marker]
            json(conn, Store.marker_info(params[:species],marker))
          end
        end
      end
    end
  end

  get do
    json(conn, %{"I am": :genenetwork})
  end

  get "/hey" do
    json(conn, %{"I am": :genenetwork})
  end

end
