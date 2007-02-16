class AcceptancetestsController < ApplicationController
  include CrudActions
  
  before_filter :require_current_project
  popups :new, :create, :edit, :update, :show , :export, :new_acceptance_for_story, :clone_acceptancetest
  
  def mymodel
    Acceptancetest
  end
  
  def clone_acceptancetest
	@object = session[:object] || mymodel.find(params[:id])
	if(params[:story_id])
		@story = Story.find(params[:story_id])
	end
    session[:object] = nil
    @page_title = "Clone #{mymodel}"
  end
  
  def index
    @stories = @project.stories
    @list = mymodel.find(:all, :order => mymodel.editlist_order, :conditions => [ "project_id = (?)", @project.id] )
    @page_title = "Acceptance Tests"
  end
  
  def export
    headers['Content-Type'] = "application/vnd.ms-excel" 
    @list = @project.acceptancetests
    render :layout => false
  end
  
  def new_acceptance_for_story
    @object = session[:object] || Acceptancetest.new
    session[:object] = nil
    @story = Story.find(params[:story_id])
  end

end
