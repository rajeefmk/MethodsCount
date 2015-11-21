#/usr/bin/ruby

require 'fileutils'
require_relative './utils'

class ComputeDependencies 

	attr_reader :library_with_version
	attr_reader :deps_fqn_list

	def initialize(library_name, utils)
		@library = library_name
		@utils = utils
	end

	def fetch_dependencies
		@utils.init_gradle_files()
		@utils.inject_library_name(@library)

		working_dir = @utils.get_working_dir

		deps_raw = `#{working_dir}/gradlew -p #{working_dir} -q dependencies`
		has_succeded = $?.exitstatus
		if has_succeded != 0
			raise "Error while computing FNQs"
		end

		# extract only the dependencies part
		substr_begin = deps_raw.index(/default\s+-\s+/)
		substr_end = deps_raw.index(/default-mapping\s+-\s+/, substr_begin)
		substr = deps_raw.slice(substr_begin .. substr_end - 1)
		
		@deps_fqn_list = []
		substr.delete! ' |'
		substr.each_line do |line|
			if line[/^(\\|\+|\|){1}-+.*?/]
				updated_line = line.gsub(/^(\\|\+|\|){1}-+/, '').gsub(/\(\*\)/, '').gsub(/\n/, '')
				if line.include?("+")
					updated_line.gsub!(/(.*):[^>]*>(.*)/, '\1:\2')
				end
				@deps_fqn_list.push(updated_line)
			end
		end

		# the first entry is the requested library
		@library_with_version = deps_fqn_list[0]
		@deps_fqn_list.delete_at(0)
	end
end

if __FILE__ == $0
	library_name = ARGV[0]
	if library_name.to_s.empty?
		library_name = "com.github.dextorer:sofa:1.+"
	end

	utils = Utils.new

	begin
		utils.clone_workspace(library_name)
		
		c = ComputeDependencies.new(library_name, utils)
		c.fetch_dependencies()
		
		puts c.library_with_version
		puts c.deps_fqn_list
	ensure
		#utils.restore_workspace()
	end
end