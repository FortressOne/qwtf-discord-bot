FactoryBot.define do 
  factory :qstat_request do
    endpoint { "fortressone.org" }

    initialize_with { new(endpoint) }
  end
end
