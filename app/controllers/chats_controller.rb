class ChatsController < ApplicationController
  TENANT_ID = ''
  CLIENT_ID = ''
  CLIENT_SECRET = ''
  CLIENT_BASE_URL = ""
  # PUB_SUB_ACCESS_URL = 'https://inbox-messaging.webpubsub.azure.com/api/hubs/Hub/:generateToken?api-version=2023-07-01&group={group_name}'

  # POST {endpoint}/api/hubs/{hub}/:generateToken?userId={userId}&role={role}&minutesToExpire={minutesToExpire}&api-version=2023-07-01&group={group}

  def login
    users = {
      "joule": "1",
      "blufftech": "2"
    }.with_indifferent_access
    name = params[:name].to_s.downcase

    render json: { name: name, userId: users[name] }
  end

  def add_user
    redis = Redis.new
    add_user_url = "https://inbox-messaging.webpubsub.azure.com/api/hubs/Hub/users/#{params[:userId]}/groups/#{params[:groupName]}?api-version=2023-07-01"

    puts "add_user_url:-----" + add_user_url

    access_token = redis.get('access_token')
    res = RestClient.put add_user_url, {}, {:Authorization => "Bearer #{access_token}"}
    render json: {code: res.code}
  end

  def users_list
    users = [
      { "name": "Joule", "userId": "1" },
      { "name": "Blufftech", "userId": "2" }
  ]

    render json: users
  end

  def negotiate
    byebug
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
    group_name = params[:groupName]
    
    # url = "https://inbox-messaging.webpubsub.azure.com/api/hubs/Hub/:generateToken?api-version=2023-07-01&userId=#{params[:userId]}&group=#{group_name}"

    roles = ["webpubsub.joinLeaveGroup.#{group_name}", "webpubsub.sendToGroup.#{group_name}"]
    
    url = "https://inbox-messaging.webpubsub.azure.com/api/hubs/Hub/:generateToken?api-version=2023-07-01&userId=#{params[:userId]}&group=#{group_name}&role=#{roles}"    

    puts "access_url:-----" + url
    res = RestClient.post url, {}, {:Authorization => "Bearer #{entra_token}"}
    access_token = JSON.parse(res.body)['token']

    puts "access_token: #{access_token}"
    
    client_url = CLIENT_BASE_URL + access_token

    render json: { client_url: client_url }
  end

  def broadcast
    redis = Redis.new
    message = params[:message]
    user_id = params[:userId]
    group_name = params[:groupName]
    from_user = params[:fromUser]

    access_token = redis.get('access_token')

    endpoint = "https://inbox-messaging.webpubsub.azure.com/api/hubs/Hub/groups/#{group_name}/:send?api-version=2023-07-01&filter=startswith(userId, '#{user_id}')"

    # endpoint = "https://inbox-messaging.webpubsub.azure.com/api/hubs/Hub/groups/#{group_name}/:send?api-version=2023-07-01"

    puts "endpoint:-----" + endpoint

    message ||= "Its working"
    # message = {
    #   "type": "sendToGroup",
    #   "group": group_name,
    #   "dataType": "text",
    #   "data": message,
    #   "ackId": 1,
    #   "fromUserId": 100
    # }

    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{access_token}"
    }

    begin
      retries ||= 0
      
      response = RestClient.post(endpoint, message.to_json, headers)
      puts response.body.inspect
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
