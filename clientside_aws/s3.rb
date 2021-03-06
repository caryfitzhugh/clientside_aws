helpers do
  def list_buckets
    buckets = AWS_REDIS.keys "s3:bucket:*"

    xml = Builder::XmlMarkup.new()
    xml.instruct!
    xml.ListAllMyBucketsResult(:xmlns => "http://doc.s3.amazonaws.com/2006-03-01") do
      xml.Owner do
        xml.tag!(:ID, UUID.new.generate)
        xml.tag!(:DisplayName, "Fake Owner")
      end
      xml.Buckets do
        buckets.each do |bucket|
          xml.Bucket do
            xml.tag!(:Name, bucket.split(":").last)
            xml.tag!(:CreationDate, Time.at(AWS_REDIS.hget(bucket, "created_at").to_i).xmlschema)
          end
        end
      end
    end

    content_type :xml
    xml.target!
  end

  def list_objects(bucket)

    xml = Builder::XmlMarkup.new()
    xml.instruct!
    xml.ListAllMyBucketsResult(:xmlns => "http://doc.s3.amazonaws.com/2006-03-01") do
      xml.tag!(:Name, bucket)
      xml.tag!(:Prefix, nil)
      xml.tag!(:Marker, nil)
      xml.tag!(:MaxKeys, 1000)
      xml.tag!(:IsTruncated, false)

      objects = AWS_REDIS.keys "s3:bucket:#{bucket}:*"
      objects.each do |object|
        xml.Contents do

          key = AWS_REDIS.hget object,  "key"
          last_modified = AWS_REDIS.hget object, "last_modified"
          etag = AWS_REDIS.hget object, "etag"
          size = AWS_REDIS.hget object, "size"

          xml.tag!(:Key, key)
          xml.tag!(:LastModified, Time.at(last_modified.to_i).xmlschema)
          xml.tag!(:ETag, etag)
          xml.tag!(:Size, size)
          xml.tag!(:Storage, "STANDARD")
          xml.Owner do
            xml.tag!(:ID, UUID.new.generate)
            xml.tag!(:DisplayName, "fake@example.com")
          end
        end
      end
    end
    content_type :xml
    xml.target!
  end

  def objectNotFound
    xml = Builder::XmlMarkup.new()
    xml.instruct!
    xml.Error do
      xml.tag!(:Code, "NoSuchKey")
      xml.tag!(:Message, "The specified key does not exist.")
    end
    content_type :xml
    xml.target!
  end


  def downloadFile(bucket, obj_name)
    obj_key = "s3:bucket:#{bucket}:#{obj_name}"
    return AWS_REDIS.hget obj_key, 'body'
  end

end

get "/s3/" do
  if env['SERVER_NAME'].match(/\./)
    bucket = env['SERVER_NAME'].split(".").first
    list_objects(bucket)
  else
    list_buckets
  end
  status 200
end

get "/s3/*" do
  bucket = nil
  file = nil

  # handle S3 downloading from the 'servers'
  if params[:splat].first.match(/\//)
    bucket, file = params[:splat].first.split(/\//)
  elsif env['SERVER_NAME'].match(/\./)
    bucket = env['SERVER_NAME'].split(".").first
    file = params[:splat].first
  else
    halt 404, "unknown bucket"
  end

  halt 404, objectNotFound if AWS_REDIS.hget("s3:bucket:#{bucket}:#{file}", "body").nil?

  body = downloadFile(bucket, file)
  content_type = AWS_REDIS.hget("s3:bucket:#{bucket}:#{file}", "content-type")
  response.headers["Content-Type"] = content_type.nil? ? 'html' : content_type
  # response.headers["Content-Length"] = body.length.to_s
  response.headers["ETag"] = Digest::MD5.hexdigest(body)
  response.body = body

  status 200
end

delete "/s3/*" do
  # delete the given key
  if env['SERVER_NAME'].match(/\./)
    bucket = env['SERVER_NAME'].split(".").first
    AWS_REDIS.del "s3:bucket:#{bucket}:#{params[:splat]}"
  end
  status 200
end


put "/s3/" do
  # bucket creation
  bucket = env['SERVER_NAME'].split(".").first
  AWS_REDIS.hset "s3:bucket:#{bucket}", "created_at", Time.now.to_i
  status 200
end

put "/s3/*" do
  params[:file] = params[:splat].first

  # upload the file (chunking not implemented) to fake S3
  if params[:file]
    body_send = nil
    file_location = params[:file]
    bucket = env['SERVER_NAME'].split(".").first
    if ENV['RACK_ENV'] == 'development'
      body_send = request.body.read
    else
      body_send = params[:body]
    end
    AWS_REDIS.hset "s3:bucket:#{bucket}:#{file_location}", "body", body_send
    if env.has_key?('content-type')
      AWS_REDIS.hset "s3:bucket:#{bucket}:#{file_location}", "content-type", env['content-type']
    elsif env.has_key?('CONTENT_TYPE')
      AWS_REDIS.hset "s3:bucket:#{bucket}:#{file_location}", "content-type", env['CONTENT_TYPE']
    end
  end
  status 200
end
