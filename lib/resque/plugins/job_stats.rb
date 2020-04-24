require 'resque'
require 'resque/plugins/job_stats/measured_hook'
require 'resque/plugins/job_stats/performed'
require 'resque/plugins/job_stats/enqueued'
require 'resque/plugins/job_stats/failed'
require 'resque/plugins/job_stats/duration'
require 'resque/plugins/job_stats/timeseries'
require 'resque/plugins/job_stats/statistic'
require 'resque/plugins/job_stats/history'

module Resque
  module Plugins
    module JobStats

      def self.included(base)
        # this is all needed to support ActiveJobs
        # the main difference is `perform` is an instance method, not a class
        # method, and it will not magically call all of our after_<event> hooks
        base.extend Resque::Plugins::JobStats::MeasuredHook
        base.extend Resque::Plugins::JobStats::Performed
        base.extend Resque::Plugins::JobStats::Enqueued
        base.extend Resque::Plugins::JobStats::Failed
        base.extend Resque::Plugins::JobStats::Duration
        base.extend Resque::Plugins::JobStats::Timeseries::Enqueued
        base.extend Resque::Plugins::JobStats::Timeseries::Performed
        base.extend Resque::Plugins::JobStats::History
        self.add_measured_job base

        if base.ancestors.map(&:to_s).include?("ActiveJob::Base")
          # ActiveJob does not magically call all of our after_perform_ABC methods like resque does
          base.after_perform do |job|
            job.class.methods.select do |meth|
              meth.to_s.start_with?("after_perform_")
            end.each do |meth|
              job.class.send(meth)
            end
          end

          base.after_enqueue do |job|
            job.class.methods.select do |meth|
              meth.to_s.start_with?("after_enqueue_")
            end.each do |meth|
              job.class.send(meth)
            end
          end
        end
      end

      include Resque::Plugins::JobStats::MeasuredHook
      include Resque::Plugins::JobStats::Performed
      include Resque::Plugins::JobStats::Enqueued
      include Resque::Plugins::JobStats::Failed
      include Resque::Plugins::JobStats::Duration
      include Resque::Plugins::JobStats::Timeseries::Enqueued
      include Resque::Plugins::JobStats::Timeseries::Performed
      include Resque::Plugins::JobStats::History

      def self.add_measured_job(name)
        Resque.redis.sadd("stats:jobs", name)
      end

      def self.rem_measured_job(name)
        Resque.redis.srem("stats:jobs", name)
      end

      def self.measured_jobs
        Resque.redis.smembers("stats:jobs").collect do
          |c| Object.const_get(c) rescue nil
        end.compact
      end
    end
  end
end
