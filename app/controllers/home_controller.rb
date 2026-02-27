class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index ]

  def index
      if user_signed_in?
        @content_items = current_user.content_items.where(parent_id: nil)
        @file = ContentItem.new
        render "home/index"
      else
        render :index
      end
  end
end
