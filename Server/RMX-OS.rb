#:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=
# RPG Maker XP Online System (RMX-OS)
#------------------------------------------------------------------------------
# Author: Blizzard
#:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=
# 
#   This work is licensed under BSD License 2.0:
# 
# #----------------------------------------------------------------------------
# #  
# # Copyright (c) Boris "Blizzard" Mikić
# # All rights reserved.
# # 
# # Redistribution and use in source and binary forms, with or without
# # modification, are permitted provided that the following conditions are met:
# # 
# # 1.  Redistributions of source code must retain the above copyright notice,
# #     this list of conditions and the following disclaimer.
# # 
# # 2.  Redistributions in binary form must reproduce the above copyright
# #     notice, this list of conditions and the following disclaimer in the
# #     documentation and/or other materials provided with the distribution.
# # 
# # 3.  Neither the name of the copyright holder nor the names of its
# #     contributors may be used to endorse or promote products derived from
# #     this software without specific prior written permission.
# # 
# # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# # AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# # IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# # ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# # LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# # CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# # SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# # INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# # CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# # ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# # POSSIBILITY OF SUCH DAMAGE.
# #  
# #----------------------------------------------------------------------------
# 
#   You may use this script for both non-commercial and commercial products
#   without limitations as long as you fulfill the conditions presented by the
#   above license. The "complete" way to give credit is to include the license
#   somewhere in your product (e.g. in the credits screen), but a "simple" way
#   is also acceptable. The "simple" way to give credit is as follows:
# 
#     RPG Maker XP Online System licensed under BSD License 2.0
#     Copyright (c) Boris "Blizzard" Mikić
# 
#   Alternatively, if your font doesn't support diacritic characters, you may
#   use this variant:
# 
#     RPG Maker XP Online System licensed under BSD License 2.0
#     Copyright (c) Boris "Blizzard" Mikic
# 
#   In general other similar variants are allowed as long as it is clear who
#   the creator is (e.g. "RMX-OS created by Blizzard" is
#   acceptable). But if possible, prefer to use one of the two variants listed
#   above.
# 
#   If you fail to give credit and/or claim that this work was created by you,
#   this may result in legal action and/or payment of damages even though this
#   work is free of charge to use normally.
# 
#:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=:=

RMXOS_VERSION = 2.06

begin
	load 'src/Data.rb'
	load 'src/Debug.rb'
	load 'src/Error.rb'
	load 'src/Result.rb'
	load 'src/Misc.rb'
rescue SyntaxError
	puts $!.message
	gets
	exit
end

# loading settings
begin
	load './cfg.ini'
rescue SyntaxError
	puts RMXOS::Error::ConfigFile
	puts RMXOS::Data::PressEnter
	gets
	exit
end

# in case somebody messed up the config of extensions
EXTENSIONS.compact!

RUBY_VERSION =~ /(\d+.\d+)/
version = $1
# following errors can happen even before RMX-OS was initialized properly
if !File.directory?("./bin/#{version}") # Ruby version unsupported
	puts RMXOS::Data.args(RMXOS::Error::WrongRubyVersion_VERSION, {'VERSION' => RUBY_VERSION})
	gets
	exit
end
if NAME == nil || NAME == '' # game name not defined
	puts RMXOS::Error::GameUndefined
	gets
	exit
end

# loading classes
begin
	load 'src/Action.rb'
	load 'src/ActionPending.rb'
	load 'src/ActionSent.rb'
	load 'src/ActionHandler1.rb'
	load 'src/ActionHandler2.rb'
	load 'src/ActionHandler3.rb'
	load 'src/ActionHandler4.rb'
	load 'src/ActionHandler5.rb'
	load 'src/ActionHandler6.rb'
	load 'src/ClientHandler.rb'
	load 'src/Client1.rb'
	load 'src/Client2.rb'
	load 'src/Client3.rb'
	load 'src/Client4.rb'
	load 'src/Options.rb'
	load 'src/Player.rb'
	load 'src/Sender.rb'
	load 'src/Server.rb'
	load 'src/SQL.rb'
rescue SyntaxError
	puts $!.message
	gets
	exit
end

# loading Ruby's libraries
require 'socket'
# loading external libraries
require "./bin/#{version}/mysql_api"

#==========================================================================
# module RMXOS
#--------------------------------------------------------------------------
# This is the container for RMXOS.
#==========================================================================

module RMXOS
	
	# Logging files
	Logs = {}
	Logs['Error'] = 'logs/errors.log'
	Logs['Incoming Message'] = 'logs/messages.log'
	Logs['Outgoing Message'] = 'logs/messages.log'
	Logs['Action'] = 'logs/actions.log'
	Logs['Extension'] = 'logs/extension_errors.log'
	Logs['Debug'] = 'logs/debug.log'
	# misc variables
	@log_mutex = nil
	@clients = nil
	#----------------------------------------------------------------------
	# RMX-OS Main Loop.
	#----------------------------------------------------------------------
	def self.main
		while true
			# clear clients
			@clients = ClientHandler.new
			@log_mutex = Mutex.new
			Client.reset
			ActionHandler.reset
			Sender.reset
			begin
				# try to create a server
				@server = Server.new
				# try to start it
				@server.start
				# try to keep it running
				@server.run
			rescue Interrupt
				@server.shutdown rescue nil
				@server.execute_shutdown rescue nil
				return
			rescue
				# error during server start or while running
				puts RMXOS::Error::UnexpectedError
				puts RMXOS.get_error
			end
			@server.shutdown rescue nil
			@server.force_shutdown rescue nil
			# stop everything if no auto-restart
			break if !AUTO_RESTART
			# wait for N seconds
			print RMXOS::Data::Restart
			(0...RESTART_TIME).each {|i|
				print " #{RESTART_TIME - i}"
				sleep(1)
			}
			puts "\n\n"
			@extensions.each_value {|ext| ext.initialize}
		end
	end
	#----------------------------------------------------------------------
	# Gets all extensions.
	#----------------------------------------------------------------------
	def self.extensions
		return @extensions
	end
	#----------------------------------------------------------------------
	# Gets the currently running Server instance.
	# Returns: Server Instance.
	#----------------------------------------------------------------------
	def self.server
		return @server
	end
	#----------------------------------------------------------------------
	# Gets the current client handler instance.
	# Returns: ClientHandler Instance.
	#----------------------------------------------------------------------
	def self.clients
		return @clients
	end
	#----------------------------------------------------------------------
	# Loads all extensions.
	#----------------------------------------------------------------------
	def self.load_extensions
		@extensions = {}
		puts RMXOS::Data::ExtensionsLoading
		# if there are any extensions defined
		if EXTENSIONS.size > 0
			# for every extension filename
			EXTENSIONS.each {|file|
				file += '.rb' if file[file.size - 3, 3] != '.rb'
				filepath = "./Extensions/#{file}"
				begin
					# try to load the file
					require filepath
					# try to load the actual extension
					extension = self.load_current_extension
					# if version is ok
					if RMXOS_VERSION >= extension::RMXOS_VERSION
						# try to activate it
						extension.initialize
						# try to load the actual extension
						@extensions[file] = extension
						puts RMXOS::Data.args(RMXOS::Data::ExtensionLoaded_FILE_VERSION, {'FILE' => file, 'VERSION' => @extensions[file]::VERSION.to_s})
					else
						# version error
						puts RMXOS::Data.args(RMXOS::Error::ExtensionVersionError_FILE_VERSION, {'FILE' => file, 'VERSION' => extension::RMXOS_VERSION.to_s})
					end
				rescue SyntaxError
					puts RMXOS::Data.args(RMXOS::Error::ExtensionLoadError_FILE, {'FILE' => file})
					puts $!.message
				rescue Errno::ENOENT
					puts RMXOS::Data.args(RMXOS::Error::ExtensionFileNotFound_FILE, {'FILE' => file})
				rescue
					puts RMXOS::Data.args(RMXOS::Error::ExtensionInitError_FILE, {'FILE' => file})
					puts RMXOS.get_error
				end
			}
		else
			puts RMXOS::Data::NoExtensions
		end
	end
	#----------------------------------------------------------------------
	# Gets a string representing the time for SQL queries.
	#  time - Time instance
	# Returns: String in SQL time format.
	#----------------------------------------------------------------------
	def self.get_sqltime(time)
		return time.strftime('%Y-%m-%d %H-%M-%S')
	end
	#----------------------------------------------------------------------
	# Gets a string of numbers that can be used to instantiate a Time object.
	#  time - SQL time string
	# Returns: Time string separated by commas.
	#----------------------------------------------------------------------
	def self.get_rubytime(time)
		return time.gsub('-', ',').gsub(':', ',').gsub(' ', ',').gsub(/,0(\d)/) {",#{$1}"}
	end
	#----------------------------------------------------------------------
	# Fixes strings for SQL queries and eval expressions.
	#  string - string to be converted
	# Returns: Converted string.
	#----------------------------------------------------------------------
	def self.sql_string(string)
		return @server.sql.escape_string(string)
	end
	#----------------------------------------------------------------------
	# Fixes strings for SQL queries and eval expressions.
	#  string - string to be converted
	# Returns: Converted string.
	#----------------------------------------------------------------------
	def self.make_message(*args)
		return args.map {|arg| arg = arg.to_s}.join("\t")
	end
	#----------------------------------------------------------------------
	# Gets error message with stack trace.
	# Returns: Error message with stack trace.
	#----------------------------------------------------------------------
	def self.get_error
		return ($!.message + "\n" + $!.backtrace.join("\n").sub(Dir.getwd, '.'))
	end
	#----------------------------------------------------------------------
	# Logs a message into a file.
	#  data - the data that created this log
	#  type - what kind of log
	#  message - message to be logged
	#----------------------------------------------------------------------
	def self.log(data, type, message)
		@log_mutex.synchronize {
			return if type == 'Debug' && !DEBUG_MODE
			return if !RMXOS::Logs.has_key?(type)
			# use user ID and username if data is player
			data = "#{data.user_id} (#{data.username})" if data.is_a?(Player)
			begin
				# open log file in append mode
				file = File.open(RMXOS::Logs[type], 'a+')
				# write time, data type and message
				file.write("#{Time.now.getutc.to_s}; #{data} - #{type}:\n#{message}\n") rescue nil
				file.close()
			rescue
			end
		}
	end
	
end

puts RMXOS::Data::Header
puts RMXOS::Data.args(RMXOS::Data::Version, {'VERSION' => RMXOS_VERSION.to_s, 'RUBY_VERSION' => RUBY_VERSION})
puts RMXOS::Data.args(RMXOS::Data::GameVersion, {'NAME' => NAME.to_s, 'VERSION' => GAME_VERSION.to_s})
puts RMXOS::Data::Header
begin
	# load extensions
	RMXOS.load_extensions
	# RMX-OS main
	RMXOS.main
rescue Interrupt # CTRL + C
end
begin
	# last message
	puts ''
	puts RMXOS::Data::PressEnter
	gets if RMXOS.server.prompt_thread == nil
rescue Interrupt # CTRL + C
end
