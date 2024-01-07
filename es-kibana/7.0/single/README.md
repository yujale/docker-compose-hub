# ELK 单节点部署

本次部署使用 ElasticSearch 官方的镜像和 Docker-Compose 来创建单节点的 ELK，用于学习 ELK 操作；在 k8s 集群内中，如果日志
量每天超过 20G 以上的话，还是建议部署在 k8s 集群外部，支持分布式集群的架构，这里使用的是有状态部署的方式，并且使用动态存
储进行持久化，需要提前创建好存储类，才能运行该 yaml。本文档仅仅采用常用的 ElasticSearch + LogStash + Kibana 组件

各个环境版本：

-   操作系统：Mac M1
-   Docker：20.10.17
-   Docker-Compose：2.10.2
-   ELK Version：7.17.4

## 第一步、创建 Docker-Compose 的配置文件

```yaml
version: '3.2'

services:
    elasticsearch:
        image: elasticsearch:7.17.4
        volumes:
            - /etc/localtime:/etc/localtime
            - ./es/plugins:/usr/share/elasticsearch/plugins #插件文件挂载
            - ./es/data:/usr/share/elasticsearch/data #数据文件挂载
        ports:
            - '9200:9200'
            - '9300:9300'
        container_name: elasticsearch
        restart: always
        environment:
            - 'cluster.name=elasticsearch' #设置集群名称为elasticsearch
            - 'discovery.type=single-node' #以单一节点模式启动
            - 'ES_JAVA_OPTS=-Xms1024m -Xmx1024m' #设置使用jvm内存大小
        networks:
            - elk
    logstash:
        image: logstash:7.17.4
        container_name: logstash
        restart: always
        volumes:
            - /etc/localtime:/etc/localtime
            - './logstash/pipelines.yml:/usr/share/logstash/config/pipelines.yml'
            - './logstash/logstash-audit.conf:/usr/share/logstash/pipeline/logstash-audit.conf'
            - './logstash/logstash-user-action.conf:/usr/share/logstash/pipeline/logstash-user-action.conf'
        ports:
            - '5044:5044'
            - '50000:50000/tcp'
            - '50000:50000/udp'
            - '9600:9600'
        environment:
            LS_JAVA_OPTS: -Xms1024m -Xmx1024m
            TZ: Asia/Shanghai
            MONITORING_ENABLED: false
        links:
            - elasticsearch:es #可以用es这个域名访问elasticsearch服务
        networks:
            - elk
        depends_on:
            - elasticsearch
    kibana:
        image: kibana:7.17.4
        container_name: kibana
        restart: always
        volumes:
            - /etc/localtime:/etc/localtime
            - ./kibana/config/kibana.yml:/usr/share/kibana/config/kibana.yml
        ports:
            - '5601:5601'
        links:
            - elasticsearch:es #可以用es这个域名访问elasticsearch服务
        environment:
            - ELASTICSEARCH_URL=http://elasticsearch:9200 #设置访问elasticsearch的地址
            - 'elasticsearch.hosts=http://es:9200' #设置访问elasticsearch的地址
            - I18N_LOCALE=zh-CN
        networks:
            - elk
        depends_on:
            - elasticsearch
networks:
    elk:
        name: elk
        driver:
            bridge
            #  ik 分词器的安装

            # 集群 docker-compose exec elasticsearch elasticsearch-plugin install https://github.com/medcl/elasticsearch-analysis-ik/releases/download/v7.17.4/elasticsearch-analysis-ik-7.17.4.zip

            # 单点 bin/elasticsearch-plugin install https://github.com/medcl/elasticsearch-analysis-ik/releases/download/v7.17.4/elasticsearch-analysis-ik-7.17.4.zip
```

在 Services 中声明了三个服务：

-   elasticsearch
-   logstash
-   kibana

### **ElasticSearch 服务的配置注意事项:**

-   environment 环境设置中 discovery.type 属性设置成 ‘single-node’ ,主要目的是将 ES 的集群发现模式配置为单节点模式
-   environment 环境设置中 ES_JAVA_OPTS 的 Xms 属性和 Xmx 属性建议设置成 ‘-Xms1024m’ ‘-Xmx1024m’ ,主要是为了防止 ES 启动
    成功后，无法查询消息
-   volumes 持久卷设置中的 /etc/localtime:/etc/localtime 主要目的是将 Docker 容器中的时间与宿主机同步
-   volumes 持久卷设置中的 ./es/data:/usr/share/elasticsearch/data 主要目的是将 ES 的数据映射到对应的宿主机中，并做持久
    化设置

### **LogStash 服务的配置注意事项:**

-   volumes 持久卷中的 ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf：将宿主机本地的 LogStash 配置映射至
    Logstash 容器内部
-   volumes 持久卷设置中的 /etc/localtime:/etc/localtime 主要目的是将 Docker 容器中的时间与宿主机同步
-   environment 环境设置中 MONITORING_ENABLED 属性设置成 false ,主要目的是关闭 LogStash 监控功能，避免容器崩溃
-   environment 环境设置中 ES_JAVA_OPTS 的 Xms 属性和 Xmx 属性建议设置成 ‘-Xms1024m’ ‘-Xmx1024m’ ,主要是为了防止
    Logstash 消费消息时突然崩溃
-   depends_on 设置,设置成 elasticsearch,表示 LogStash 容器的启动必须依赖于 ES 容器启动,如果 ES 启动失败，则 LogStash 启
    动也失败

### **Kibana 服务的配置注意事项:**

-   volumes 持久卷设置中的 /etc/localtime:/etc/localtime 主要目的是将 Docker 容器中的时间与宿主机同步
-   volumes 持久卷中的./kibana/config/kibana.yml:/usr/share/kibana/config/kibana.yml,主要目的是 Kibana 容器启动使用外部
    配置为变化吧
-   environment 环境设置中 ELASTICSEARCH_URL 属性设置成 ‘http://elasticsearch:9200’ ,主要目的是连接 ES 容器，监控 ES 服
    务
-   environment 环境设置中 I18N_LOCALE 属性设置成 zh-CN ,主要目的将 Kibana 的系统语言设置成中文,可视化页面同时也是中文语
    言
-   depends_on 设置,设置成 elasticsearch,表示 Kibana 容器的启动必须依赖于 ES 容器启动,如果 ES 启动失败，则 Kibana 启动也
    失败

## 第二步、配置 LogStash 配置

### 创建批量写入文件 pipeline.yml

```yaml
- pipeline.id: user-action
  path.config: /usr/share/logstash/pipeline/logstash-user-action.conf
  pipeline.workers: 3
- pipeline.id: audit
  path.config: /usr/share/logstash/pipeline/logstash-audit.conf
  pipeline.workers: 3
```

yaml 需要配置写入的日志 ID、路径配置文件和工作线程

logstash-user-action.conf 和 logstash-audit.conf 按需要求进行定制化更改

## 第三步、配置 Kibana 配置

新建 conf 配置文件夹,创建 kibana.yml 文件

```yaml
# Default Kibana configuration for docker target
server.host: '0.0.0.0'
server.shutdownTimeout: '5s'
elasticsearch.hosts: ['http://elasticsearch:9200']
monitoring.ui.container.elasticsearch.enabled: true
```

-   server.host:设置成 0.0.0.0 表示 允许所有机器访问
-   elasticsearch.hosts:设置成 ES 服务地址，可以是单机地址，也可以是服务地址
-   monitoring.ui.container.elasticsearch.enabled:是否开启对 ES 进行容器监控

## 第四步、部署测试

### ES 容器是否启动

![image.png](https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/764142ee9a0f4d42acea611902ac19d5~tplv-k3u1fbpfcp-watermark.image?)

### Kibana 容器是否启动

![image.png](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/4593a41817e8484f9e0262f21fe91da1~tplv-k3u1fbpfcp-watermark.image?)

### 推荐一个 ES 可视化插件 [Elasticvue]()

Elasticvue 相对于 Kibana 来讲，是很轻量，在浏览器中随装随用，不需要配置繁琐的配置。当然功能层次上也没有 Kibana 那么全面
，适合当作入门级插件使用。

![image.png](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/f5640322ebe54740bb52275c88150424~tplv-k3u1fbpfcp-watermark.image?)
