require 'erb'
require 'zlib'

class Server::UserDataController < ApplicationController
	before_filter :login_required
	require_role  :admin,
        :unless => "params[:id].nil? or current_user.has_server_access?(Server.find(params[:id])) "

	def show
		@server = Server.find(params[:id])
		@cluster = @server.cluster
		@provider_account = @cluster.provider_account
		@server_user_data = Server::UserDataController.generate(@server)
		# remove password values before rendering
		(@provider_account.provider_account_parameters +
		 @cluster.cluster_parameters +
		 @server.server_parameters).each do |p|
			@server_user_data.sub!(p.value.sub("'","\'"),'[FILTERED]') if p.is_protected? and !p.value.blank?
		end
	end

	def self.generate(server, compress = false)
		loader_template = File.dirname(__FILE__) + "/../../views/server/user_data/loader"
		payload_template = File.dirname(__FILE__) + "/../../views/server/user_data/generate.erb"
		emissary_template = File.dirname(__FILE__) + '/../../views/server/user_data/emissary.erb'
    
		user_data = ServerUserData.new
		user_data.server = server
		user_data.parameters = server.cluster.provider_account.provider_account_parameters +
			server.cluster.cluster_parameters +
			server.server_parameters
			
		user_data.startup_scripts << StartupScript.new('account_script', server.cluster.provider_account.startup_script || '')
		user_data.startup_scripts << StartupScript.new('cluster_script', server.cluster.startup_script || '')
		user_data.startup_scripts << StartupScript.new('server_script', server.startup_script || '')

		emissary_config = ERB.new(File.read(emissary_template), nil, '%-').result(binding)
		
		erb = ERB.new(File.read(payload_template), nil, "%-")
		payload = erb.result(binding)
		if compress
			loader = File.read(loader_template)
			StringIO.open(loader, 'ab') do |f|
				gz = Zlib::GzipWriter.new(f)
				gz.write payload
				gz.close
			end
			payload = loader
		end
		return payload
	end
end
