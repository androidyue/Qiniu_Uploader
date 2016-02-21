#!/usr/bin/env ruby

require 'inifile'
require 'qiniu'
require 'digest'

##Configs Loading

SEARCH_FILE_NAME = '.qiniu.ini'

$configs = nil

def getMD5(filePath) 
    return Digest::MD5.hexdigest(File.read(filePath))
end

def findFileUpward(filePath, fileToFind)
    return nil if File.file?(filePath)
    configFilePath = filePath + '/' + fileToFind
    containsConfigFile = !Dir[configFilePath].empty?
    return configFilePath if containsConfigFile
    parentDir = File.expand_path('..', filePath)
    return nil  if  parentDir == filePath
    return findFileUpward(parentDir, fileToFind)
end


def initConfiguration
    searchDirectory = File.dirname(__FILE__)
    iniFile = findFileUpward(searchDirectory, SEARCH_FILE_NAME)
    raise 'ConfigFile(%s) not found under Directory(%s)'%[searchFileName, searchDirectory]  if iniFile.nil?
    $configs = IniFile.load(iniFile)
end

def initQiniuAuth
    auth = $configs['auth']
    Qiniu.establish_connection! :access_key => auth['access_key'],:secret_key => auth['secret_key']
end



##Database Related
require 'sqlite3'
DB_FILE = File.expand_path('..', __FILE__) + '/.qiniu.db'
TABLE_NAME = "qn_uploaded"
COLUMN_FILE_PATH = 'filePath'
COLUMN_BUCKET = 'bucket'
COLUMN_LAST_MODIFIED = 'lastModified'
COLUMN_MD5 = 'md5'
UPLOAD_TYPE_NO_NEED = 0
UPLOAD_TYPE_CREATE = 1
UPLOAD_TYPE_UPDATE = 2


$db = nil


def initDb() 
	$db = SQLite3::Database.new DB_FILE
	sql = "CREATE TABLE IF NOT EXISTS #{TABLE_NAME}(#{COLUMN_FILE_PATH} VARCHAR(255), #{COLUMN_BUCKET} VARCHAR(63),  #{COLUMN_LAST_MODIFIED} FLOAT, #{COLUMN_MD5} VARCHAR(32)) ;"
	$db.execute sql
    
    #indexSql = "CREATE INDEX buket_path ON #{TABLE_NAME} (#{COLUMN_FILE_PATH}, #{COLUMN_BUCKET})";
    #$db.execute indexSql

end

def insertUploadRecord(filePath, bucket)
    lastModified = File.new(filePath).mtime.to_f
    md5 = getMD5(filePath)
    insertSQL = "insert into #{TABLE_NAME} values('%s', '%s', '%f', '%s')"%[filePath, bucket, lastModified, md5]
    #puts insertSQL if $verboseOn
    $db.execute insertSQL
end

def updateUploadRecord(filePath, bucket)
    lastModified = File.new(filePath).mtime.to_f
    md5 = getMD5(filePath)
    updateSQL = "UPDATE #{TABLE_NAME} SET #{COLUMN_LAST_MODIFIED}=%f, #{COLUMN_MD5}='%s' WHERE #{COLUMN_FILE_PATH} = '%s' and #{COLUMN_BUCKET}='%s'"%[lastModified, md5, filePath, bucket]
    #puts updateSQL if $verboseOn
    $db.execute updateSQL
end

def determinUploadType(filePath, bucket)
	query = "select #{COLUMN_LAST_MODIFIED},#{COLUMN_MD5} from #{TABLE_NAME} where #{COLUMN_FILE_PATH} = '%s' and #{COLUMN_BUCKET} = '%s'"%[filePath, bucket]
    result = $db.execute query 
    #p 'determinUploadType query =' , query, 'result=',result if $verboseOn
    return UPLOAD_TYPE_CREATE if result.empty?
    lastModified = result[0][0];
    lastMd5 = result[0][1]
    currentMd5 = getMD5(filePath)
    #puts "lastModified=#{lastModified}, lastMd5=#{lastMd5}, currentMd5=#{currentMd5}" if $verboseOn
    if File.new(filePath).mtime.to_f == lastModified
        return UPLOAD_TYPE_NO_NEED
    end
    if lastMd5 != getMD5(filePath)
        return UPLOAD_TYPE_UPDATE
    end
    return UPLOAD_TYPE_NO_NEED
end



##Qiniu Storage Related
STATUS_CODE_OK = 200

def uploadFile(bucket, localPath, fileName=nil, putPolicy=nil, xVar=nil)
    uploadType = determinUploadType(localPath, bucket)
    fileName = File.basename(localPath) if fileName.nil?
    if UPLOAD_TYPE_NO_NEED == uploadType 
        puts "[CONSOLE] NO_NEED to upload #{fileName}"
        return true
    end
    initQiniuAuth
    #puts 'fileName =' + fileName if $verboseOn
    put_policy = Qiniu::Auth::PutPolicy.new(bucket + ':' + fileName ) if putPolicy.nil?
    #puts 'uploadFile method localPath =' + localPath + ';fileName=' + fileName + ';bucket=' + bucket if $verboseOn
    code, result, response_headers = Qiniu::Storage.upload_with_put_policy(
            put_policy,    
            localPath,    
            fileName,            
            xVar      
    )
    #puts code, result, response_headers if $verboseOn
    if success = (STATUS_CODE_OK == code)
        if UPLOAD_TYPE_CREATE == uploadType 
            puts "[CONSOLE] upload  CREATE successfully #{fileName}" if $verboseOn
            insertUploadRecord(localPath, bucket) 
        else
            puts "[CONSOLE] upload UPDATE successfully #{fileName}" if $verboseOn
            updateUploadRecord(localPath, bucket) 
        end
    else
        puts "[CONSOLE] upload failed #{fileName}" if $verboseOn
    end
    return success
end



