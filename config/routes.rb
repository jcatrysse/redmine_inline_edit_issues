# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

resources :projects, :only => [] do
  resources :inline_issues, :only => [] do
    collection do
      get :edit_multiple
    end
  end
end

resources :inline_issues, :only => [] do
  collection do
    get :edit_multiple
    put :update_multiple
  end
end


  
