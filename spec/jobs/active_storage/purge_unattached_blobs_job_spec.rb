require 'rails_helper'

describe ActiveStorage::PurgeUnattachedBlobsJob do
  it_behaves_like 'enqueues_job_correctly', :low

  describe '#perform' do
    before do
      [
        { filename: 'hello_0.txt', created_at: 1.day.ago - 1.hour },
        { filename: 'hello_1.txt', created_at: 1.day.ago + 1.hour }
      ].each do |attributes|
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new('hello'),
          filename: attributes[:filename]
        )
        blob.update(created_at: attributes[:created_at])
      end
    end

    it 'deletes file has been unattached over 1 day' do
      described_class.perform_now

      expect(ActiveStorage::Blob.where(filename: 'hello_0.txt').count).to eq(0)
      expect(ActiveStorage::Blob.where(filename: 'hello_1.txt').count).to eq(1)
    end
  end
end
