#!/usr/bin/env ruby
require File.expand_path("../", __FILE__) + '/qiniuCore.rb'
$syncDir = File.absolute_path(ARGV[0])
$bucket = ARGV[1]

initDb
initConfiguration
$verboseOn = true
$excludeItems = ['.', '..', '.git', '.DS_Store']
$failed = []
def createFileName(filePath)
    fileName = filePath.sub $syncDir, ''
    if fileName.start_with? '/'
        fileName = fileName.sub '/',''
    end
    return fileName
end

def sync(dir)
    Dir.entries(dir).each do |fileEntry|
        #puts "Looping directory fileEntry=#{fileEntry}; dir=#{dir}"
        if $excludeItems.include? fileEntry
            next
        end
        dir = dir + '/' if !dir.end_with? '/'
        filePath = dir + fileEntry
        #puts "filePath = #{filePath}"
        if File.directory?(filePath)
            sync(filePath)
        else
            fileName = createFileName(filePath)
            #puts "uploading filePath=#{filePath}, fileName=#{fileName}"
            if !uploadFile($bucket, filePath, fileName)
                $failed.push(fileName)
            end
        end
    end
end

sync($syncDir)

$failed.each do |item|
    puts "Failed to upload #{item} "
end

