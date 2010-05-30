require 'rake/clean'
CLEAN   = FileList["build/vaedit*"]
SRC     = FileList["src/*.vala"]
DEPS    = %w[gee-1.0 gio-2.0 gtksourceview-2.0 gtk+-2.0]
CC_OPTS = nil

task :default => "build/vaedit"

file "build/vaedit" => SRC do
	sh "valac #{DEPS.empty? ? '' : '--pkg '+DEPS.join(' --pkg ')} -o build/vaedit #{SRC.join(' ')}#{CC_OPTS ? ' -X '+CC_OPTS : ''}"
end

task :debug do
	sh "valac #{DEPS.empty? ? '' : '--pkg '+DEPS.join(' --pkg ')} -g --save-temps --thread -o build/vaedit_dbg #{SRC.join(' ')}#{CC_OPTS ? ' -X '+CC_OPTS : ''}"
end
