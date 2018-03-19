# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class WelcomeController < ApplicationController
  caches_action :robots
  before_action :allow_x_domain, :only => :loginAd

  def index
    redirect_to signin_path
    @news = News.latest User.current
  end

  def robots
    # @projects = Project.all_public.active
    render :layout => false, :content_type => 'text/plain'
  end

  def loginAd
    render :json => {
      :delay => 4000,
      :pics => [
        {:name => "A", :src => view_context.image_url('login_ad.png')},
        {:name => "B", :src => view_context.image_url('login_ad.png')},
      ]
    }
  end
end
