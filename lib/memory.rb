require 'java'
require 'core_ext/kernel/run_periodically'

import java.lang.management.ManagementFactory

class Memory
  class << self
    def report_periodically
      new.report_periodically
    end
  end

  def report_periodically
    run_periodically(60) do
      begin
        log
        meter
      rescue Exception => e
        puts e.message, e.backtrace
      end
    end
  end

  def log
    stats.each do |key, value|
      puts "[memory] #{key}: #{value.to_s}"
    end
  end

  def meter
    [:used, :committed].each do |key|
      Metriks.meter("v1.travis-logs.memory.heap.#{key}").mark(heap.send(key))
    end
  end

  private

    def stats
      { :heap => heap, :non_heap => non_heap, :waiting => waiting }
    end

    def heap
      memory_manager.heap_memory_usage
    end

    def non_heap
      memory_manager.non_heap_memory_usage
    end

    def waiting
      memory_manager.object_pending_finalization_count
    end

    def memory_manager
      @memory_manager ||= ManagementFactory.memoryMXBean
    end

    # def gc_beans
    #   @gc_beans ||= ManagementFactory.garbageCollectorMXBeans
    # end

    # def memory_managers
    #   ManagementFactory.memory_manager_mxbeans
    # end

    # def memory_pools
    #   ManagementFactory.memory_pool_mxbeans
    # end
end

