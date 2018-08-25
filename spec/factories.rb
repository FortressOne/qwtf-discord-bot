FactoryBot.define do 
  factory :qstat_request do
    endpoint { "fortressone.ga" }

    initialize_with { new(endpoint) }
  end
end
