class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index ]

  def index
    if user_signed_in?
      @file = ContentItem.new
      @query = params[:q].to_s.strip
      @content_items = current_user.content_items.where(parent_id: nil)
      if @query.present?
        like_query = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
        @content_items = @content_items.where("name ILIKE :q OR extracted_text ILIKE :q", q: like_query)
      end
      @content_items = @content_items.order(created_at: :desc)
      render "home/index"
    else
      render :index
    end
  end
end
