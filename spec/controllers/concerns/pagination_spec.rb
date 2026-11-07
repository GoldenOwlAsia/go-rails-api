require 'rails_helper'

describe Pagination do
  controller(ApplicationController) do
    def index
      pagy, records = paginate(User.order(:email))
      render_resource_collection(records, pagy:)
    end

    def show
      pagy, records = paginate_array(%w[a b c])
      render json: { data: records, meta: paginate_meta(pagy) }
    end
  end

  let(:json) { JSON.parse(response.body) }

  before { create_list(:user, 3) }

  describe '#paginate' do
    it 'returns the requested page and its metadata' do
      get :index, params: { page: { number: 2, size: 2 } }

      expect(response).to have_http_status(:ok)
      expect(json['data'].size).to eq(1)
      expect(json['meta']).to eq(
        'page_size' => 2, 'page_number' => 2, 'total_count' => 3,
        'prev_page' => 1, 'next_page' => nil, 'last_page' => 2
      )
    end

    it 'uses the default page and page size' do
      get :index

      expect(json['data'].size).to eq(3)
      expect(json['meta']).to include('page_size' => 25, 'page_number' => 1, 'prev_page' => nil, 'last_page' => 1)
    end

    it 'returns an empty page when the page is out of range' do
      get :index, params: { page: { number: 9, size: 2 } }

      expect(response).to have_http_status(:ok)
      expect(json['data']).to eq([])
      expect(json['meta']).to include('page_number' => 9, 'next_page' => nil, 'last_page' => 2)
    end

    it 'caps the page size' do
      get :index, params: { page: { size: 100_000 } }

      expect(response).to have_http_status(:ok)
      expect(json['meta']['page_size']).to eq(described_class::MAX_PAGE_SIZE)
    end

    it 'returns an empty page for a very large page number' do
      get :index, params: { page: { number: '9' * 30 } }

      expect(response).to have_http_status(:ok)
      expect(json['data']).to eq([])
    end

    [
      { page: { number: 'abc', size: 'abc' } },
      { page: { number: '0', size: '0' } },
      { page: { number: '-1', size: '-1' } },
      { page: { number: '2x', size: '2x' } },
      { page: { number: { a: 1 }, size: ['1'] } },
      { page: '3' }
    ].each do |invalid_params|
      it "uses the defaults for #{invalid_params}" do
        get :index, params: invalid_params

        expect(response).to have_http_status(:ok)
        expect(json['meta']).to include('page_size' => 25, 'page_number' => 1)
      end
    end
  end

  describe '#paginate_array' do
    it 'paginates a plain array' do
      get :show, params: { id: 1, page: { number: 1, size: 2 } }

      expect(json['data']).to eq(%w[a b])
      expect(json['meta']).to include('total_count' => 3, 'next_page' => 2)
    end
  end
end
