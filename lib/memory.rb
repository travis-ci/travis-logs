require 'java'

import java.lang.management.ManagementFactory

class Memory
  class << self
    def dump_stats
      interval = 5
      memory = new
      Thread.new do
        loop do
          begin
            memory.stats
          rescue Exception => e
            puts e.message, e.backtrace
          end
          sleep(interval)
        end
      end
    end
  end

  def stats
    puts "Current heap usage: #{memory_manager.heap_memory_usage}"
    puts "Current non-heap usage: #{memory_manager.non_heap_memory_usage}"
    puts "Waiting to finalize: #{memory_manager.object_pending_finalization_count}"

    # total_collections = 0
    # total_time = 0.0
    # for gc in gc_beans
    #   puts "Name: #{gc.name}"
    #   puts "  Pools: #{gc.memory_pool_names.to_a.join(', ')}"
    #   puts "  Collections: #{gc.collection_count}"
    #   puts "  Time: #{gc.collection_time}"
    #   total_collections += gc.collection_count
    #   total_time += gc.collection_time
    # end
    # puts "Total collections: #{total_collections}"
    # puts "Total time: #{total_time}"
    # puts
  end

  def memory_manager
    ManagementFactory.memoryMXBean
  end

  def gc_beans
    ManagementFactory.garbageCollectorMXBeans
  end

  # def memory_managers
  #   ManagementFactory.memory_manager_mxbeans
  # end

  # def memory_pools
  #   ManagementFactory.memory_pool_mxbeans
  # end
end

