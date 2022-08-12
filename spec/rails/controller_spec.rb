# frozen_string_literal: true

RSpec.describe Cutoff::Rails::Controller, type: :controller do
  before do
    Timecop.freeze
  end

  base_controller = Class.new(ActionController::Base) do
    def self.name
      'TestController'
    end

    def index
      Timecop.travel(Integer(params[:duration]))
      Cutoff.checkpoint!
      head :ok
    end
  end

  context 'with no cutoff' do
    controller(base_controller) {} # rubocop:disable Lint/EmptyBlock

    it 'does nothing at checkpoint' do
      get :index, params: { duration: 10 }
    end
  end

  context 'with 5s cutoff' do
    controller(base_controller) do
      cutoff 5
    end

    it 'raises CutoffExceededError' do
      expect do
        get :index, params: { duration: 10 }
      end.to raise_error(Cutoff::CutoffExceededError)
    end
  end

  context 'with controller subclass' do
    parent = Class.new(base_controller) do
      cutoff 5
    end

    controller(parent) {} # rubocop:disable Lint/EmptyBlock

    it 'uses cutoff of the parent' do
      expect do
        get :index, params: { duration: 7 }
      end.to raise_error(Cutoff::CutoffExceededError)
    end
  end

  context 'with controller subclass with longer cutoff' do
    parent = Class.new(base_controller) do
      cutoff 5
    end

    controller(parent) do
      cutoff 15
    end

    it 'increases the allowed seconds' do
      get :index, params: { duration: 12 }
    end
  end

  context 'with controller subclass with shorter cutoff' do
    parent = Class.new(base_controller) do
      cutoff 5
    end

    controller(parent) do
      cutoff 2
    end

    it 'decreases the allowed seconds' do
      get :index, params: { duration: 1 }
    end
  end

  context 'with controller with multiple cutoff calls' do
    controller(base_controller) do
      cutoff 3
      cutoff 5
    end

    it 'uses last allowed seconds value' do
      get :index, params: { duration: 4 }
    end
  end

  context 'with callback exclude filter' do
    controller(base_controller) do
      cutoff 5, except: :index
    end

    it 'ignores the cutoff' do
      get :index, params: { duration: 7 }
    end
  end
end
