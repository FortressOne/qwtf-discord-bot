require 'pry'

RSpec.describe QstatRequest do
  let(:qstat_request) { build(:qstat_request, result: result) }

  describe "#to_embed" do
    let(:embed) { qstat_request.to_embed }

    context "when request returns error" do
      let(:result) { File.read('spec/qstat_responses/error.txt') }

      it "returns nil" do
        expect(embed).to be nil
      end
    end

    context "when request doesn't return an error" do
      context "and server is empty" do
        let(:result) { File.read('spec/qstat_responses/empty.txt') }

        it "returns nil" do
          expect(embed).to be nil
        end
      end

      context "and server is not empty" do
        let(:result) { File.read('spec/qstat_responses/one_spectator.txt') }

        it "returns instance of Discordrb::Webhooks::Embed" do
          expect(embed).to be_instance_of Discordrb::Webhooks::Embed
        end

        context "when contains a single user" do
          let(:result) { File.read('spec/qstat_responses/one_spectator.txt') }

          it "has a single field" do
            expect(embed.fields.size).to be 1
          end
        end

        context "when contains a spectator" do
          let(:result) { File.read('spec/qstat_responses/one_spectator.txt') }

          it 'has a field named "Spec"' do
            expect(embed.fields.any? { |field| field.to_hash[:name] == "Spec" }).to be true
          end
        end

        context "when contains a player without a team" do
          let(:result) { File.read('spec/qstat_responses/one_player_without_team.txt') }

          it 'has a field named "Spec"' do
            expect(embed.fields.any? { |field| field.to_hash[:name] == "Spec" }).to be true
          end
        end

        context "when contains a player on the blue team" do
          let(:result) { File.read('spec/qstat_responses/one_blue_player.txt') }

          it 'has a field named "Blue"' do
            expect(embed.fields.any? { |field| field.to_hash[:name].include? "Blue" }).to be true
          end
        end

        context "when contains a player on the red team" do
          let(:result) { File.read('spec/qstat_responses/one_red_player.txt') }

          it 'has a field named "Red"' do
            expect(embed.fields.any? { |field| field.to_hash[:name].include? "Red" }).to be true
          end
        end

        context "when contains three players on the blue team" do
          let(:result) { File.read('spec/qstat_responses/three_blue_players.txt') }

          it 'has one field' do
            expect(embed.fields.size).to be 1
          end

          it 'named "Blue"' do
            expect(embed.fields.first.to_hash[:name]).to include "Blue"
          end
        end

        context "when contains blue and red players and a spectator" do
          let(:result) { File.read('spec/qstat_responses/full.txt') }

          it 'has three fields' do
            expect(embed.fields.size).to be 3
          end

          it 'the first field is named "Blue"' do
            expect(embed.fields.first.to_hash[:name].include?("Blue")).to be true
          end

          it 'the second field is named "Red"' do
            expect(embed.fields[1].to_hash[:name].include?("Red")).to be true
          end

          it 'the last field is named "Spec"' do
            expect(embed.fields.last.to_hash[:name].include?("Spec")).to be true
          end
        end
      end
    end
  end
end
