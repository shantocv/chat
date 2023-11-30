Rails.application.routes.draw do
  post 'chats/negotiate'
  post 'chats/broadcast'
  get 'chats/login'
  get 'chats/users_list'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
