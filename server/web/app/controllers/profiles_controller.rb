require 'rexml/document'
require 'prettyxml'

class ProfilesController < ApplicationController
	def index
		@profiles = Profile.find(:all)
	end

	# GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
	verify :method => :post, :only => [ :destroy, :create, :update ],
               :redirect_to => { :action => :list }

	def show
		@profile = Profile.find(params[:id])
		@text = PrettyXML.make(REXML::Document.new(@profile.xml)).gsub(/^\n\n/, '')
	end

	def new
		@profile = Profile.new
	end

	def create
		begin
			REXML::Document.new(params[:profile][:xml])
		rescue
			flash[:notice] = 'Wrong XML'
			render :action => 'Edit'
			return
		end
		@profile = Profile.new(params[:id])
		if @profile.save
			flash[:notice] = 'Profile was successfully created.'
			redirect_to :action => 'index'
		else
			render :action => 'new'
		end
	end

	def edit
		@profile = Profile.find(params[:id])
		@models = Model.find(:all, :order => :name).map { |x| [x.name, x.id] }.unshift(['', nil])
		@default_model_id = @profile.model ? @profile.model.id : nil
	end

	def update
		begin
			REXML::Document.new(params[:profile][:xml])
		rescue
			flash[:notice] = 'Wrong XML'
			render :action => 'edit'
			return
		end
		@profile = Profile.new
		@profile.xml = params[:profile][:xml]
		@profile.feature = params[:profile][:feature]
		@profile.model_id = params[:model][:id]
		@profile.timestamp = Time.now		
		if @profile.save!
			flash[:notice] = 'Profile was successfully created.'
			redirect_to :action => 'index'
		else
			render :action => 'new'
		end
	end

	def destroy
		Profile.find(params[:id]).destroy
		redirect_to :action => 'list'
	end
end
