module Pagination
  extend ActiveSupport::Concern

  MAX_PAGE_SIZE = 100

  def paginate(collection)
    pagy(collection, page: page_number, limit: page_size)
  end
  alias paginate_array paginate

  def paginate_meta(pagy)
    {
      page_size: pagy.limit,
      page_number: pagy.page,
      total_count: pagy.count,
      prev_page: pagy.previous,
      next_page: pagy.next,
      last_page: pagy.last
    }
  end

  def page_number
    page_param(:number) || 1
  end

  def page_size
    [page_param(:size) || Pagy::OPTIONS[:limit], MAX_PAGE_SIZE].min
  end

  private

  def page_param(key)
    page = params[:page]
    value = page[key] if page.is_a?(ActionController::Parameters)
    value.to_i if value.is_a?(String) && value.match?(/\A[1-9]\d*\z/)
  end
end
