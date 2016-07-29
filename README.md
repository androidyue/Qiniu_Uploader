# Qiniu_Uploader
An Uploading Tool for Uploading Files to Qiniu, especially for Octopress

##为什么写这个应用
  * 七牛官方的qrsync不支持例外目录，会上传.git文件夹下的内容
  * 七牛的qrsync更新策略不符合我的需求
  * 自己有时间和能力

##功能描述
  * 暂时只支持对文件的上传和更新，不含删除和下载功能
  * 尤其适合于Octopress网站


##使用
###创建授权信息文件
从七牛后台 账号-->秘钥 中获取AccessKey和SecretKey分别填入下面
```
[auth]
access_key = ""
secret_key = ""
```
将上述内容保存成文件`.qiniu.ini` 放在同步脚本的祖先目录上即可，也可以放在家目录。

举个例子，比如你的同步脚本放在`~/tools/notes/sync_dir/`下，你的配置文件，可以放在`~/`,`~/tools/`以及`~/tools/notes/`。

注意，必要将上述文件放同步脚本目录，以免信息泄露。

###同步
使用方法如下，很简单，需要传入同步文件夹路径和bucket名称

```java
ruby push2Qiniu.rb dir_to_sync bucket
```

##实现原理
实现原理很简单，基本如下
  
  * 新文件 直接上传
  * 已存在的文件，如果lastModified没有变化，不上传
  * 已存在的文件，如果lastModified有变化，检测文件内容md5，如果和上一次不同，则上传，否则不上传。


## Note
建议安装6.5.1版qiniu sdk
```
sudo gem install qiniu -v 6.5.1
```
