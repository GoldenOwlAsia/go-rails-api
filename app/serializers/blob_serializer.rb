class BlobSerializer < ApplicationSerializer
  identifier :signed_id

  field :url do |object|
    file_url(object)
  end

  view :detail do
    fields :content_type,
           :byte_size

    field :filename do |object|
      object.filename&.to_s
    end

    field :created_at do |object|
      object.created_at&.to_i
    end
  end
end
