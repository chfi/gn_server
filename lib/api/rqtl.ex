defmodule GnServer.Router.Rqtl do

  use Maru.Router

  namespace :genotype do

    namespace :mouse do

      route_param :cross, type: String do

        plug CORSPlug, headers: ["Range", "If-None-Match", "Accept-Ranges"], expose: ["Content-Range"]

        params do
          requires :file,       type: String
          optional :chr,        type: String
          optional :start,      type: Float
          optional :end, 				type: Float
        end

        get do
          # this should probably be done in a... better way.
          path = "./genotype/" <> params[:cross] <> "_" <> params[:file] <> ".csv"

          conn
          |> GnServer.Utility.serve_file(path, "text/csv", 206)
        end
      end
    end
  end
end

defmodule GnServer.Router.QTL do

  use Maru.Router
  namespace :qtl do
    route_param :file, type: String do
      plug CORSPlug, headers: ["Range", "If-None-Match", "Accept-Ranges"], expose: ["Content-Range"]

      get do
        path = "./qtl/" <> params[:file]

        conn
        |> GnServer.Utility.serve_file(path, "text/csv", 206)
      end
    end
  end
end

defmodule GnServer.Router.SNP do

  use Maru.Router

  namespace :snp do
    route_param :file, type: String do
      plug CORSPlug, headers: ["Range", "If-None-Match", "Accept-Ranges"], expose: ["Content-Range"]

      # params do
      # optional :chr,        type: String
      # optional :start,      type: Float
      # optional :end, 				type: Float
      # end

      get do
        IO.inspect params[:file]
        path = "./snptest/" <> params[:file]

        conn
        |> GnServer.Utility.serve_file(path, "application/x-gzip", 206)
      end
    end
  end
end

defmodule GnServer.Router.Stylesheets do

  use Maru.Router

  namespace :stylesheets do
    route_param :file, type: String do
      plug CORSPlug, headers: ["Range", "If-None-Match", "Accept-Ranges"], expose: ["Content-Range"]

      get do
        path = "./bd-stylesheets/" <> params[:file]

        conn
        |> GnServer.Utility.serve_file(path, "application/xml", 200)
      end

    end
  end
end
