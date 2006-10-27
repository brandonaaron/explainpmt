##############################################################################
# eXPlain Project Management Tool
# Copyright (C) 2005  John Wilger <johnwilger@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
##############################################################################


require File.dirname(__FILE__) + '/../test_helper'
require 'stories_controller'

# Re-raise errors caught by the controller.
class StoriesController; def rescue_action(e) raise e end; end

class StoriesControllerTest < Test::Unit::TestCase
  def setup
    @user_one = User.find 2
    @project_one = Project.find 1
    @iteration_one = Iteration.find 1
    @story_one = Story.find 1
    @story_two = Story.find 2
    @story_three = Story.find 3
    @story_six = Story.find 6

    @controller = StoriesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @request.session[:current_user] = @user_one
  end

  def test_backlog
    get :index, 'project_id' => @project_one.id
    assert_response :success
    assert_template 'index'
    assert_equal [ @story_six ], assigns( :stories )
  end

  def test_backlog_show_cancelled
    get :index, 'project_id' => @project_one.id, 'show_cancelled' => 1
    assert_response :success
    assert_template 'index'
    assert_equal [ @story_six, @story_three ], assigns( :stories )
  end

  def test_backlog_no_iterations
    Iteration.destroy_all
    get :index, 'project_id' => @project_one.id
    assert_response :success
    assert_template 'index'
    assert_tag :tag => "div", :content => "No iterations to move story cards to."
  end

  def test_show
    get :show, 'id' => @story_one.id, 'project_id' => @project_one.id
    assert_response :success
    assert_template 'show'
    assert_equal @story_one, assigns( :story )
  end

  def test_delete
    get :delete, 'id' => @story_one.id, 'project_id' => @project_one.id
    assert_redirected_to :controller => 'stories', :action => 'index',
      :project_id => @project_one.id.to_s
    assert_raise( ActiveRecord::RecordNotFound ) { Story.find @story_one.id }
  end

  def test_delete_from_iteration
    get :delete, 'id' => @story_one.id, 'project_id' => @project_one.id,
      :iteration_id => @iteration_one.id
    assert_redirected_to :controller => 'iterations', :action => 'show',
      :id => @iteration_one.id.to_s, :project_id => @project_one.id.to_s
    assert_raise( ActiveRecord::RecordNotFound ) { Story.find @story_one.id }
  end

  def test_new
    get :new, :project_id => @project_one.id
    assert_response :success
    assert_template 'new'
    assert_equal 'Create new story cards', assigns(:page_title)
  end

  def test_create
    num = @project_one.stories.backlog.size
    previous_stories = @project_one.stories.dup
    post :create, :project_id => @project_one.id,
      :story_card_titles => "New Story One\nNew Story Two\nNew Story Three"
    assert_redirected_to :controller => 'stories', :action => 'list_new', :project_id => @project_one.id
    assert_equal num + 3, @project_one.stories( true ).backlog.size
    new_stories = @project_one.stories - previous_stories
    assert_kind_of Array, session[:new_story_ids]
    new_stories.map{ |s| s.id }.each { |id| assert session[:new_story_ids].include?(id) }
    assert_equal new_stories.size, session[:new_story_ids].size
  end

  def test_create_empty
    num = Story.count
    post :create, :project_id => @project_one.id, :story_card_titles => ''
    assert_redirected_to :controller => 'stories', :action => 'new',
      :project_id => @project_one.id
    assert_equal 'Please enter at least one story card title.', flash[:error]
  end

  def test_edit
    get :edit, 'project_id' => @project_one.id, 'id' => @story_one.id
    assert_response :success
    assert_template 'edit'
    assert_equal @story_one, assigns( :story )
  end

  def test_edit_from_invalid
    @story_one.title = nil
    @request.session[ :edit_story ] = @story_one
    test_edit
    assert_nil session[ :edit_story ]
  end

  def test_update
    post :update, 'project_id' => @project_one.id, 'id' => @story_one.id,
      'story' => { 'title' => 'Test Update', 'status' => 1 }
    assert_redirected_to :controller => 'stories', :action => 'index'
  end
  
  def test_update_return_to_referer
    @request.session[:referer] = 'http://test.host/project/1/iterations/show/1'  
    post :update, 'project_id' => @project_one.id, 'id' => @story_one.id,
      'story' => { 'title' => 'Test Update' } 
    assert_redirected_to 'http://test.host/project/1/iterations/show/1'
  end

  def test_update_invalid
    post :update, 'project_id' => @project_one.id, 'id' => @story_one.id,
      'story' => { 'title' => '' }
    assert_redirected_to :controller => 'stories', :action => 'edit',
      :project_id => @project_one.id.to_s, :id => @story_one.id.to_s
    assert session[ :edit_story ]
  end

  def test_take_ownership
    get :take_ownership, 'id' => @story_one.id, 'project_id' => @project_one.id
    assert_redirected_to :controller => 'iterations', :action => 'show',
      :id => @iteration_one.id.to_s, :project_id => @project_one.id.to_s
    assert flash[ :status ]
    assert_equal @request.session[ :current_user ],
      Story.find( @story_one.id ).owner
  end

  def test_release_ownership
    @story_one.owner = @request.session[ :current_user ]
    @story_one.save

    get :release_ownership, 'id' => @story_one.id,
      'project_id' => @project_one.id
    assert_redirected_to :controller => 'iterations', :action => 'show',
      :id => @iteration_one.id.to_s, :project_id => @project_one.id.to_s
    assert flash[ :status ]
    assert_nil Story.find( @story_one.id ).owner
  end
  
  def test_main_menu_has_correct_current_link
    # new/edit/view story should have no selected item (class="current") in the MainMenu
    for action in [ :new, :show, :edit ]
      get action, 'id' => @story_one.id, 'project_id' => @project_one.id
      assert_no_tag :tag => 'a', :attributes => { :class => 'current' },
        :ancestor => { :tag => 'ul', :attributes => { :id => 'MainMenu' } }
    end
  end
end
