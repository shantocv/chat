class ChatsController < ApplicationController

  PUB_SUB_ACCESS_URL = 'https://inbox-messaging.webpubsub.azure.com/api/hubs/Hub/:generateToken?api-version=2023-07-01&userId={userId}'

  def login
    users = {
      "shanto": "1",
      "satyam": "2"
    }.with_indifferent_access
    name = params[:name].to_s.downcase
    render json: { name: name, userId: users[name] }
  end

  def users_list
    users = [
      { "name": "shanto", "userId": "1" },
      { "name": "satyam", "userId": "2" }
  ]

    render json: users
  end

  def negotiate
    redis = Redis.new
    entra_url = "https://login.microsoftonline.com/#{TENANT_ID}/oauth2/token"


    body = {
      grant_type: 'client_credentials',
      resource: 'https://webpubsub.azure.com',
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET
    }

    # byebug

    # uri = URI(entra_url)
    # Net::HTTP::Post.new(uri.request_uri).set_form_data(body)
    # response = Net::HTTP.post_form( uri, body.to_a )

    response = RestClient.post(entra_url, body)
    entra_token = JSON.parse(response.body)["access_token"]
    redis.set("access_token", entra_token)
    res = RestClient.post PUB_SUB_ACCESS_URL.gsub('{userId}', params[:userId].to_s), {}, {:Authorization => "Bearer #{entra_token}"}
    access_token = JSON.parse(res.body)['token']
    client_url = CLIENT_BASE_URL + access_token

    render json: { client_url: client_url }
  end

  def broadcast
    redis = Redis.new
    message = params[:message]
    user_id = params[:userId]

    access_token = redis.get('access_token')

    endpoint = "https://inbox-messaging.webpubsub.azure.com/api/hubs/Hub/users/#{user_id}/:send?api-version=2023-07-01"

    message ||= "Its working"

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{access_token}"
    }

    begin
      retries ||= 0
      response = RestClient.post(endpoint, message.to_json, headers)
      puts response.body
    rescue => e
      puts e.message 
      if (retries += 1) < 3
        entra_url = "https://login.microsoftonline.com/#{TENANT_ID}/oauth2/token"


        body = {
          grant_type: 'client_credentials',
          resource: 'https://webpubsub.azure.com',
          client_id: CLIENT_ID,
          client_secret: CLIENT_SECRET
        }
    
        # byebug
    
        # uri = URI(entra_url)
        # Net::HTTP::Post.new(uri.request_uri).set_form_data(body)
        # response = Net::HTTP.post_form( uri, body.to_a )
    
        response = RestClient.post(entra_url, body)
        access_token = JSON.parse(response.body)["access_token"]
        redis.set("access_token", access_token)
        headers = {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{access_token}"
        }
        retry
      end
    end
    
    render json: { success: true }
  end
end
