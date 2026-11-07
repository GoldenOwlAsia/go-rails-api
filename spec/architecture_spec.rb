require 'rails_helper'

describe 'Architecture boundaries' do
  def offenses(globs, pattern)
    Array(globs).flat_map { |glob| Rails.root.glob(glob) }.flat_map do |path|
      path.readlines.each_with_index.filter_map do |line, index|
        next if line.match?(/\A\s*#/) || !line.match?(pattern)

        "#{path.relative_path_from(Rails.root)}:#{index + 1}: #{line.strip}"
      end
    end
  end

  def classes_in(layer, except: [])
    Rails.root.glob("app/#{layer}/**/*.rb").filter_map do |path|
      name = path.relative_path_from(Rails.root.join('app', layer)).to_s.delete_suffix('.rb')
      next if name.start_with?('concerns/')

      constant = name.camelize.constantize
      constant if constant.is_a?(Class) && except.exclude?(constant.name)
    end
  end

  describe 'layers this repo does not have' do
    it 'introduces no parallel layer directory' do
      forbidden = %w[services forms interactors presenters].select { |dir| Rails.root.join('app', dir).exist? }

      message = "app/#{forbidden.join(', app/')} exists. What other codebases call a Service Object " \
                'is an Operation here (app/operations). Adding a layer is a decision for the whole team: see ' \
                '.claude/rules/rails-architecture.md, "Layers this repo does not have".'

      expect(forbidden).to be_empty, message
    end
  end

  describe 'error handling' do
    it 'has no blanket rescue anywhere in app/' do
      blanket = /
        \brescue(_from)?\s+(::)?(StandardError|Exception)\b # rescue StandardError, rescue_from Exception
        | \brescue\s*(=>.*)?$                               # bare rescue, rescue => e
        | \S\s+rescue\s+\S                                  # the modifier form: foo rescue nil
      /x
      found = offenses('app/**/*.rb', blanket)

      message = "Blanket rescue:\n#{found.join("\n")}\n" \
                'ExceptionFilter already renders the failures clients should see, and anything else is a bug that ' \
                'should reach Sentry and Sidekiq retry. Rescue the specific error you have a plan for: see ' \
                '.claude/rules/serializers-and-errors.md.'

      expect(found).to be_empty, message
    end
  end

  describe 'controllers' do
    # These act only on current_user, so there is no record to authorize.
    let(:no_policy_needed) { %w[app/controllers/api/v1/auth/profiles_controller.rb] }

    it 'inherits BaseController or a Devise controller under API::V1' do
      strays = classes_in('controllers').select { |klass| klass.name.start_with?('API::') }.reject do |klass|
        klass == API::V1::BaseController || klass < API::V1::BaseController || klass < DeviseController
      end

      message = "#{strays.join(', ')} skips API::V1::BaseController, so it does not get authenticate_user!: see " \
                '.claude/rules/controllers.md.'

      expect(strays).to be_empty, message
    end

    it 'authorizes somewhere in every controller built on BaseController' do
      found = Rails.root.glob('app/controllers/api/**/*_controller.rb').filter_map do |path|
        relative = path.relative_path_from(Rails.root).to_s
        source = path.read
        next if no_policy_needed.include?(relative) || relative.end_with?('/base_controller.rb')
        next unless source.match?(/<\s*BaseController\b/)

        relative unless source.match?(/\b(authorize|policy_scope)\b/)
      end

      message = "No authorize or policy_scope in:\n#{found.join("\n")}\n" \
                'Nothing enforces Pundit here, so such a controller is open to every signed-in user: see ' \
                '.claude/rules/controllers.md.'

      expect(found).to be_empty, message
    end
  end

  describe 'models' do
    it 'dispatches no mail or background work' do
      found = offenses('app/models/**/*.rb', /deliver_later|deliver_now|perform_later|perform_async/)

      message = "Workflow in a model:\n#{found.join("\n")}\n" \
                'Sending mail or enqueuing a job is a workflow and belongs in an Operation, not a model or its ' \
                'callbacks: see .claude/rules/models-and-migrations.md and .claude/rules/rails-transactions.md.'

      expect(found).to be_empty, message
    end
  end

  describe 'layer base classes' do
    {
      'operations' => 'ApplicationOperation',
      'queries' => 'ApplicationQuery',
      'policies' => 'ApplicationPolicy',
      'serializers' => 'ApplicationSerializer',
      'decorators' => 'ApplicationDecorator',
      'jobs' => 'ApplicationJob',
      'mailers' => 'ApplicationMailer',
      'errors' => 'APIError::StandardError'
    }.each do |layer, base_name|
      it "has every class in app/#{layer} inherit #{base_name}" do
        base = base_name.constantize
        strays = classes_in(layer, except: [base_name]).reject { |klass| klass < base }

        expect(strays).to be_empty, "#{strays.join(', ')} does not inherit #{base_name}."
      end
    end
  end
end
